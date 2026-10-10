from __future__ import annotations

import calendar
import sqlite3
from collections import defaultdict
from datetime import date, timedelta, datetime
from typing import Any
from zoneinfo import ZoneInfo

from app.config import Settings
from app.domain.catalog import catalog_hash, eligible_recipes, read_catalog
from app.integrations.generation import (
    GenerationError, GenerationRequest, generate_ai, generate_test, validate_proposal,
)
from app.services.profile import get_profile
from app.storage.db import connection, utc_now


SLOT_ORDER = {"desayuno": 0, "comida": 1, "cena": 2, "merienda": 3}


class MenuError(Exception):
    def __init__(self, code: str, message: str, status: int = 400):
        self.code = code
        self.status = status
        super().__init__(message)


def local_today() -> date:
    return datetime.now(ZoneInfo("Europe/Madrid")).date()


def week_start(day: date) -> date:
    return day - timedelta(days=day.weekday())


def _month_slots(month: str, schedule: list[dict[str, Any]]) -> list[tuple[str, str]]:
    year, number = (int(part) for part in month.split("-"))
    selected = {(item["weekday"], item["slot"]) for item in schedule}
    days = calendar.monthrange(year, number)[1]
    return [
        (day.isoformat(), slot)
        for number_of_day in range(1, days + 1)
        for day in [date(year, number, number_of_day)]
        for slot in SLOT_ORDER
        if (day.weekday(), slot) in selected
    ]


def _preference_scores(settings: Settings, user_id: int, profile: dict[str, Any],
                       catalog: dict[str, Any]) -> dict[str, int]:
    liked = set(profile["liked_ingredients"])
    disliked = set(profile["disliked_ingredients"])
    with connection(settings) as db:
        feedback_scores = dict(db.execute(
            "SELECT mi.recipe_code, SUM(f.rating) FROM feedback f "
            "JOIN menu_items mi ON mi.id = f.item_id WHERE f.user_id = ? GROUP BY mi.recipe_code",
            (user_id,),
        ).fetchall())
    scores = {}
    for recipe in catalog["recipes"].values():
        ingredients = {item["code"] for item in recipe["ingredients"]}
        score = 2 * len(liked & ingredients) - 2 * len(disliked & ingredients)
        score += 3 * (feedback_scores.get(recipe["code"]) or 0)
        scores[recipe["code"]] = score
    return scores


def _request(settings: Settings, user_id: int, month: str) -> tuple[GenerationRequest, dict[str, Any]]:
    profile = get_profile(settings, user_id)
    if profile is None or not profile["completed"]:
        raise MenuError("profile_required", "Completa tu perfil antes de generar un menú")
    if month < local_today().strftime("%Y-%m"):
        raise MenuError("past_month", "No se pueden generar meses pasados")
    slots = _month_slots(month, profile["schedule"])
    if not slots:
        raise MenuError("empty_schedule", "Selecciona al menos una comida semanal")
    catalog = read_catalog(settings)
    candidates = {}
    for slot in {slot for _, slot in slots}:
        candidates[slot] = eligible_recipes(catalog, profile, slot)
        if not candidates[slot]:
            raise MenuError("no_candidates", f"No hay platos disponibles para {slot} con estas restricciones")
    return GenerationRequest(month, slots, candidates,
                             _preference_scores(settings, user_id, profile, catalog)), catalog


def _log_attempt(settings: Settings, user_id: int, month: str, status: str,
                 error_code: str | None = None) -> None:
    with connection(settings) as db:
        db.execute(
            "INSERT INTO generation_attempts(user_id, month, origin, provider, model, status, error_code, created_at) "
            "VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
            (user_id, month, settings.mode,
             settings.ai_provider if settings.mode == "ai" else None,
             settings.ai_model if settings.mode == "ai" else None,
             status, error_code, utc_now()),
        )


def generate_cycle(settings: Settings, user_id: int, month: str,
                   replace_pending: bool = False) -> dict[str, Any]:
    with connection(settings) as db:
        existing = db.execute(
            "SELECT id, status FROM menu_cycles WHERE user_id = ? AND month = ?", (user_id, month)
        ).fetchone()
        if existing and (not replace_pending or existing["status"] != "pending_review"):
            raise MenuError("cycle_exists", "Este mes ya tiene una propuesta", 409)
    try:
        request, _ = _request(settings, user_id, month)
        proposal = generate_ai(request, settings) if settings.mode == "ai" else generate_test(request)
        validate_proposal(request, proposal)
    except GenerationError as exc:
        _log_attempt(settings, user_id, month, "error", exc.code)
        raise MenuError(exc.code, str(exc), 503 if exc.code in {"ai_unavailable", "missing_api_key"} else 502) from exc
    except MenuError as exc:
        _log_attempt(settings, user_id, month, "error", exc.code)
        raise

    created = utc_now()
    with connection(settings) as db:
        if existing:
            db.execute("DELETE FROM menu_cycles WHERE id = ? AND status = 'pending_review'", (existing["id"],))
        needs_review = db.execute(
            "SELECT 1 FROM initial_reviews WHERE user_id = ?", (user_id,)
        ).fetchone() is None
        status = "pending_review" if needs_review else "approved"
        cursor = db.execute(
            "INSERT INTO menu_cycles(user_id, month, status, origin, provider, model, catalog_hash, created_at, approved_at) "
            "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
            (user_id, month, status, settings.mode,
             settings.ai_provider if settings.mode == "ai" else None,
             settings.ai_model if settings.mode == "ai" else None,
             catalog_hash(settings), created, None if needs_review else created),
        )
        cycle_id = cursor.lastrowid
        db.executemany(
            "INSERT INTO menu_items(cycle_id, day, slot, recipe_code, source) VALUES (?, ?, ?, ?, 'generated')",
            [(cycle_id, day, slot, code) for day, slot, code in proposal],
        )
    _log_attempt(settings, user_id, month, "success")
    return {"id": cycle_id, "month": month, "status": status, "origin": settings.mode,
            "items_count": len(proposal)}


def cycle_status(settings: Settings, user_id: int, month: str) -> dict[str, Any]:
    with connection(settings) as db:
        row = db.execute(
            "SELECT id, month, status, origin, created_at, approved_at FROM menu_cycles "
            "WHERE user_id = ? AND month = ?", (user_id, month)
        ).fetchone()
    if row is None:
        return {"month": month, "status": "not_generated", "origin": settings.mode}
    return dict(row)


def _item_dict(row: sqlite3.Row, catalog: dict[str, Any], profile: dict[str, Any] | None,
               editable: bool) -> dict[str, Any]:
    recipe = catalog["recipes"].get(row["recipe_code"])
    attention = False
    if recipe and profile:
        attention = recipe not in eligible_recipes(catalog, profile, row["slot"])
    return {
        "id": row["id"], "day": row["day"], "slot": row["slot"],
        "recipe_code": row["recipe_code"], "recipe": recipe,
        "source": row["source"], "version": row["version"],
        "can_swap": editable, "needs_user_attention": attention,
    }


def get_week(settings: Settings, user_id: int, selected_day: date) -> dict[str, Any]:
    start = week_start(selected_day)
    end = start + timedelta(days=6)
    catalog = read_catalog(settings)
    profile = get_profile(settings, user_id)
    with connection(settings) as db:
        rows = db.execute(
            "SELECT mi.*, mc.origin FROM menu_items mi JOIN menu_cycles mc ON mc.id = mi.cycle_id "
            "WHERE mc.user_id = ? AND mc.status = 'approved' AND mi.day BETWEEN ? AND ? "
            "ORDER BY mi.day, CASE mi.slot WHEN 'desayuno' THEN 0 WHEN 'comida' THEN 1 "
            "WHEN 'cena' THEN 2 ELSE 3 END",
            (user_id, start.isoformat(), end.isoformat()),
        ).fetchall()
        pending = db.execute(
            "SELECT COUNT(*) FROM menu_cycles WHERE user_id = ? AND status = 'pending_review' "
            "AND month BETWEEN ? AND ?",
            (user_id, start.strftime("%Y-%m"), end.strftime("%Y-%m")),
        ).fetchone()[0]
    editable_week = start > week_start(local_today())
    return {
        "week_start": start.isoformat(), "week_end": end.isoformat(),
        "status": "pending_review" if pending and not rows else "ready" if rows else "empty",
        "origin": rows[0]["origin"] if rows else settings.mode,
        "items": [_item_dict(row, catalog, profile, editable_week) for row in rows],
    }


def pending_reviews(settings: Settings) -> list[dict[str, Any]]:
    with connection(settings) as db:
        return [dict(row) for row in db.execute(
            "SELECT mc.id, mc.month, mc.origin, mc.created_at, u.username, p.plan, p.diet "
            "FROM menu_cycles mc JOIN users u ON u.id = mc.user_id "
            "JOIN profiles p ON p.user_id = u.id WHERE mc.status = 'pending_review' "
            "ORDER BY mc.created_at"
        )]


def review_detail(settings: Settings, cycle_id: int) -> dict[str, Any]:
    catalog = read_catalog(settings)
    with connection(settings) as db:
        cycle = db.execute(
            "SELECT mc.*, u.username FROM menu_cycles mc JOIN users u ON u.id = mc.user_id WHERE mc.id = ?",
            (cycle_id,),
        ).fetchone()
        if cycle is None:
            raise MenuError("not_found", "Propuesta no encontrada", 404)
        rows = db.execute("SELECT * FROM menu_items WHERE cycle_id = ? ORDER BY day, slot", (cycle_id,)).fetchall()
    profile = get_profile(settings, cycle["user_id"])
    return {"cycle": dict(cycle), "profile": profile,
            "items": [_item_dict(row, catalog, profile, False) for row in rows]}


def approve_first(settings: Settings, cycle_id: int, operator_id: int) -> dict[str, Any]:
    with connection(settings) as db:
        cycle = db.execute("SELECT * FROM menu_cycles WHERE id = ?", (cycle_id,)).fetchone()
        if cycle is None:
            raise MenuError("not_found", "Propuesta no encontrada", 404)
        if cycle["status"] != "pending_review":
            raise MenuError("already_approved", "La propuesta ya está aprobada", 409)
        db.execute(
            "INSERT INTO initial_reviews(user_id, cycle_id, operator_id, reviewed_at) VALUES (?, ?, ?, ?)",
            (cycle["user_id"], cycle_id, operator_id, utc_now()),
        )
        db.execute("UPDATE menu_cycles SET status = 'approved', approved_at = ? WHERE id = ?",
                   (utc_now(), cycle_id))
    return {"id": cycle_id, "status": "approved"}


def _replace(settings: Settings, item_id: int, actor_id: int, new_code: str,
             expected_version: int, actor_role: str) -> dict[str, Any]:
    catalog = read_catalog(settings)
    recipe = catalog["recipes"].get(new_code)
    if recipe is None:
        raise MenuError("recipe_not_found", "Plato no disponible", 404)
    with connection(settings) as db:
        row = db.execute(
            "SELECT mi.*, mc.user_id, mc.status FROM menu_items mi "
            "JOIN menu_cycles mc ON mc.id = mi.cycle_id WHERE mi.id = ?", (item_id,)
        ).fetchone()
        if row is None:
            raise MenuError("not_found", "Comida no encontrada", 404)
        if row["slot"] not in recipe["slots"]:
            raise MenuError("wrong_slot", "El plato no está disponible para esa comida")
        if row["version"] != expected_version:
            raise MenuError("version_conflict", "La comida cambió; actualiza la semana antes de guardar", 409)
        if actor_role == "operator":
            if row["status"] != "pending_review":
                raise MenuError("not_pending", "Solo se puede editar la primera propuesta pendiente", 409)
            profile = get_profile(settings, row["user_id"])
            if recipe not in eligible_recipes(catalog, profile, row["slot"]):
                raise MenuError("incompatible", "Este plato no cumple las restricciones registradas")
        else:
            if row["user_id"] != actor_id:
                raise MenuError("forbidden", "No puedes modificar este menú", 403)
            if row["status"] != "approved" or week_start(date.fromisoformat(row["day"])) <= week_start(local_today()):
                raise MenuError("not_editable", "Solo puedes cambiar comidas de semanas futuras", 409)
        old_code = row["recipe_code"]
        db.execute(
            "UPDATE menu_items SET recipe_code = ?, source = ?, version = version + 1 WHERE id = ?",
            (new_code, actor_role, item_id),
        )
        db.execute(
            "INSERT INTO swaps(item_id, actor_id, old_recipe_code, new_recipe_code, created_at) "
            "VALUES (?, ?, ?, ?, ?)", (item_id, actor_id, old_code, new_code, utc_now()),
        )
    return {"id": item_id, "recipe_code": new_code, "version": expected_version + 1,
            "allergens": recipe["allergens"]}


def client_swap(settings: Settings, item_id: int, user_id: int,
                recipe_code: str, expected_version: int) -> dict[str, Any]:
    return _replace(settings, item_id, user_id, recipe_code, expected_version, "client")


def operator_replace(settings: Settings, item_id: int, operator_id: int,
                     recipe_code: str, expected_version: int) -> dict[str, Any]:
    return _replace(settings, item_id, operator_id, recipe_code, expected_version, "operator")


def save_feedback(settings: Settings, user_id: int, item_id: int,
                  rating: int, comment: str) -> dict[str, Any]:
    with connection(settings) as db:
        item = db.execute(
            "SELECT mi.day, mi.recipe_code, mc.user_id, mc.status FROM menu_items mi "
            "JOIN menu_cycles mc ON mc.id = mi.cycle_id WHERE mi.id = ?", (item_id,)
        ).fetchone()
        if item is None or item["user_id"] != user_id:
            raise MenuError("not_found", "Plato no encontrado", 404)
        if item["status"] != "approved" or date.fromisoformat(item["day"]) > local_today():
            raise MenuError("feedback_unavailable", "Podrás opinar cuando llegue el día del plato", 409)
        db.execute(
            "INSERT INTO feedback(item_id, user_id, rating, comment, created_at) VALUES (?, ?, ?, ?, ?) "
            "ON CONFLICT(item_id, user_id) DO UPDATE SET rating=excluded.rating, "
            "comment=excluded.comment, created_at=excluded.created_at",
            (item_id, user_id, rating, comment.strip(), utc_now()),
        )
    return {"item_id": item_id, "rating": rating, "comment": comment.strip()}


def get_delivery(settings: Settings, user_id: int, selected_day: date) -> dict[str, Any]:
    profile = get_profile(settings, user_id)
    if profile is None or profile["plan"] != "pro":
        raise MenuError("pro_required", "La entrega solo está disponible en el plan Pro", 403)
    week = get_week(settings, user_id, selected_day)
    return {"week_start": week["week_start"], "address": profile["address"],
            "status": "entregada_simulada" if date.fromisoformat(week["week_end"]) < local_today()
            else "planificada_simulada" if week["items"] else "sin_menu",
            "items_count": len(week["items"]), "simulated": True}
