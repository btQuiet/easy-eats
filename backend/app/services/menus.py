import asyncio
import hashlib
import json
import logging
from datetime import date, timedelta
from uuid import UUID

from ..domain import Problem, dump, fold, monday, next_month, slots_for, uid, validate_output
from ..integrations.generation import GroqGenerator, TestGenerator
from .profiles import version

LOG = logging.getLogger(__name__)


class Menus:
    def __init__(self, database, catalog, profiles, settings, clock, generator=None):
        self.database, self.catalog, self.profiles = database, catalog, profiles
        self.settings, self.clock = settings, clock
        self.generator = generator or (TestGenerator() if settings.mode == "test" else GroqGenerator(settings))
        self.wake = asyncio.Event()

    def input_versions(self, db, user, month):
        p = self.profiles.get(db, user)
        cal, _ = self.profiles.calendar(db, user, month)
        return {"profile": p["version"], "preferences": p["preferences_version"],
                "calendar_id": cal["id"] if cal else None, "catalog_hash": self.catalog.hash}

    def cycle(self, db, ident):
        row = db.execute("SELECT * FROM menu_cycles WHERE id=?", (ident,)).fetchone()
        if not row:
            raise Problem("NOT_FOUND", "Ciclo no encontrado.", 404)
        return row

    def cycle_dto(self, db, cycle):
        proposal = db.execute("SELECT * FROM generation_attempts WHERE id=?", (cycle["proposal_generation_id"],)).fetchone()
        count = db.execute("SELECT COUNT(*),COALESCE(SUM(cancelled),0) FROM menu_items WHERE cycle_id=?", (cycle["id"],)).fetchone()
        reviewed = db.execute("SELECT 1 FROM initial_reviews WHERE user_id=?", (cycle["user_id"],)).fetchone()
        return {"id": cycle["id"], "month": cycle["month"], "status": cycle["status"],
                "version": cycle["version"], "service_start_date": cycle["service_start_date"],
                "requires_initial_review": not bool(reviewed), "published_at": cycle["published_at"],
                "generation_origin": proposal["origin"] if proposal else None,
                "latest_generation_id": cycle["latest_attempt_id"],
                "input_versions": json.loads(proposal["input_snapshot_json"])["versions"] if proposal else None,
                "warnings": json.loads(proposal["warning_json"]) if proposal else [],
                "item_count": count[0], "cancelled_count": count[1]}

    def attempt_dto(self, attempt):
        result = {k: attempt[k] for k in ("id", "cycle_id", "state", "origin", "provider", "model", "created_at", "started_at", "finished_at")}
        result["error"] = json.loads(attempt["error_json"]) if attempt["error_json"] else None
        result["retry_after"] = result["error"]["details"].get("retry_after") if result["error"] else None
        return result

    def item(self, db, ident):
        item = db.execute("SELECT i.*,c.user_id,c.status AS cycle_status,c.month FROM menu_items i JOIN menu_cycles c ON c.id=i.cycle_id WHERE i.id=?", (ident,)).fetchone()
        if not item:
            raise Problem("NOT_FOUND", "Comida no encontrada.", 404)
        return item

    def item_dto(self, item):
        today = self.clock.today().isoformat()
        return {"id": item["id"], "cycle_id": item["cycle_id"], "date": item["date"],
                "meal_slot": item["meal_slot"], "recipe_code": item["recipe_code"],
                "recipe_snapshot": json.loads(item["recipe_snapshot_json"]), "version": item["version"],
                "compatibility": item["compatibility"],
                "incompatibility_reasons": json.loads(item["incompatibility_reasons_json"]),
                "cancelled": bool(item["cancelled"]),
                "can_swap": item["cycle_status"] == "approved" and not item["cancelled"] and item["date"] > today,
                "can_feedback": item["cycle_status"] == "approved" and not item["cancelled"] and item["date"] <= today}

    def own_item(self, db, ident, user):
        item = self.item(db, ident)
        if item["user_id"] != user or item["cycle_status"] != "approved":
            raise Problem("NOT_FOUND", "Comida no encontrada.", 404)
        return item

    def snapshot(self, db, cycle):
        p = self.profiles.require_completed(db, cycle["user_id"])
        cal, slots = self.profiles.calendar(db, cycle["user_id"], cycle["month"])
        wanted = slots_for(cycle["month"], slots, cycle["service_start_date"])
        missing = [m for m in {s["meal_slot"] for s in wanted} if not self.catalog.candidates(p, m)]
        if missing:
            raise Problem("NO_CANDIDATES", "No hay platos compatibles para todas las comidas elegidas.", meal_slots=sorted(missing))
        if not any(s["date"] > self.clock.today().isoformat() for s in wanted):
            raise Problem("CYCLE_EXPIRED", "No quedan comidas futuras en ese mes.", 409, suggested_month=next_month(cycle["month"]))
        # Approved history only; never the proposal being replaced.
        history = [dict(x) for x in db.execute(
            "SELECT i.date,i.meal_slot,i.recipe_code FROM menu_items i JOIN menu_cycles c ON c.id=i.cycle_id WHERE c.user_id=? AND c.status='approved' AND c.id<>? AND i.cancelled=0 AND i.date>=? ORDER BY i.date",
            (cycle["user_id"], cycle["id"], (date.fromisoformat(cycle["month"] + "-01") - timedelta(days=14)).isoformat()))]
        ratings = {r[0]: r[1] for r in db.execute(
            "SELECT f.recipe_code,AVG(f.rating) FROM feedback f JOIN menu_items i ON i.id=f.item_id WHERE f.user_id=? AND i.date>=? AND i.date<=? GROUP BY f.recipe_code",
            (cycle["user_id"], (self.clock.today() - timedelta(days=89)).isoformat(), self.clock.today().isoformat()))}
        return {"profile": p, "slots": wanted, "history": history, "ratings": ratings,
                "versions": self.input_versions(db, cycle["user_id"], cycle["month"]), "base_cycle_version": cycle["version"]}

    def queue(self, db, cycle, actor):
        active = db.execute("SELECT * FROM generation_attempts WHERE cycle_id=? AND state IN('queued','running')", (cycle["id"],)).fetchone()
        if active:
            return 202, self.attempt_dto(active)
        if self.settings.mode == "ai" and not self.settings.groq_key:
            raise Problem("AI_NOT_CONFIGURED", "Configura GROQ_API_KEY en el servidor para generar.", 503)
        snap = self.snapshot(db, cycle)
        ident = uid()
        db.execute("INSERT INTO generation_attempts(id,cycle_id,actor_id,state,origin,provider,model,input_snapshot_json,input_hash,catalog_hash,created_at) VALUES(?,?,?,'queued',?,?,?,?,?,?,?)",
                   (ident, cycle["id"], actor, self.settings.mode,
                    "groq" if self.settings.mode == "ai" else None,
                    self.settings.groq_model if self.settings.mode == "ai" else None,
                    dump(snap), hashlib.sha256(dump(snap).encode()).hexdigest(), self.catalog.hash, self.clock.stamp()))
        db.execute("UPDATE menu_cycles SET latest_attempt_id=? WHERE id=?", (ident, cycle["id"]))
        self.wake.set()
        return 202, self.attempt_dto(db.execute("SELECT * FROM generation_attempts WHERE id=?", (ident,)).fetchone())

    def ensure(self, db, user, actor, month):
        p = self.profiles.require_completed(db, user)
        from ..domain import month_dates
        month_dates(month)
        current = self.clock.today().strftime("%Y-%m")
        if month not in (current, next_month(current)) or month < p["service_start_date"][:7]:
            raise Problem("INVALID_INPUT", "Solo se admite el mes actual o siguiente, a partir del inicio.", suggested_month=max(current, p["service_start_date"][:7]))
        old = db.execute("SELECT * FROM menu_cycles WHERE user_id=? AND month=?", (user, month)).fetchone()
        if old and old["status"] == "approved":
            return 200, self.cycle_dto(db, old)
        if old and old["status"] == "expired":
            raise Problem("CYCLE_EXPIRED", "El ciclo ya no tiene comidas futuras.", 409, suggested_month=next_month(month))
        if not p["initial_review_completed"]:
            live = db.execute("SELECT * FROM menu_cycles WHERE user_id=? AND month<>? AND status IN('draft','pending_review')", (user, month)).fetchone()
            if live:
                raise Problem("INITIAL_REVIEW_PENDING", "La primera propuesta está pendiente de revisión.", 409, month=live["month"])
        if old and old["status"] == "pending_review":
            if self.cycle_dto(db, old)["input_versions"] == self.input_versions(db, user, month):
                return 200, self.cycle_dto(db, old)
        if not old:
            start = max(month + "-01", p["service_start_date"])
            ident = uid()
            db.execute("INSERT INTO menu_cycles(id,user_id,month,status,service_start_date) VALUES(?,?,?,'draft',?)", (ident, user, month, start))
            old = self.cycle(db, ident)
        return self.queue(db, old, actor)

    def expire(self, db):
        today = self.clock.today().isoformat()
        for c in db.execute("SELECT * FROM menu_cycles WHERE status IN('draft','pending_review')").fetchall():
            _, slots = self.profiles.calendar(db, c["user_id"], c["month"])
            if not any(x["date"] > today for x in slots_for(c["month"], slots, c["service_start_date"])):
                db.execute("UPDATE menu_cycles SET status='expired',version=version+1 WHERE id=?", (c["id"],))

    def review(self, db, ident):
        c = self.cycle(db, ident)
        if c["status"] not in ("pending_review", "draft"):
            raise Problem("ITEM_NOT_EDITABLE", "Este ciclo ya no está pendiente.", 409)
        dto = self.cycle_dto(db, c)
        dto["profile"] = self.profiles.get(db, c["user_id"])
        dto["user"] = dict(db.execute("SELECT id,alias_normalized AS alias FROM users WHERE id=?", (c["user_id"],)).fetchone())
        dto["items"] = [self.item_dto(self.item(db, x[0])) for x in db.execute("SELECT id FROM menu_items WHERE cycle_id=? ORDER BY date,CASE meal_slot WHEN 'desayuno' THEN 0 WHEN 'comida' THEN 1 WHEN 'merienda' THEN 2 ELSE 3 END", (ident,))]
        dto["requires_refresh"] = dto["input_versions"] != self.input_versions(db, c["user_id"], c["month"])
        latest = db.execute("SELECT * FROM generation_attempts WHERE id=?", (c["latest_attempt_id"],)).fetchone()
        dto["latest_generation"] = self.attempt_dto(latest) if latest else None
        proposal = db.execute("SELECT input_snapshot_json FROM generation_attempts WHERE id=?", (c["proposal_generation_id"],)).fetchone()
        dto["input_snapshot"] = json.loads(proposal[0])["profile"] if proposal else None
        today = self.clock.today().isoformat()
        future = [item for item in dto["items"] if not item["cancelled"] and item["date"] > today]
        blockers = []
        try:
            self.approval_check(db, c, dto)
        except Problem as error:
            blockers.append(error.payload())
        dto["review_summary"] = {
            "future_item_count": len(future),
            "elapsed_item_count": sum(not item["cancelled"] and item["date"] <= today for item in dto["items"]),
            "first_future_date": future[0]["date"] if future else None,
            "can_approve": not blockers,
            "blocking_reasons": blockers,
        }
        def labels(codes, options):
            names = {option["code"]: option["name"] for option in options}
            return [{"code": code, "name": names.get(code, code), "known": code in names} for code in codes]
        p = dto["profile"]
        dto["profile_labels"] = {
            "allergens": labels(p["allergen_codes"], self.catalog.allergens),
            "excluded_ingredients": labels(p["excluded_ingredient_codes"], self.catalog.ingredients),
            "liked_ingredients": labels(p["liked_ingredient_codes"], self.catalog.ingredients),
            "disliked_ingredients": labels(p["disliked_ingredient_codes"], self.catalog.ingredients),
        }
        return dto

    def approval_check(self, db, c, dto=None):
        """Use the same readiness rules for review and the publication transaction."""
        if c["status"] == "expired":
            raise Problem("CYCLE_EXPIRED", "No quedan comidas futuras.", 409, suggested_month=next_month(c["month"]))
        if c["status"] != "pending_review":
            raise Problem("ITEM_NOT_EDITABLE", "Solo se aprueba una primera propuesta pendiente.", 409)
        if db.execute("SELECT 1 FROM generation_attempts WHERE cycle_id=? AND state IN('queued','running')", (c["id"],)).fetchone():
            raise Problem("GENERATION_IN_PROGRESS", "Espera a que termine la generación.", 409)
        dto = dto or self.cycle_dto(db, c)
        if dto["input_versions"] != self.input_versions(db, c["user_id"], c["month"]):
            raise Problem("INPUT_CHANGED", "El perfil cambió. Regenera la propuesta.", 409)
        rows = db.execute("SELECT * FROM menu_items WHERE cycle_id=? AND cancelled=0 AND date>?", (c["id"], self.clock.today().isoformat())).fetchall()
        if not rows:
            raise Problem("CYCLE_EXPIRED", "No quedan comidas futuras.", 409, suggested_month=next_month(c["month"]))
        p = self.profiles.get(db, c["user_id"])
        for item in rows:
            recipe = self.catalog.recipes.get(item["recipe_code"])
            if recipe is None or self.catalog.reasons(recipe, p, item["meal_slot"]):
                raise Problem("RECIPE_INCOMPATIBLE", "Hay platos incompatibles en la propuesta.", 409)
        return rows

    def approve(self, db, ident, actor, expected):
        c = self.cycle(db, ident)
        version(c, expected)
        self.approval_check(db, c)
        db.execute("UPDATE menu_items SET cancelled=1,cancellation_reason='ELAPSED_BEFORE_APPROVAL' WHERE cycle_id=? AND date<=?", (ident, self.clock.today().isoformat()))
        db.execute("INSERT INTO initial_reviews VALUES(?,?,?,?,?,?)", (uid(), c["user_id"], ident, actor, c["version"] + 1, self.clock.stamp()))
        db.execute("UPDATE menu_cycles SET status='approved',version=version+1,published_at=? WHERE id=?", (self.clock.stamp(), ident))
        return 200, self.cycle_dto(db, self.cycle(db, ident))

    def candidates(self, db, item, query=""):
        p = self.profiles.get(db, item["user_id"])
        return sorted([dict(r, compatible=True, incompatibility_reasons=[]) for r in self.catalog.candidates(p, item["meal_slot"])
                       if fold(query) in fold(r["name"] + " " + " ".join(i["name"] for i in r["ingredients"]))],
                      key=lambda r: (fold(r["name"]), r["code"]))

    def substitute(self, db, ident, user, expected, code, operator=False):
        item = self.item(db, ident) if operator else self.own_item(db, ident, user)
        version(item, expected)
        if operator:
            if item["cycle_status"] != "pending_review":
                raise Problem("ITEM_NOT_EDITABLE", "Solo se corrige una propuesta pendiente.", 409)
            if db.execute("SELECT 1 FROM generation_attempts WHERE cycle_id=? AND state IN('queued','running')", (item["cycle_id"],)).fetchone():
                raise Problem("GENERATION_IN_PROGRESS", "Espera a que termine la generación.", 409)
        elif not self.item_dto(item)["can_swap"]:
            raise Problem("ITEM_NOT_EDITABLE", "Solo puedes cambiar comidas futuras aprobadas.", 409)
        r = self.catalog.recipe(code)
        reasons = self.catalog.reasons(r, self.profiles.get(db, item["user_id"]), item["meal_slot"])
        if reasons:
            raise Problem("RECIPE_INCOMPATIBLE", "Ese plato no es compatible.", reasons=reasons)
        if code == item["recipe_code"]:
            raise Problem("INVALID_INPUT", "Elige un plato diferente.")
        db.execute("UPDATE menu_items SET recipe_code=?,recipe_snapshot_json=?,version=version+1,compatibility='compatible',incompatibility_reasons_json='[]' WHERE id=?", (code, dump(r), ident))
        db.execute("UPDATE menu_cycles SET version=version+1 WHERE id=?", (item["cycle_id"],))
        audit = uid()
        c = self.cycle(db, item["cycle_id"])
        if operator:
            db.execute("INSERT INTO operator_corrections VALUES(?,?,?,?,?,?,?,?)", (audit, c["id"], ident, user, item["recipe_code"], code, self.clock.stamp(), c["version"]))
            return 200, {"item": self.item_dto(self.item(db, ident)), "cycle_version": c["version"]}
        db.execute("INSERT INTO swaps VALUES(?,?,?,?,?,?,?,?)", (audit, ident, user, item["recipe_code"], code, expected, expected + 1, self.clock.stamp()))
        return 200, {"item": self.item_dto(self.item(db, ident)), "swap_id": audit}

    def feedback(self, db, ident, user, expected, rating, comment):
        item = self.own_item(db, ident, user)
        if not self.item_dto(item)["can_feedback"]:
            raise Problem("ITEM_NOT_EDITABLE", "Solo se opina sobre comidas ya disponibles.", 409)
        if type(rating) is not int or rating not in (-1, 1) or not isinstance(comment, str) or len(comment) > 500:
            raise Problem("INVALID_INPUT", "Opinión no válida.")
        old = db.execute("SELECT * FROM feedback WHERE item_id=?", (ident,)).fetchone()
        version(old or {"version": 0}, expected)
        db.execute("INSERT INTO feedback VALUES(?,?,?,?,?,?,?,?,?) ON CONFLICT(item_id) DO UPDATE SET rating=excluded.rating,comment=excluded.comment,version=excluded.version,updated_at=excluded.updated_at",
                   (old["id"] if old else uid(), user, ident, item["recipe_code"], rating, comment.strip(), expected + 1, old["created_at"] if old else self.clock.stamp(), self.clock.stamp()))
        db.execute("UPDATE profiles SET preferences_version=preferences_version+1 WHERE user_id=?", (user,))
        result = dict(db.execute("SELECT * FROM feedback WHERE item_id=?", (ident,)).fetchone())
        result.pop("user_id")
        return result

    def week(self, db, user, start):
        try:
            d = date.fromisoformat(start)
            if d.weekday() != 0 or d.isoformat() != start:
                raise ValueError()
            end = d + timedelta(days=6)
        except (ValueError, TypeError, OverflowError):
            raise Problem("INVALID_INPUT", "La semana debe comenzar un lunes.")
        p = self.profiles.require_completed(db, user)
        segments = []
        attempts = []
        for month in sorted({(d + timedelta(days=n)).strftime("%Y-%m") for n in range(7)}):
            c = db.execute("SELECT * FROM menu_cycles WHERE user_id=? AND month=?", (user, month)).fetchone()
            segments.append({"month": month, "status": c["status"] if c else "missing", "cycle_id": c["id"] if c else None})
            if c:
                attempts += [x[0] for x in db.execute("SELECT id FROM generation_attempts WHERE cycle_id=? AND state IN('queued','running')", (c["id"],))]
        days = []
        for n in range(7):
            day = d + timedelta(days=n)
            _, cal = self.profiles.calendar(db, user, day.strftime("%Y-%m"))
            scheduled = cal[day.weekday()]["meal_slots"] if day.isoformat() >= p["service_start_date"] else []
            ids = [x[0] for x in db.execute("SELECT i.id FROM menu_items i JOIN menu_cycles c ON c.id=i.cycle_id WHERE c.user_id=? AND c.status='approved' AND i.date=? AND i.cancelled=0 ORDER BY CASE i.meal_slot WHEN 'desayuno' THEN 0 WHEN 'comida' THEN 1 WHEN 'merienda' THEN 2 ELSE 3 END", (user, day.isoformat()))]
            days.append({"date": day.isoformat(), "scheduled_slots": scheduled, "items": [self.item_dto(self.item(db, ident)) for ident in ids]})
        visible = [item for day in days for item in day["items"]]
        today = self.clock.today().isoformat()
        return {"start": start, "end": end.isoformat(), "days": days, "cycle_segments": segments,
                "summary": {"published_item_count": len(visible),
                            "today_item_count": sum(item["date"] == today for item in visible),
                            "future_item_count": sum(item["date"] > today for item in visible),
                            "attention_item_count": sum(item["date"] >= today and item["compatibility"] == "needs_attention" for item in visible),
                            "next_item_id": next((item["id"] for item in visible if item["date"] >= today), None)},
                "pending_generation_ids": attempts,
                "pending_initial_review": not p["initial_review_completed"],
                "can_view_delivery": self.profiles.plan(db, user)["can_view_delivery"]}

    def idempotent(self, db, user, key, operation, body, action):
        try:
            UUID(key)
        except (ValueError, TypeError, AttributeError):
            raise Problem("INVALID_INPUT", "Idempotency-Key debe ser un UUID.")
        digest = hashlib.sha256(dump(body).encode()).hexdigest()
        db.execute("DELETE FROM idempotency_operations WHERE expires_at<=?", (self.clock.stamp(),))
        old = db.execute("SELECT * FROM idempotency_operations WHERE user_id=? AND key=?", (user, key)).fetchone()
        if old:
            if old["operation_name"] != operation or old["request_hash"] != digest:
                raise Problem("IDEMPOTENCY_CONFLICT", "Esa clave pertenece a otra operación.", 409)
            result = json.loads(old["result_json"])
            return result["status"], result["data"]
        status, data = action()
        state = "pending" if status == 202 and data.get("state") in ("queued", "running") else "completed"
        db.execute("INSERT INTO idempotency_operations VALUES(?,?,?,?,?,?,?)",
                   (user, operation, key, digest, state, dump({"status": status, "data": data}),
                    (self.clock.now() + timedelta(hours=24)).isoformat()))
        return status, data

    def recover(self, db):
        for a in db.execute("SELECT * FROM generation_attempts WHERE state='running'").fetchall():
            self.fail(db, a, Problem("SERVER_RESTARTED", "El servidor se reinició durante la generación.", 503))
        old_hash = db.execute("SELECT value FROM runtime_info WHERE key='catalog_hash'").fetchone()
        if not old_hash or old_hash[0] != self.catalog.hash:
            for u in db.execute("SELECT user_id FROM profiles WHERE completed=1").fetchall():
                self.profiles.reevaluate(db, u[0])
        db.execute("INSERT OR REPLACE INTO runtime_info VALUES('catalog_hash',?)", (self.catalog.hash,))
        self.expire(db)

    def complete_operations(self, db, attempt):
        dto = self.attempt_dto(attempt)
        for op in db.execute("SELECT * FROM idempotency_operations WHERE state='pending'").fetchall():
            result = json.loads(op["result_json"])
            if result["data"].get("id") == attempt["id"]:
                db.execute("UPDATE idempotency_operations SET state='completed',result_json=? WHERE user_id=? AND key=?",
                           (dump({"status": 202, "data": dto}), op["user_id"], op["key"]))

    def fail(self, db, attempt, problem):
        state = "cancelled" if problem.code == "INPUT_CHANGED" else "failed"
        db.execute("UPDATE generation_attempts SET state=?,error_json=?,finished_at=? WHERE id=?", (state, dump(problem.payload()), self.clock.stamp(), attempt["id"]))
        self.complete_operations(db, db.execute("SELECT * FROM generation_attempts WHERE id=?", (attempt["id"],)).fetchone())

    async def work_one(self):
        with self.database.transaction() as db:
            a = db.execute("SELECT * FROM generation_attempts WHERE state='queued' ORDER BY created_at,id LIMIT 1").fetchone()
            if not a:
                return False
            a = dict(a)
            db.execute("UPDATE generation_attempts SET state='running',started_at=? WHERE id=?", (self.clock.stamp(), a["id"]))
        try:
            snapshot = json.loads(a["input_snapshot_json"])
            items, warnings = await asyncio.wait_for(self.generator.generate(snapshot, self.catalog), 120)
            items, warnings = validate_output(items, snapshot, self.catalog)
            with self.database.transaction() as db:
                c = self.cycle(db, a["cycle_id"])
                if snapshot["versions"] != self.input_versions(db, c["user_id"], c["month"]) or snapshot["base_cycle_version"] != c["version"] or c["status"] == "expired":
                    raise Problem("INPUT_CHANGED", "Los datos cambiaron durante la generación.", 409)
                # Keep identities for existing slot audit references; removed slots become cancelled.
                db.execute("UPDATE menu_items SET cancelled=1,cancellation_reason='PROPOSAL_REPLACED' WHERE cycle_id=?", (c["id"],))
                reviewed = bool(db.execute("SELECT 1 FROM initial_reviews WHERE user_id=?", (c["user_id"],)).fetchone())
                for item in items:
                    cancelled = reviewed and item["date"] <= self.clock.today().isoformat()
                    db.execute("INSERT INTO menu_items(id,cycle_id,date,meal_slot,recipe_code,recipe_snapshot_json,compatibility,cancelled,cancellation_reason) VALUES(?,?,?,?,?,?,'compatible',?,?) ON CONFLICT(cycle_id,date,meal_slot) DO UPDATE SET recipe_code=excluded.recipe_code,recipe_snapshot_json=excluded.recipe_snapshot_json,version=menu_items.version+1,compatibility='compatible',incompatibility_reasons_json='[]',cancelled=excluded.cancelled,cancellation_reason=excluded.cancellation_reason",
                               (uid(), c["id"], item["date"], item["meal_slot"], item["recipe_code"], dump(self.catalog.recipe(item["recipe_code"])), int(cancelled), "ELAPSED_BEFORE_PUBLICATION" if cancelled else None))
                db.execute("UPDATE generation_attempts SET state='succeeded',proposed_items_json=?,warning_json=?,finished_at=? WHERE id=?", (dump(items), dump(warnings), self.clock.stamp(), a["id"]))
                db.execute("UPDATE menu_cycles SET proposal_generation_id=?,status=?,version=version+1,published_at=? WHERE id=?", (a["id"], "approved" if reviewed else "pending_review", self.clock.stamp() if reviewed else None, c["id"]))
                self.complete_operations(db, db.execute("SELECT * FROM generation_attempts WHERE id=?", (a["id"],)).fetchone())
        except asyncio.CancelledError:
            raise  # A restart records SERVER_RESTARTED for the persisted running attempt.
        except Exception as error:
            if not isinstance(error, Problem):
                LOG.exception("Generation failed: %s", a["id"])
            problem = error if isinstance(error, Problem) else Problem("AI_UNAVAILABLE", "La generación no pudo completarse.", 503)
            with self.database.transaction() as db:
                self.fail(db, a, problem)
        return True

    async def worker(self):
        while True:
            self.wake.clear()
            while await self.work_one():
                await asyncio.sleep(0)
            try:
                await asyncio.wait_for(self.wake.wait(), 2)
            except asyncio.TimeoutError:
                pass
