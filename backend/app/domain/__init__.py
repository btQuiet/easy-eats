"""Catalog, eligibility, calendar and variety policy."""
import calendar
import hashlib
import json
import sqlite3
import unicodedata
from datetime import date, timedelta

MEALS = ("desayuno", "comida", "merienda", "cena")
DEFAULT_SLOTS = [{"weekday": n, "meal_slots": ["comida", "cena"]} for n in range(1, 8)]


class Problem(Exception):
    def __init__(self, code, message, status=422, **details):
        self.code, self.message, self.status, self.details = code, message, status, details
        super().__init__(message)

    def payload(self):
        return {"code": self.code, "message": self.message, "details": self.details}


def uid():
    from uuid import uuid4
    return str(uuid4())


def dump(value):
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"))


def fold(value):
    return "".join(c for c in unicodedata.normalize("NFD", value.lower()) if not unicodedata.combining(c))


def next_month(month):
    d = date.fromisoformat(month + "-01")
    return (d.replace(day=28) + timedelta(days=4)).strftime("%Y-%m")


def month_dates(month):
    try:
        d = date.fromisoformat(month + "-01")
        if d.strftime("%Y-%m") != month:
            raise ValueError()
    except (ValueError, TypeError):
        raise Problem("INVALID_INPUT", "Mes no válido.")
    return [d.replace(day=n) for n in range(1, calendar.monthrange(d.year, d.month)[1] + 1)]


def slots_for(month, weekly, start):
    pattern = {x["weekday"]: x["meal_slots"] for x in weekly}
    return [{"date": d.isoformat(), "meal_slot": m}
            for d in month_dates(month) if d.isoformat() >= start
            for m in MEALS if m in pattern.get(d.isoweekday(), [])]


def monday(d):
    return d - timedelta(days=d.weekday())


class Catalog:
    def __init__(self, path):
        self.hash = hashlib.sha256(path.read_bytes()).hexdigest()
        db = sqlite3.connect(path.resolve().as_uri() + "?mode=ro", uri=True)
        db.row_factory = sqlite3.Row
        if db.execute("PRAGMA integrity_check").fetchone()[0] != "ok":
            raise ValueError("Catalog integrity failed")
        self.ingredients = [dict(x) for x in db.execute("SELECT code,name_es AS name FROM ingredients ORDER BY name_es")]
        self.allergens = [dict(x) for x in db.execute("SELECT code,name_es AS name FROM allergens ORDER BY name_es")]
        self.recipes = {}
        for r in db.execute("SELECT r.*,d.is_vegan,d.is_vegetarian FROM recipes r JOIN recipe_dietary d ON d.recipe_id=r.id"):
            r = dict(r)
            ident = r.pop("id")
            r["name"] = r.pop("name_es")
            r["is_active"], r["is_vegan"], r["is_vegetarian"] = map(bool, (r["is_active"], r["is_vegan"], r["is_vegetarian"]))
            r["meal_slots"] = [x[0] for x in db.execute("SELECT meal_slot_code FROM recipe_meal_slots WHERE recipe_id=?", (ident,))]
            r["ingredients"] = [dict(x) for x in db.execute(
                "SELECT i.code,i.name_es AS name FROM recipe_ingredients ri JOIN ingredients i ON i.id=ri.ingredient_id WHERE recipe_id=? ORDER BY position", (ident,))]
            r["allergens"] = [dict(x) for x in db.execute(
                "SELECT a.code,a.name_es AS name FROM recipe_allergens ra JOIN allergens a ON a.code=ra.allergen_code WHERE recipe_id=?", (ident,))]
            self.recipes[r["code"]] = r
        self.categories = sorted({r["category"] for r in self.recipes.values()})
        db.close()

    def reasons(self, recipe, profile, meal=None):
        reasons = []
        if not recipe["is_active"]:
            reasons.append("INACTIVE")
        if meal and meal not in recipe["meal_slots"]:
            reasons.append("MEAL_SLOT")
        if profile["diet"] == "vegan" and not recipe["is_vegan"]:
            reasons.append("DIET")
        if profile["diet"] == "vegetarian" and not recipe["is_vegetarian"]:
            reasons.append("DIET")
        if {i["code"] for i in recipe["ingredients"]} & set(profile["excluded_ingredient_codes"]):
            reasons.append("EXCLUDED_INGREDIENT")
        if {a["code"] for a in recipe["allergens"]} & set(profile["allergen_codes"]):
            reasons.append("ALLERGEN")
        # Missing restriction codes cannot silently broaden a profile.
        known_i, known_a = {x["code"] for x in self.ingredients}, {x["code"] for x in self.allergens}
        if set(profile["excluded_ingredient_codes"]) - known_i or set(profile["allergen_codes"]) - known_a:
            reasons.append("UNKNOWN_RESTRICTION")
        return reasons

    def candidates(self, profile, meal=None):
        return [r for r in self.recipes.values() if not self.reasons(r, profile, meal)]

    def recipe(self, code):
        if code not in self.recipes:
            raise Problem("NOT_FOUND", "Plato no encontrado.", 404)
        return self.recipes[code]

    def options(self):
        return {"ingredients": self.ingredients, "allergens": self.allergens,
                "categories": self.categories, "meal_slots": list(MEALS)}


def eligible_tier(pool, history, day, tolerance):
    limit = {"low": 1, "normal": 2, "high": 3}[tolerance]
    d = date.fromisoformat(day)
    same = {x["recipe_code"] for x in history if x["date"] == day}
    counts = {r["code"]: sum(x["recipe_code"] == r["code"] and
              d - timedelta(days=6) <= date.fromisoformat(x["date"]) <= d for x in history) for r in pool}
    primary = [r for r in pool if r["code"] not in same and counts[r["code"]] < limit]
    if primary:
        return primary, 1
    secondary = [r for r in pool if r["code"] not in same]
    return (secondary, 2) if secondary else (pool, 3)


def score(recipe, profile, history, ratings, day):
    codes = {i["code"] for i in recipe["ingredients"]}
    d = date.fromisoformat(day)
    repeats = sum(x["recipe_code"] == recipe["code"] and
                  d - timedelta(days=14) <= date.fromisoformat(x["date"]) < d for x in history)
    return (2 * min(3, len(codes & set(profile["liked_ingredient_codes"]))) -
            2 * min(3, len(codes & set(profile["disliked_ingredient_codes"]))) +
            3 * (recipe["category"] in profile["preferred_categories"]) +
            4 * ratings.get(recipe["code"], 0) - 2 * repeats)


def validate_output(items, snapshot, catalog):
    wanted = [(x["date"], x["meal_slot"]) for x in snapshot["slots"]]
    if not isinstance(items, list) or len(items) != len(wanted):
        raise Problem("AI_INVALID_OUTPUT", "La generación no cubre todas las comidas.", 503)
    indexed = {}
    for x in items:
        if not isinstance(x, dict) or set(x) != {"date", "meal_slot", "recipe_code"} or any(not isinstance(v,str) for v in x.values()):
            raise Problem("AI_INVALID_OUTPUT", "Formato de generación no válido.", 503)
        key = (x["date"], x["meal_slot"])
        if key in indexed or key not in wanted or x["recipe_code"] not in catalog.recipes:
            raise Problem("AI_INVALID_OUTPUT", "Cobertura o código de plato no válido.", 503)
        indexed[key] = x
    history, result, warnings = list(snapshot["history"]), [], []
    for key in wanted:
        x = indexed[key]
        pool = catalog.candidates(snapshot["profile"], key[1])
        tier, relaxation = eligible_tier(pool, history, key[0], snapshot["profile"]["repetition_tolerance"])
        if x["recipe_code"] not in {r["code"] for r in tier}:
            raise Problem("AI_INVALID_OUTPUT", "Un plato incumple las restricciones o variedad disponible.", 503)
        result.append(x)
        history.append(x)
        if relaxation > 1:
            warnings.append({"code": "VARIETY_RELAXED", "date": key[0], "meal_slot": key[1], "tier": relaxation})
    return result, warnings
