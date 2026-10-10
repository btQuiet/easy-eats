from __future__ import annotations

import hashlib
from typing import Any

from app.config import Settings
from app.storage.db import catalog_connection


def catalog_hash(settings: Settings) -> str:
    return hashlib.sha256(settings.catalog_path.read_bytes()).hexdigest()


def read_catalog(settings: Settings) -> dict[str, Any]:
    with catalog_connection(settings) as db:
        recipes = {
            row["code"]: {
                "code": row["code"], "name": row["name_es"],
                "category": row["category"], "cuisine": row["cuisine"],
                "is_vegan": bool(row["is_vegan"]),
                "is_vegetarian": bool(row["is_vegetarian"]),
                "validation_status": row["validation_status"],
                "slots": [], "ingredients": [], "allergens": [],
            }
            for row in db.execute(
                "SELECT r.code, r.name_es, r.category, r.cuisine, r.validation_status, "
                "d.is_vegan, d.is_vegetarian FROM recipes r "
                "JOIN recipe_dietary d ON d.recipe_id = r.id WHERE r.is_active = 1"
            )
        }
        for row in db.execute(
            "SELECT r.code, s.meal_slot_code FROM recipe_meal_slots s "
            "JOIN recipes r ON r.id = s.recipe_id WHERE r.is_active = 1"
        ):
            recipes[row["code"]]["slots"].append(row["meal_slot_code"])
        for row in db.execute(
            "SELECT r.code, i.code AS ingredient_code, i.name_es FROM recipe_ingredients ri "
            "JOIN recipes r ON r.id = ri.recipe_id JOIN ingredients i ON i.id = ri.ingredient_id "
            "WHERE r.is_active = 1 ORDER BY ri.position"
        ):
            recipes[row["code"]]["ingredients"].append(
                {"code": row["ingredient_code"], "name": row["name_es"]}
            )
        for row in db.execute(
            "SELECT r.code, a.code AS allergen_code, a.name_es FROM recipe_allergens ra "
            "JOIN recipes r ON r.id = ra.recipe_id JOIN allergens a ON a.code = ra.allergen_code "
            "WHERE r.is_active = 1 ORDER BY a.name_es"
        ):
            recipes[row["code"]]["allergens"].append(
                {"code": row["allergen_code"], "name": row["name_es"]}
            )
        ingredients = [dict(row) for row in db.execute(
            "SELECT code, name_es AS name, category FROM ingredients ORDER BY name_es"
        )]
        allergens = [dict(row) for row in db.execute(
            "SELECT code, name_es AS name FROM allergens ORDER BY name_es"
        )]
    return {"recipes": recipes, "ingredients": ingredients, "allergens": allergens}


def eligible_recipes(catalog: dict[str, Any], profile: dict[str, Any], slot: str) -> list[dict[str, Any]]:
    allergen_codes = set(profile["allergens"])
    excluded_codes = set(profile["excluded_ingredients"])
    result = []
    for recipe in catalog["recipes"].values():
        if slot not in recipe["slots"]:
            continue
        if profile["diet"] == "vegan" and not recipe["is_vegan"]:
            continue
        if profile["diet"] == "vegetarian" and not recipe["is_vegetarian"]:
            continue
        if allergen_codes & {item["code"] for item in recipe["allergens"]}:
            continue
        if excluded_codes & {item["code"] for item in recipe["ingredients"]}:
            continue
        result.append(recipe)
    return result
