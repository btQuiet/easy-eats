import asyncio
import hashlib
import hmac
import logging
from contextlib import asynccontextmanager, suppress
from datetime import timedelta
from uuid import uuid4

from fastapi import FastAPI, Query, Request
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, Response

from ..config import Clock, Settings
from ..services.deliveries import Deliveries
from ..domain import Catalog, Problem, fold
from ..services.menus import Menus
from ..services.profiles import Profiles, version
from .schemas import (AddressUpdate, CalendarUpdate, Credentials, Draft, Ensure,
                      Opinion, PlanUpdate, ProfilePatch, Replacement, Versioned)
from ..security import create_user, new_session, normalize_alias, session_dto, verify_password
from ..storage import Database

PREFIX = "/api/v1"


def create_app(settings=None, clock=None, generator=None, run_worker=True):
    settings, clock = settings or Settings(), clock or Clock()
    database, catalog = Database(settings.db_path), Catalog(settings.catalog_path)
    profiles = Profiles(catalog, clock)
    menus = Menus(database, catalog, profiles, settings, clock, generator)
    deliveries = Deliveries(profiles, clock)

    @asynccontextmanager
    async def lifespan(app):
        with database.instance():
            with database.transaction() as db:
                menus.recover(db)
                db.execute("DELETE FROM sessions WHERE expires_at<=? OR revoked_at IS NOT NULL", (clock.stamp(),))
            task = asyncio.create_task(menus.worker()) if run_worker else None
            try:
                yield
            finally:
                if task:
                    task.cancel()
                    with suppress(asyncio.CancelledError):
                        await task

    app = FastAPI(title="Easy Eats", version="1.0.0", lifespan=lifespan)
    app.state.database, app.state.menus, app.state.clock = database, menus, clock
    app.state.profiles, app.state.deliveries = profiles, deliveries
    app.add_middleware(CORSMiddleware, allow_origins=list(settings.origins), allow_credentials=True,
                       allow_methods=["GET", "POST", "PUT", "PATCH", "OPTIONS"],
                       allow_headers=["Content-Type", "Authorization", "X-CSRF-Token", "Idempotency-Key"])

    def meta(request, **extra):
        return {"request_id": getattr(request.state, "request_id", str(uuid4())),
                "server_today": clock.today().isoformat(), "generation_mode": settings.mode, **extra}

    def ok(request, data, status=200, **extra):
        return JSONResponse({"data": data, "meta": meta(request, **extra)}, status_code=status)

    def page(request, rows):
        try:
            limit, offset = int(request.query_params.get("limit", 25)), int(request.query_params.get("offset", 0))
        except ValueError:
            raise Problem("INVALID_INPUT", "Paginación no válida.")
        if not 1 <= limit <= 100 or offset < 0:
            raise Problem("INVALID_INPUT", "Paginación no válida.")
        return ok(request, rows[offset:offset + limit], total=len(rows), limit=limit, offset=offset)

    @app.middleware("http")
    async def context(request, call_next):
        request.state.request_id = str(uuid4())
        try:
            with database.transaction() as db:
                menus.expire(db)
                db.execute("DELETE FROM sessions WHERE expires_at<=? OR revoked_at IS NOT NULL", (clock.stamp(),))
                db.execute("DELETE FROM idempotency_operations WHERE expires_at<=?", (clock.stamp(),))
            response = await call_next(request)
        except Problem as error:
            response = JSONResponse({"error": error.payload(), "meta": meta(request)}, status_code=error.status)
        except Exception:
            logging.exception("Request failed %s", request.state.request_id)
            response = JSONResponse({"error": {"code": "INTERNAL_ERROR", "message": "No se pudo completar la operación.", "details": {}}, "meta": meta(request)}, status_code=500)
        response.headers["X-Request-ID"] = request.state.request_id
        response.headers["Cache-Control"] = "no-store"
        return response

    @app.exception_handler(Problem)
    async def business_error(request, error):
        return JSONResponse({"error": error.payload(), "meta": meta(request)}, status_code=error.status)

    @app.exception_handler(RequestValidationError)
    async def validation_error(request, error):
        # Locations only: do not echo passwords or provider secrets from input.
        return JSONResponse({"error": {"code": "INVALID_INPUT", "message": "Revisa los campos enviados.",
                                      "details": {"fields": [list(e["loc"]) for e in error.errors()]}}, "meta": meta(request)}, status_code=422)

    def origin_check(request):
        origin = request.headers.get("origin")
        if origin and origin not in settings.origins:
            raise Problem("FORBIDDEN", "Origen web no permitido.", 403)

    def auth(db, request, role=None):
        header = request.headers.get("authorization", "")
        bearer = header.startswith("Bearer ")
        token = header[7:] if bearer else request.cookies.get("easy_eats_session", "")
        row = db.execute("SELECT s.*,u.alias_normalized,u.role FROM sessions s JOIN users u ON u.id=s.user_id WHERE s.token_hash=? AND s.revoked_at IS NULL AND s.expires_at>?",
                         (hashlib.sha256(token.encode()).hexdigest(), clock.stamp())).fetchone()
        if not row or row["transport"] != ("bearer" if bearer else "cookie"):
            raise Problem("AUTH_REQUIRED", "Vuelve a iniciar sesión.", 401)
        if row["transport"] == "cookie":
            origin_check(request)
            if request.method not in ("GET", "HEAD") and (not row["csrf_token"] or not hmac.compare_digest(request.headers.get("x-csrf-token", ""), row["csrf_token"])):
                raise Problem("FORBIDDEN", "La protección de sesión no es válida. Recarga.", 403)
        if role and row["role"] != role:
            raise Problem("FORBIDDEN", "No tienes permiso para esta operación.", 403)
        if row["role"] == "client":
            profiles.plan(db, row["user_id"])
        return row

    def session_response(request, body, register):
        origin_check(request)
        alias = normalize_alias(body.alias)
        ip = request.client.host if request.client else "unknown"
        invalid = False
        with database.transaction() as db:
            db.execute("DELETE FROM login_attempts WHERE occurred_at<?", ((clock.now() - timedelta(hours=24)).isoformat(),))
            since = (clock.now() - timedelta(minutes=15)).isoformat()
            failures = db.execute("SELECT COUNT(*) FROM login_attempts WHERE succeeded=0 AND occurred_at>=? AND (alias_normalized=? OR ip=?)", (since, alias, ip)).fetchone()[0]
            if failures >= 10:
                raise Problem("INVALID_CREDENTIALS", "Demasiados intentos. Espera quince minutos.", 429, retry_after=900)
            if register:
                user = create_user(db, alias, body.password, "client", clock)
            else:
                user = db.execute("SELECT * FROM users WHERE alias_normalized=?", (alias,)).fetchone()
                invalid = not user or not verify_password(body.password, user)
            db.execute("INSERT INTO login_attempts VALUES(?,?,?,?)", (alias, ip, clock.stamp(), int(not invalid)))
            if not invalid:
                token, dto = new_session(db, user, body.transport, clock)
        if invalid:
            raise Problem("INVALID_CREDENTIALS", "Alias o contraseña incorrectos.", 401)
        response = ok(request, dto, 201 if register else 200)
        if body.transport == "cookie":
            response.set_cookie("easy_eats_session", token, max_age=7 * 86400, httponly=True,
                                secure=settings.cookie_secure, samesite="strict", path=PREFIX)
        return response

    @app.get(PREFIX + "/system/capabilities")
    def capabilities(request: Request):
        available = settings.mode == "test" or bool(settings.groq_key)
        return ok(request, {"api_version": "1", "generation_mode": settings.mode, "can_generate": available,
                            "generation_unavailable_reason": None if available else "AI_NOT_CONFIGURED",
                            "timezone": "Europe/Madrid", "server_today": clock.today().isoformat(),
                            "catalog_hash": catalog.hash, "catalog_validation_status": "demo_unverified"})

    @app.post(PREFIX + "/auth/register", status_code=201)
    def register(request: Request, body: Credentials):
        return session_response(request, body, True)

    @app.post(PREFIX + "/auth/login")
    def login(request: Request, body: Credentials):
        return session_response(request, body, False)

    @app.get(PREFIX + "/auth/session")
    def session(request: Request):
        with database.transaction() as db:
            a = auth(db, request)
            user = db.execute("SELECT * FROM users WHERE id=?", (a["user_id"],)).fetchone()
            return ok(request, session_dto(db, user, a))

    @app.post(PREFIX + "/auth/logout", status_code=204)
    def logout(request: Request):
        with database.transaction() as db:
            a = auth(db, request)
            db.execute("UPDATE sessions SET revoked_at=? WHERE id=?", (clock.stamp(), a["id"]))
        response = Response(status_code=204)
        response.delete_cookie("easy_eats_session", path=PREFIX)
        return response

    @app.get(PREFIX + "/operations/{key}")
    def operation(request: Request, key: str):
        import json
        with database.transaction() as db:
            a = auth(db, request)
            row = db.execute("SELECT * FROM idempotency_operations WHERE user_id=? AND key=? AND expires_at>?", (a["user_id"], key, clock.stamp())).fetchone()
            if not row:
                raise Problem("NOT_FOUND", "Operación no encontrada.", 404)
            return ok(request, {"key": key, "state": row["state"], "result": json.loads(row["result_json"])})

    @app.get(PREFIX + "/profile")
    def profile(request: Request):
        with database.transaction() as db:
            a = auth(db, request, "client")
            return ok(request, profiles.get(db, a["user_id"]))

    @app.put(PREFIX + "/onboarding/draft")
    def draft(request: Request, body: Draft):
        with database.transaction() as db:
            a = auth(db, request, "client")
            return ok(request, profiles.save_draft(db, a["user_id"], body.expected_version, body.step, body.fields))

    @app.post(PREFIX + "/onboarding/complete")
    def complete(request: Request, body: Versioned):
        with database.transaction() as db:
            a = auth(db, request, "client")
            return ok(request, profiles.complete(db, a["user_id"], body.expected_version))

    @app.patch(PREFIX + "/profile")
    def patch_profile(request: Request, body: ProfilePatch):
        fields = body.model_dump(exclude={"expected_version"}, exclude_unset=True)
        if any(v is None for v in fields.values()):
            raise Problem("INVALID_INPUT", "El perfil no admite valores nulos.")
        with database.transaction() as db:
            a = auth(db, request, "client")
            deliveries.sync(db, a["user_id"])
            return ok(request, profiles.patch(db, a["user_id"], body.expected_version, fields))

    @app.put(PREFIX + "/profile/calendar")
    def calendar(request: Request, body: CalendarUpdate):
        with database.transaction() as db:
            a = auth(db, request, "client")
            return ok(request, profiles.edit_calendar(db, a["user_id"], body.expected_version, body.weekly_slots))

    @app.get(PREFIX + "/plan")
    def plan(request: Request):
        with database.transaction() as db:
            a = auth(db, request, "client")
            return ok(request, profiles.plan(db, a["user_id"]))

    @app.put(PREFIX + "/plan")
    def change_plan(request: Request, body: PlanUpdate):
        with database.transaction() as db:
            a = auth(db, request, "client")
            deliveries.sync(db, a["user_id"])
            result = profiles.change_plan(db, a["user_id"], body.expected_version, body.plan,
                                          body.address.model_dump() if body.address else None, body.expected_address_version)
            deliveries.sync(db, a["user_id"])
            return ok(request, result)

    @app.get(PREFIX + "/delivery/address")
    def address(request: Request):
        with database.transaction() as db:
            a = auth(db, request, "client")
            profiles.require_completed(db, a["user_id"])
            return ok(request, profiles.address(db, a["user_id"]))

    @app.put(PREFIX + "/delivery/address")
    def save_address(request: Request, body: AddressUpdate):
        with database.transaction() as db:
            a = auth(db, request, "client")
            profiles.require_completed(db, a["user_id"])
            p = profiles.plan(db, a["user_id"])
            if p["current_plan"] != "pro" and p["pending_plan"] != "pro":
                raise Problem("FORBIDDEN", "La dirección requiere Pro vigente o pendiente.", 403)
            deliveries.sync(db, a["user_id"])
            return ok(request, profiles.save_address(db, a["user_id"], body.expected_version, body.model_dump(exclude={"expected_version"})))

    def recipes_for(request, user=None, slot=None):
        profile = None
        with database.transaction() as db:
            a = auth(db, request)
            if a["role"] == "client":
                profile = profiles.get(db, a["user_id"])
        query = fold(request.query_params.get("q", ""))
        meal = request.query_params.get("meal_slot", slot)
        diet = request.query_params.get("diet")
        compatible = request.query_params.get("compatible_only", "false") == "true"
        if meal and meal not in ("desayuno", "comida", "merienda", "cena") or diet and diet not in ("omnivore", "vegetarian", "vegan"):
            raise Problem("INVALID_INPUT", "Filtro no válido.")
        result = []
        for r in catalog.recipes.values():
            reasons = catalog.reasons(r, profile, meal) if profile else []
            if meal and meal not in r["meal_slots"] or diet == "vegan" and not r["is_vegan"] or diet == "vegetarian" and not r["is_vegetarian"]:
                continue
            if compatible and reasons:
                continue
            if query not in fold(r["name"] + " " + " ".join(i["name"] for i in r["ingredients"])):
                continue
            result.append(dict(r, compatible=not reasons if profile else None, incompatibility_reasons=reasons))
        return sorted(result, key=lambda x: (fold(x["name"]), x["code"]))

    @app.get(PREFIX + "/catalog/options")
    def options(request: Request):
        with database.transaction() as db:
            auth(db, request)
        return ok(request, catalog.options())

    @app.get(PREFIX + "/catalog/recipes")
    def recipe_list(request: Request):
        return page(request, recipes_for(request))

    @app.get(PREFIX + "/catalog/recipes/{code}")
    def recipe_detail(request: Request, code: str):
        with database.transaction() as db:
            a = auth(db, request)
            p = profiles.get(db, a["user_id"]) if a["role"] == "client" else None
            r = catalog.recipe(code)
            reasons = catalog.reasons(r, p) if p else []
            return ok(request, dict(r, compatible=not reasons if p else None, incompatibility_reasons=reasons))

    @app.post(PREFIX + "/menus/ensure", responses={202: {"description": "Persisted generation attempt"}})
    def ensure(request: Request, body: Ensure):
        with database.transaction() as db:
            a = auth(db, request, "client")
            status, data = menus.idempotent(db, a["user_id"], request.headers.get("idempotency-key"), "ensure", body.model_dump(),
                                           lambda: menus.ensure(db, a["user_id"], a["user_id"], body.month))
            return ok(request, data, status)

    @app.get(PREFIX + "/menus/week")
    def week(request: Request, start: str):
        with database.transaction() as db:
            a = auth(db, request, "client")
            return ok(request, menus.week(db, a["user_id"], start))

    @app.get(PREFIX + "/menus/cycles/{ident}")
    def cycle(request: Request, ident: str):
        with database.transaction() as db:
            a = auth(db, request, "client")
            c = menus.cycle(db, ident)
            if c["user_id"] != a["user_id"]:
                raise Problem("NOT_FOUND", "Ciclo no encontrado.", 404)
            return ok(request, menus.cycle_dto(db, c))

    @app.get(PREFIX + "/menus/generations/{ident}")
    def generation(request: Request, ident: str):
        with database.transaction() as db:
            a = auth(db, request, "client")
            row = db.execute("SELECT g.*,c.user_id FROM generation_attempts g JOIN menu_cycles c ON c.id=g.cycle_id WHERE g.id=?", (ident,)).fetchone()
            if not row or row["user_id"] != a["user_id"]:
                raise Problem("NOT_FOUND", "Generación no encontrada.", 404)
            return ok(request, menus.attempt_dto(row))

    @app.get(PREFIX + "/menus/items/{ident}")
    def item(request: Request, ident: str):
        with database.transaction() as db:
            a = auth(db, request, "client")
            return ok(request, menus.item_dto(menus.own_item(db, ident, a["user_id"])))

    @app.get(PREFIX + "/menus/items/{ident}/candidates")
    def candidates(request: Request, ident: str):
        with database.transaction() as db:
            a = auth(db, request, "client")
            item = menus.own_item(db, ident, a["user_id"])
            if not menus.item_dto(item)["can_swap"]:
                raise Problem("ITEM_NOT_EDITABLE", "Esta comida no admite cambios.", 409)
            return page(request, menus.candidates(db, item, request.query_params.get("q", "")))

    @app.put(PREFIX + "/menus/items/{ident}/substitution")
    def substitute(request: Request, ident: str, body: Replacement):
        with database.transaction() as db:
            a = auth(db, request, "client")
            deliveries.sync(db, a["user_id"])
            status, data = menus.idempotent(db, a["user_id"], request.headers.get("idempotency-key"), "swap:" + ident, body.model_dump(),
                                           lambda: menus.substitute(db, ident, a["user_id"], body.expected_version, body.recipe_code))
            return ok(request, data, status)

    @app.put(PREFIX + "/menus/items/{ident}/feedback")
    def feedback(request: Request, ident: str, body: Opinion):
        with database.transaction() as db:
            a = auth(db, request, "client")
            return ok(request, menus.feedback(db, ident, a["user_id"], body.expected_version, body.rating, body.comment))

    @app.get(PREFIX + "/feedback")
    def feedback_list(request: Request):
        with database.transaction() as db:
            a = auth(db, request, "client")
            rows = [dict(x) for x in db.execute("SELECT f.id,f.item_id,f.recipe_code,f.rating,f.comment,f.version,f.created_at,f.updated_at,json_extract(i.recipe_snapshot_json,'$.name') AS recipe_name FROM feedback f JOIN menu_items i ON i.id=f.item_id WHERE f.user_id=? ORDER BY f.updated_at DESC,f.id", (a["user_id"],))]
            return page(request, rows)

    @app.get(PREFIX + "/operator/reviews")
    def reviews(request: Request, q: str = Query(default="", max_length=80)):
        with database.transaction() as db:
            auth(db, request, "operator")
            rows = [dict(menus.cycle_dto(db, c), user=dict(db.execute("SELECT id,alias_normalized AS alias FROM users WHERE id=?", (c["user_id"],)).fetchone())) for c in db.execute("SELECT c.* FROM menu_cycles c JOIN users u ON u.id=c.user_id WHERE c.status IN('pending_review','draft') AND instr(u.alias_normalized,?)>0 ORDER BY c.month,c.id", (fold(q.strip()),))]
            return page(request, rows)

    @app.get(PREFIX + "/operator/cycles/{ident}")
    def review(request: Request, ident: str):
        with database.transaction() as db:
            auth(db, request, "operator")
            return ok(request, menus.review(db, ident))

    @app.get(PREFIX + "/operator/items/{ident}/candidates")
    def operator_candidates(request: Request, ident: str):
        with database.transaction() as db:
            auth(db, request, "operator")
            item = menus.item(db, ident)
            if item["cycle_status"] != "pending_review":
                raise Problem("ITEM_NOT_EDITABLE", "La propuesta no está pendiente.", 409)
            return page(request, menus.candidates(db, item, request.query_params.get("q", "")))

    @app.put(PREFIX + "/operator/items/{ident}")
    def correct(request: Request, ident: str, body: Replacement):
        with database.transaction() as db:
            a = auth(db, request, "operator")
            status, data = menus.substitute(db, ident, a["user_id"], body.expected_version, body.recipe_code, True)
            return ok(request, data, status)

    @app.post(PREFIX + "/operator/cycles/{ident}/regenerate", responses={202: {"description": "Persisted generation attempt"}})
    def regenerate(request: Request, ident: str, body: Versioned):
        with database.transaction() as db:
            a = auth(db, request, "operator")
            def action():
                c = menus.cycle(db, ident)
                version(c, body.expected_version)
                if c["status"] not in ("pending_review", "draft"):
                    raise Problem("CYCLE_EXPIRED" if c["status"] == "expired" else "ITEM_NOT_EDITABLE", "Solo se regenera una propuesta pendiente.", 409)
                return menus.queue(db, c, a["user_id"])
            status, data = menus.idempotent(db, a["user_id"], request.headers.get("idempotency-key"), "regenerate:" + ident, body.model_dump(), action)
            return ok(request, data, status)

    @app.post(PREFIX + "/operator/cycles/{ident}/approve")
    def approve(request: Request, ident: str, body: Versioned):
        with database.transaction() as db:
            a = auth(db, request, "operator")
            status, data = menus.idempotent(db, a["user_id"], request.headers.get("idempotency-key"), "approve:" + ident, body.model_dump(),
                                           lambda: menus.approve(db, ident, a["user_id"], body.expected_version))
            c = menus.cycle(db, ident)
            deliveries.sync(db, c["user_id"])
            return ok(request, data, status)

    @app.post(PREFIX + "/operator/users/{user}/menus/ensure")
    def operator_ensure(request: Request, user: str, body: Ensure):
        with database.transaction() as db:
            a = auth(db, request, "operator")
            p = profiles.require_completed(db, user)
            if p["initial_review_completed"]:
                raise Problem("FORBIDDEN", "Solo se prepara la primera revisión.", 403)
            status, data = menus.idempotent(db, a["user_id"], request.headers.get("idempotency-key"), "operator_ensure:" + user, body.model_dump(),
                                           lambda: menus.ensure(db, user, a["user_id"], body.month))
            return ok(request, data, status)

    @app.get(PREFIX + "/deliveries")
    def delivery_list(request: Request, start: str | None = None):
        with database.transaction() as db:
            a = auth(db, request, "client")
            profiles.require_completed(db, a["user_id"])
            if not profiles.plan(db, a["user_id"])["can_view_delivery"]:
                raise Problem("FORBIDDEN", "Las entregas requieren Pro vigente.", 403)
            return page(request, deliveries.list(db, a["user_id"], start))

    return app
