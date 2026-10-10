import json
from datetime import timedelta

from ..domain import DEFAULT_SLOTS, MEALS, Problem, dump, month_dates, next_month, uid

LISTS = {"allergen_codes": ("profile_allergens", "allergen_code"),
         "excluded_ingredient_codes": ("excluded_ingredients", "ingredient_code"),
         "preferred_categories": ("category_preferences", "category")}
FOOD_FIELDS = {"diet", "allergen_codes", "excluded_ingredient_codes", "liked_ingredient_codes",
               "disliked_ingredient_codes", "preferred_categories", "repetition_tolerance"}
PREF_FIELDS = {"liked_ingredient_codes", "disliked_ingredient_codes", "preferred_categories", "repetition_tolerance"}
STEPS = {"plan": {"plan"}, "calendar": {"weekly_slots"},
         "restrictions": {"diet", "allergen_codes", "excluded_ingredient_codes"},
         "preferences": PREF_FIELDS, "summary": {"service_start_date", "address"}}


def version(row, expected):
    if row["version"] != expected:
        raise Problem("VERSION_CONFLICT", "El dato ha cambiado. Recarga antes de guardar.", 409,
                      current_version=row["version"])


class Profiles:
    def __init__(self, catalog, clock):
        self.catalog, self.clock = catalog, clock

    def calendar(self, db, user, month=None, latest=False):
        if latest:
            row = db.execute("SELECT * FROM weekly_calendars WHERE user_id=? ORDER BY effective_month DESC,revision DESC LIMIT 1", (user,)).fetchone()
        else:
            row = db.execute("SELECT * FROM weekly_calendars WHERE user_id=? AND effective_month<=? ORDER BY effective_month DESC,revision DESC LIMIT 1", (user, month)).fetchone()
        if not row:
            return None, DEFAULT_SLOTS
        slots = [{"weekday": n, "meal_slots": [m for m in MEALS if db.execute(
            "SELECT 1 FROM weekly_slots WHERE calendar_id=? AND weekday=? AND meal_slot=?", (row["id"], n, m)).fetchone()]}
                 for n in range(1, 8)]
        return dict(row), slots

    def get(self, db, user):
        row = db.execute("SELECT * FROM profiles WHERE user_id=?", (user,)).fetchone()
        if not row:
            raise Problem("NOT_FOUND", "Perfil no encontrado.", 404)
        result = dict(row)
        result.pop("user_id")
        result["completed"] = bool(row["completed"])
        for key, (table, col) in LISTS.items():
            result[key] = [x[0] for x in db.execute(f"SELECT {col} FROM {table} WHERE user_id=? ORDER BY {col}", (user,))]
        for name, weight in (("liked_ingredient_codes", 1), ("disliked_ingredient_codes", -1)):
            result[name] = [x[0] for x in db.execute("SELECT ingredient_code FROM ingredient_preferences WHERE user_id=? AND weight=? ORDER BY ingredient_code", (user, weight))]
        cal, slots = self.calendar(db, user, latest=True)
        result.update(weekly_slots=slots, calendar_revision=cal["revision"] if cal else 0,
                      calendar_effective_month=cal["effective_month"] if cal else None,
                      initial_review_completed=bool(db.execute("SELECT 1 FROM initial_reviews WHERE user_id=?", (user,)).fetchone()))
        effective = (result["service_start_date"] or self.clock.today().isoformat())[:7] if not result["initial_review_completed"] else next_month(self.clock.today().strftime("%Y-%m"))
        while db.execute("SELECT 1 FROM menu_cycles WHERE user_id=? AND month=? AND status='approved'", (user, effective)).fetchone():
            effective = next_month(effective)
        result["next_calendar_effective_month"] = effective
        if not result["completed"]:
            draft = db.execute("SELECT fields_json FROM onboarding_drafts WHERE user_id=?", (user,)).fetchone()
            result.update(json.loads(draft[0]) if draft else {})
        return result

    def require_completed(self, db, user):
        p = self.get(db, user)
        if not p["completed"]:
            raise Problem("PROFILE_INCOMPLETE", "Termina primero la configuración.", 409)
        return p

    def validate(self, fields):
        if "diet" in fields and fields["diet"] not in ("omnivore", "vegetarian", "vegan"):
            raise Problem("INVALID_INPUT", "Dieta no válida.")
        if "repetition_tolerance" in fields and fields["repetition_tolerance"] not in ("low", "normal", "high"):
            raise Problem("INVALID_INPUT", "Tolerancia no válida.")
        allowed = {"allergen_codes": {x["code"] for x in self.catalog.allergens},
                   "excluded_ingredient_codes": {x["code"] for x in self.catalog.ingredients},
                   "liked_ingredient_codes": {x["code"] for x in self.catalog.ingredients},
                   "disliked_ingredient_codes": {x["code"] for x in self.catalog.ingredients},
                   "preferred_categories": set(self.catalog.categories)}
        for key, codes in allowed.items():
            if key in fields:
                v = fields[key]
                if not isinstance(v, list) or any(not isinstance(c, str) for c in v) or len(v) != len(set(v)) or set(v) - codes:
                    raise Problem("INVALID_INPUT", "Hay códigos desconocidos o duplicados.", field=key)
        if set(fields.get("liked_ingredient_codes", [])) & set(fields.get("disliked_ingredient_codes", [])):
            raise Problem("INVALID_INPUT", "Un ingrediente no puede gustarte y disgustarte a la vez.")
        if "weekly_slots" in fields:
            slots = fields["weekly_slots"]
            if not isinstance(slots, list) or len(slots) != 7:
                raise Problem("INVALID_INPUT", "El calendario necesita los siete días.")
            days = []
            total = 0
            for x in slots:
                if not isinstance(x, dict) or set(x) != {"weekday", "meal_slots"} or type(x["weekday"]) is not int or x["weekday"] not in range(1, 8):
                    raise Problem("INVALID_INPUT", "Día de calendario no válido.")
                meals = x["meal_slots"]
                if not isinstance(meals, list) or any(not isinstance(m, str) for m in meals) or len(meals) != len(set(meals)) or set(meals) - set(MEALS):
                    raise Problem("INVALID_INPUT", "Comidas desconocidas o duplicadas.")
                days.append(x["weekday"])
                total += len(meals)
            if len(set(days)) != 7 or total == 0:
                raise Problem("INVALID_INPUT", "Elige al menos una comida semanal, sin repetir días.")
        if "plan" in fields and fields["plan"] not in ("free", "pro"):
            raise Problem("INVALID_INPUT", "Plan no válido.")
        if "service_start_date" in fields:
            from datetime import date
            try:
                d = date.fromisoformat(fields["service_start_date"])
                if d.isoformat() != fields["service_start_date"]:
                    raise ValueError()
            except (ValueError, TypeError):
                raise Problem("INVALID_INPUT", "Fecha de inicio no válida.")
            maximum = month_dates(next_month(self.clock.today().strftime("%Y-%m")))[-1]
            if not self.clock.today() < d <= maximum:
                raise Problem("INVALID_INPUT", "El inicio debe estar entre mañana y el final del próximo mes.")
        if "address" in fields:
            self.validate_address(fields["address"])

    def validate_address(self, address):
        if not isinstance(address, dict) or set(address) - {"line1", "city", "postal_code", "notes"}:
            raise Problem("INVALID_INPUT", "Dirección no válida.")
        for key, maximum in (("line1", 150), ("city", 80), ("postal_code", 12), ("notes", 250)):
            text = address.get(key, "")
            if not isinstance(text, str) or len(text) > maximum or (key != "notes" and not text.strip()):
                raise Problem("INVALID_INPUT", "Revisa la dirección ficticia.", field=key)

    def write_food(self, db, user, fields):
        db.execute("UPDATE profiles SET diet=?,repetition_tolerance=?,updated_at=? WHERE user_id=?",
                   (fields["diet"], fields["repetition_tolerance"], self.clock.stamp(), user))
        for key, (table, col) in LISTS.items():
            db.execute(f"DELETE FROM {table} WHERE user_id=?", (user,))
            db.executemany(f"INSERT INTO {table}(user_id,{col}) VALUES(?,?)", [(user, x) for x in fields[key]])
        db.execute("DELETE FROM ingredient_preferences WHERE user_id=?", (user,))
        db.executemany("INSERT INTO ingredient_preferences VALUES(?,?,?)",
                       [(user, x, weight) for key, weight in (("liked_ingredient_codes", 1), ("disliked_ingredient_codes", -1)) for x in fields[key]])

    def add_calendar(self, db, user, month, slots):
        revision = db.execute("SELECT COALESCE(MAX(revision),0)+1 FROM weekly_calendars WHERE user_id=? AND effective_month=?", (user, month)).fetchone()[0]
        ident = uid()
        db.execute("INSERT INTO weekly_calendars VALUES(?,?,?,?,?)", (ident, user, month, revision, self.clock.stamp()))
        db.executemany("INSERT INTO weekly_slots VALUES(?,?,?)", [(ident, x["weekday"], m) for x in slots for m in x["meal_slots"]])

    def save_draft(self, db, user, expected, step, fields):
        p = self.get(db, user)
        version(p, expected)
        if p["completed"]:
            raise Problem("PROFILE_ALREADY_COMPLETED", "La configuración ya está terminada.", 409)
        if step not in STEPS or set(fields) - STEPS[step]:
            raise Problem("INVALID_INPUT", "Campos no válidos para este paso.")
        self.validate(fields)
        old = json.loads(db.execute("SELECT fields_json FROM onboarding_drafts WHERE user_id=?", (user,)).fetchone()[0])
        old.update(fields)
        self.validate({k: old[k] for k in FOOD_FIELDS if k in old})
        db.execute("UPDATE onboarding_drafts SET fields_json=?,last_completed_step=?,updated_at=? WHERE user_id=?", (dump(old), step, self.clock.stamp(), user))
        db.execute("UPDATE profiles SET version=version+1,last_completed_step=?,updated_at=? WHERE user_id=?", (step, self.clock.stamp(), user))
        return self.get(db, user)

    def complete(self, db, user, expected):
        p = self.get(db, user)
        version(p, expected)
        if p["completed"]:
            raise Problem("PROFILE_ALREADY_COMPLETED", "El perfil ya está configurado.", 409)
        draft = json.loads(db.execute("SELECT fields_json FROM onboarding_drafts WHERE user_id=?", (user,)).fetchone()[0])
        if not {"plan", "weekly_slots", "service_start_date", "diet"} <= draft.keys():
            raise Problem("INVALID_INPUT", "Revisa todos los pasos antes de finalizar.")
        self.validate(p)
        if p["plan"] == "pro":
            if not p.get("address"):
                raise Problem("INVALID_INPUT", "Pro necesita una dirección ficticia.")
            self.save_address(db, user, 0, p["address"])
        self.write_food(db, user, p)
        self.add_calendar(db, user, p["service_start_date"][:7], p["weekly_slots"])
        db.execute("UPDATE profiles SET version=version+1,completed=1,last_completed_step='summary',service_start_date=? WHERE user_id=?", (p["service_start_date"], user))
        db.execute("UPDATE plan_memberships SET current_plan=? WHERE user_id=?", (p["plan"], user))
        db.execute("INSERT INTO plan_events VALUES(?,?,?,?,?,?,'initial')", (uid(), user, None, p["plan"], self.clock.today().isoformat(), self.clock.stamp()))
        return self.get(db, user)

    def reevaluate(self, db, user):
        p, affected = self.get(db, user), []
        rows = db.execute("SELECT i.* FROM menu_items i JOIN menu_cycles c ON c.id=i.cycle_id WHERE c.user_id=? AND i.date>=? AND i.cancelled=0", (user, self.clock.today().isoformat())).fetchall()
        cycles = set()
        for item in rows:
            r = self.catalog.recipes.get(item["recipe_code"])
            reasons = self.catalog.reasons(r, p, item["meal_slot"]) if r else ["UNKNOWN_RECIPE"]
            state = "needs_attention" if reasons else "compatible"
            if item["compatibility"] != state or item["incompatibility_reasons_json"] != dump(reasons):
                db.execute("UPDATE menu_items SET compatibility=?,incompatibility_reasons_json=?,version=version+1 WHERE id=?", (state, dump(reasons), item["id"]))
                cycles.add(item["cycle_id"])
                affected.append(item["id"])
        for cycle in cycles:
            db.execute("UPDATE menu_cycles SET version=version+1 WHERE id=?", (cycle,))
        return affected

    def patch(self, db, user, expected, fields):
        p = self.require_completed(db, user)
        version(p, expected)
        if not fields or set(fields) - FOOD_FIELDS:
            raise Problem("INVALID_INPUT", "Campos de perfil no válidos.")
        p.update(fields)
        validated = dict(fields)
        if set(fields) & {"liked_ingredient_codes", "disliked_ingredient_codes"}:
            validated.update({k: p[k] for k in ("liked_ingredient_codes", "disliked_ingredient_codes")})
        self.validate(validated)
        self.write_food(db, user, p)
        db.execute("UPDATE profiles SET version=version+1,preferences_version=preferences_version+? WHERE user_id=?", (int(bool(set(fields) & PREF_FIELDS)), user))
        affected = self.reevaluate(db, user)
        return dict(self.get(db, user), affected_items=affected)

    def edit_calendar(self, db, user, expected, slots):
        p = self.require_completed(db, user)
        version(p, expected)
        self.validate({"weekly_slots": slots})
        month = p["service_start_date"][:7] if not p["initial_review_completed"] else next_month(self.clock.today().strftime("%Y-%m"))
        while db.execute("SELECT 1 FROM menu_cycles WHERE user_id=? AND month=? AND status='approved'", (user, month)).fetchone():
            month = next_month(month)
        self.add_calendar(db, user, month, slots)
        db.execute("UPDATE profiles SET version=version+1 WHERE user_id=?", (user,))
        return self.get(db, user)

    def address(self, db, user):
        row = db.execute("SELECT * FROM delivery_addresses WHERE user_id=?", (user,)).fetchone()
        if not row:
            return None
        result = dict(row)
        result.pop("user_id")
        return result

    def save_address(self, db, user, expected, fields):
        self.validate_address(fields)
        old = self.address(db, user)
        version(old or {"version": 0}, expected)
        db.execute("INSERT INTO delivery_addresses VALUES(?,?,?,?,?,?,?) ON CONFLICT(user_id) DO UPDATE SET version=excluded.version,line1=excluded.line1,city=excluded.city,postal_code=excluded.postal_code,notes=excluded.notes,updated_at=excluded.updated_at",
                   (user, expected + 1, fields["line1"].strip(), fields["city"].strip(), fields["postal_code"].strip(), fields.get("notes", "").strip(), self.clock.stamp()))
        return self.address(db, user)

    def plan(self, db, user):
        row = dict(db.execute("SELECT * FROM plan_memberships WHERE user_id=?", (user,)).fetchone())
        if row["pending_plan"] and row["effective_date"] <= self.clock.today().isoformat():
            db.execute("UPDATE plan_memberships SET current_plan=pending_plan,pending_plan=NULL,effective_date=NULL,version=version+1 WHERE user_id=?", (user,))
            db.execute("INSERT INTO plan_events VALUES(?,?,?,?,?,?,'effective')", (uid(), user, row["current_plan"], row["pending_plan"], row["effective_date"], self.clock.stamp()))
            row = dict(db.execute("SELECT * FROM plan_memberships WHERE user_id=?", (user,)).fetchone())
        row.pop("user_id")
        row.update(can_view_delivery=row["current_plan"] == "pro",
                   address_required=(row["current_plan"] == "pro" or row["pending_plan"] == "pro") and not self.address(db, user))
        return row

    def change_plan(self, db, user, expected, plan, address=None, address_version=None):
        self.require_completed(db, user)
        old = self.plan(db, user)
        version(old, expected)
        self.validate({"plan": plan})
        if address is not None:
            if plan != "pro" or address_version is None:
                raise Problem("INVALID_INPUT", "La dirección y su versión solo se envían al elegir Pro.")
            self.save_address(db, user, address_version, address)
        if plan == "pro" and not self.address(db, user):
            raise Problem("INVALID_INPUT", "Añade una dirección ficticia para Pro.")
        effective = (self.clock.today() + timedelta(days=7 - self.clock.today().weekday())).isoformat()
        pending = plan if plan != old["current_plan"] else None
        if pending or old["pending_plan"]:
            db.execute("INSERT INTO plan_events VALUES(?,?,?,?,?,?,?)",
                       (uid(), user, old["pending_plan"] or old["current_plan"], plan,
                        effective if pending else self.clock.today().isoformat(), self.clock.stamp(),
                        "scheduled" if pending else "cancelled"))
        db.execute("UPDATE plan_memberships SET version=version+1,pending_plan=?,effective_date=? WHERE user_id=?", (pending, effective if pending else None, user))
        return self.plan(db, user)
