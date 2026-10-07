"""Build the self-contained SQLite demo dish catalogue from editable CSV seeds."""

from __future__ import annotations

import csv
import os
import sqlite3
from contextlib import closing
from pathlib import Path


ROOT = Path(__file__).resolve().parent
DATABASE = ROOT / "catalog.sqlite"
TEMP_DATABASE = ROOT / ".catalog.sqlite.tmp"
ALLERGEN_CODES = {
    "gluten", "crustaceos", "huevo", "pescado", "cacahuetes", "soja",
    "leche", "frutos_cascara", "apio", "mostaza", "sesamo", "sulfitos",
    "altramuces", "moluscos",
}
MEAL_SLOT_CODES = {"desayuno", "comida", "cena", "merienda"}
DIET_KINDS = {"plant", "dairy", "egg", "meat", "fish", "seafood"}


def read_rows(filename: str, columns: tuple[str, ...]) -> list[dict[str, str]]:
    with (ROOT / filename).open("r", encoding="utf-8-sig", newline="") as source:
        reader = csv.DictReader(source, delimiter=";")
        if tuple(reader.fieldnames or ()) != columns:
            raise ValueError(f"{filename}: cabecera esperada {columns}")
        rows = list(reader)
    for number, row in enumerate(rows, start=2):
        required = (column for column in columns if column != "allergens")
        if None in row or any(row[column] is None or not row[column].strip() for column in required):
            raise ValueError(f"{filename}:{number}: fila incompleta")
    return rows


def split_codes(value: str) -> list[str]:
    return [item.strip() for item in value.split("|") if item.strip()]


def require_unique(rows: list[dict[str, str]], field: str, filename: str) -> None:
    values = [row[field] for row in rows]
    if len(values) != len(set(values)):
        raise ValueError(f"{filename}: valor duplicado en {field}")


def build() -> None:
    allergens = read_rows("allergens.csv", ("code", "name_es"))
    ingredients = read_rows(
        "ingredients.csv", ("code", "name_es", "category", "diet_kind", "allergens")
    )
    recipes = read_rows(
        "recipes.csv", ("code", "name_es", "category", "cuisine", "meal_slots", "ingredients")
    )
    if {row["code"] for row in allergens} != ALLERGEN_CODES:
        raise ValueError("allergens.csv debe contener exactamente los 14 grupos de la UE")
    if not 100 <= len(recipes) <= 150:
        raise ValueError("Se esperan entre 100 y 150 platos")
    for filename, rows in (("allergens.csv", allergens), ("ingredients.csv", ingredients), ("recipes.csv", recipes)):
        require_unique(rows, "code", filename)
        require_unique(rows, "name_es", filename)

    known_ingredients = {row["code"] for row in ingredients}
    used_ingredients: set[str] = set()
    used_allergens: set[str] = set()
    used_slots: set[str] = set()
    for row in ingredients:
        if row["diet_kind"] not in DIET_KINDS:
            raise ValueError(f"Tipo dietético desconocido: {row['code']}")
        codes = split_codes(row["allergens"])
        if len(codes) != len(set(codes)) or set(codes) - ALLERGEN_CODES:
            raise ValueError(f"Alérgenos inválidos: {row['code']}")
        used_allergens.update(codes)
    if used_allergens != ALLERGEN_CODES:
        raise ValueError(f"Sin representación en ingredientes: {ALLERGEN_CODES - used_allergens}")
    for row in recipes:
        ingredient_codes = split_codes(row["ingredients"])
        slot_codes = split_codes(row["meal_slots"])
        if len(ingredient_codes) < 3 or len(ingredient_codes) != len(set(ingredient_codes)):
            raise ValueError(f"Ingredientes insuficientes o repetidos: {row['code']}")
        if set(ingredient_codes) - known_ingredients:
            raise ValueError(f"Ingrediente desconocido en {row['code']}: {set(ingredient_codes) - known_ingredients}")
        if not slot_codes or len(slot_codes) != len(set(slot_codes)) or set(slot_codes) - MEAL_SLOT_CODES:
            raise ValueError(f"Momentos de comida inválidos: {row['code']}")
        used_ingredients.update(ingredient_codes)
        used_slots.update(slot_codes)
    if used_slots != MEAL_SLOT_CODES:
        raise ValueError(f"Faltan momentos de comida: {MEAL_SLOT_CODES - used_slots}")
    if used_ingredients != known_ingredients:
        raise ValueError(f"Ingredientes no usados: {known_ingredients - used_ingredients}")

    if TEMP_DATABASE.exists():
        TEMP_DATABASE.unlink()
    try:
        with closing(sqlite3.connect(TEMP_DATABASE)) as db:
            db.execute("PRAGMA foreign_keys = ON")
            db.executescript((ROOT / "schema.sql").read_text(encoding="utf-8"))
            db.executemany("INSERT INTO catalog_info(key, value) VALUES (?, ?)", [
                ("catalog_name", "Easy Eats: catálogo demostrativo"),
                ("source", "Platos de ejemplo originales definidos para el prototipo"),
                ("status", "demo_unverified"),
                ("allergen_basis", "Ingredientes modelados; no contempla formulaciones comerciales ni contaminación cruzada"),
            ])
            db.executemany("INSERT INTO allergens(code, name_es) VALUES (?, ?)",
                           [(row["code"], row["name_es"]) for row in allergens])
            db.executemany("INSERT INTO meal_slots(code, name_es) VALUES (?, ?)", [
                ("desayuno", "Desayuno"), ("comida", "Comida"),
                ("cena", "Cena"), ("merienda", "Merienda"),
            ])
            for row in ingredients:
                cursor = db.execute(
                    "INSERT INTO ingredients(code, name_es, category, diet_kind) VALUES (?, ?, ?, ?)",
                    (row["code"], row["name_es"], row["category"], row["diet_kind"]),
                )
                db.executemany("INSERT INTO ingredient_allergens(ingredient_id, allergen_code) VALUES (?, ?)",
                               [(cursor.lastrowid, code) for code in split_codes(row["allergens"])])
            ingredient_ids = dict(db.execute("SELECT code, id FROM ingredients"))
            for row in recipes:
                cursor = db.execute(
                    "INSERT INTO recipes(code, name_es, category, cuisine) VALUES (?, ?, ?, ?)",
                    (row["code"], row["name_es"], row["category"], row["cuisine"]),
                )
                recipe_id = cursor.lastrowid
                db.executemany("INSERT INTO recipe_ingredients(recipe_id, ingredient_id, position) VALUES (?, ?, ?)",
                               [(recipe_id, ingredient_ids[code], position)
                                for position, code in enumerate(split_codes(row["ingredients"]), start=1)])
                db.executemany("INSERT INTO recipe_meal_slots(recipe_id, meal_slot_code) VALUES (?, ?)",
                               [(recipe_id, code) for code in split_codes(row["meal_slots"])])
            db.commit()
            assert db.execute("PRAGMA integrity_check").fetchone()[0] == "ok"
            assert db.execute("PRAGMA foreign_key_check").fetchall() == []
            assert db.execute("SELECT COUNT(*) FROM recipes").fetchone()[0] == len(recipes)
        os.replace(TEMP_DATABASE, DATABASE)
    finally:
        if TEMP_DATABASE.exists():
            TEMP_DATABASE.unlink()

    with closing(sqlite3.connect(DATABASE)) as db:
        vegan, vegetarian = db.execute(
            "SELECT SUM(is_vegan), SUM(is_vegetarian) FROM recipe_dietary"
        ).fetchone()
        print(f"Catálogo generado: {DATABASE}")
        print(f"{len(recipes)} platos, {len(ingredients)} ingredientes, {len(allergens)} grupos de alérgenos")
        print(f"{vegan} platos veganos, {vegetarian} vegetarianos (según ingredientes modelados)")


if __name__ == "__main__":
    build()
