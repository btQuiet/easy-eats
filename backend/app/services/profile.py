from __future__ import annotations

from typing import Any

from app.api.schemas import ProfileInput
from app.config import Settings
from app.storage.db import connection, utc_now


def get_profile(settings: Settings, user_id: int) -> dict[str, Any] | None:
    with connection(settings) as db:
        row = db.execute("SELECT * FROM profiles WHERE user_id = ?", (user_id,)).fetchone()
        if row is None:
            return None
        schedule = [dict(item) for item in db.execute(
            "SELECT weekday, slot FROM weekly_slots WHERE user_id = ? ORDER BY weekday, slot", (user_id,)
        )]
        allergens = [item[0] for item in db.execute(
            "SELECT allergen_code FROM profile_allergens WHERE user_id = ? ORDER BY allergen_code", (user_id,)
        )]
        excluded = [item[0] for item in db.execute(
            "SELECT ingredient_code FROM excluded_ingredients WHERE user_id = ? ORDER BY ingredient_code", (user_id,)
        )]
        liked = [item[0] for item in db.execute(
            "SELECT ingredient_code FROM ingredient_preferences WHERE user_id = ? AND weight = 1 ORDER BY ingredient_code",
            (user_id,),
        )]
        disliked = [item[0] for item in db.execute(
            "SELECT ingredient_code FROM ingredient_preferences WHERE user_id = ? AND weight = -1 ORDER BY ingredient_code",
            (user_id,),
        )]
    return {
        "plan": row["plan"], "diet": row["diet"], "address": row["address"],
        "completed": bool(row["completed"]), "updated_at": row["updated_at"],
        "schedule": schedule, "allergens": allergens,
        "excluded_ingredients": excluded, "liked_ingredients": liked,
        "disliked_ingredients": disliked,
    }


def save_profile(settings: Settings, user_id: int, profile: ProfileInput,
                 valid_allergens: set[str], valid_ingredients: set[str]) -> dict[str, Any]:
    if set(profile.allergens) - valid_allergens:
        raise ValueError("Hay alérgenos desconocidos")
    codes = set(profile.excluded_ingredients + profile.liked_ingredients + profile.disliked_ingredients)
    if codes - valid_ingredients:
        raise ValueError("Hay ingredientes desconocidos")
    with connection(settings) as db:
        db.execute(
            "INSERT INTO profiles(user_id, plan, diet, address, completed, updated_at) VALUES (?, ?, ?, ?, 1, ?) "
            "ON CONFLICT(user_id) DO UPDATE SET plan=excluded.plan, diet=excluded.diet, "
            "address=excluded.address, completed=1, updated_at=excluded.updated_at",
            (user_id, profile.plan, profile.diet, profile.address.strip(), utc_now()),
        )
        for table in ("weekly_slots", "profile_allergens", "excluded_ingredients", "ingredient_preferences"):
            db.execute(f"DELETE FROM {table} WHERE user_id = ?", (user_id,))
        db.executemany("INSERT INTO weekly_slots(user_id, weekday, slot) VALUES (?, ?, ?)",
                       [(user_id, item.weekday, item.slot) for item in profile.schedule])
        db.executemany("INSERT INTO profile_allergens(user_id, allergen_code) VALUES (?, ?)",
                       [(user_id, code) for code in profile.allergens])
        db.executemany("INSERT INTO excluded_ingredients(user_id, ingredient_code) VALUES (?, ?)",
                       [(user_id, code) for code in profile.excluded_ingredients])
        db.executemany("INSERT INTO ingredient_preferences(user_id, ingredient_code, weight) VALUES (?, ?, ?)",
                       [(user_id, code, 1) for code in profile.liked_ingredients] +
                       [(user_id, code, -1) for code in profile.disliked_ingredients])
    return get_profile(settings, user_id) or {}
