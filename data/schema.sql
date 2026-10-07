PRAGMA foreign_keys = ON;

CREATE TABLE catalog_info (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
);

CREATE TABLE allergens (
    code TEXT PRIMARY KEY,
    name_es TEXT NOT NULL UNIQUE
);

CREATE TABLE ingredients (
    id INTEGER PRIMARY KEY,
    code TEXT NOT NULL UNIQUE,
    name_es TEXT NOT NULL UNIQUE,
    category TEXT NOT NULL,
    diet_kind TEXT NOT NULL CHECK (diet_kind IN ('plant', 'dairy', 'egg', 'meat', 'fish', 'seafood'))
);

CREATE TABLE ingredient_allergens (
    ingredient_id INTEGER NOT NULL REFERENCES ingredients(id) ON DELETE CASCADE,
    allergen_code TEXT NOT NULL REFERENCES allergens(code),
    PRIMARY KEY (ingredient_id, allergen_code)
);

CREATE TABLE meal_slots (
    code TEXT PRIMARY KEY,
    name_es TEXT NOT NULL UNIQUE
);

CREATE TABLE recipes (
    id INTEGER PRIMARY KEY,
    code TEXT NOT NULL UNIQUE,
    name_es TEXT NOT NULL UNIQUE,
    category TEXT NOT NULL,
    cuisine TEXT NOT NULL,
    validation_status TEXT NOT NULL DEFAULT 'demo_unverified'
        CHECK (validation_status IN ('demo_unverified', 'verified')),
    is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1))
);

CREATE TABLE recipe_ingredients (
    recipe_id INTEGER NOT NULL REFERENCES recipes(id) ON DELETE CASCADE,
    ingredient_id INTEGER NOT NULL REFERENCES ingredients(id),
    position INTEGER NOT NULL CHECK (position > 0),
    PRIMARY KEY (recipe_id, ingredient_id),
    UNIQUE (recipe_id, position)
);

CREATE TABLE recipe_meal_slots (
    recipe_id INTEGER NOT NULL REFERENCES recipes(id) ON DELETE CASCADE,
    meal_slot_code TEXT NOT NULL REFERENCES meal_slots(code),
    PRIMARY KEY (recipe_id, meal_slot_code)
);

CREATE INDEX idx_ingredient_allergens_allergen ON ingredient_allergens(allergen_code, ingredient_id);
CREATE INDEX idx_recipe_ingredients_ingredient ON recipe_ingredients(ingredient_id, recipe_id);
CREATE INDEX idx_recipe_meal_slots_slot ON recipe_meal_slots(meal_slot_code, recipe_id);
CREATE INDEX idx_recipes_category ON recipes(category);

-- Solo se derivan alérgenos presentes en los ingredientes modelados.
-- La ausencia de filas NO certifica ausencia real ni contaminación cruzada.
CREATE VIEW recipe_allergens AS
SELECT DISTINCT ri.recipe_id, ia.allergen_code
FROM recipe_ingredients AS ri
JOIN ingredient_allergens AS ia ON ia.ingredient_id = ri.ingredient_id;

CREATE VIEW recipe_dietary AS
SELECT r.id AS recipe_id,
       CASE WHEN NOT EXISTS (
           SELECT 1 FROM recipe_ingredients AS ri
           JOIN ingredients AS i ON i.id = ri.ingredient_id
           WHERE ri.recipe_id = r.id AND i.diet_kind <> 'plant'
       ) THEN 1 ELSE 0 END AS is_vegan,
       CASE WHEN NOT EXISTS (
           SELECT 1 FROM recipe_ingredients AS ri
           JOIN ingredients AS i ON i.id = ri.ingredient_id
           WHERE ri.recipe_id = r.id AND i.diet_kind NOT IN ('plant', 'dairy', 'egg')
       ) THEN 1 ELSE 0 END AS is_vegetarian
FROM recipes AS r;
