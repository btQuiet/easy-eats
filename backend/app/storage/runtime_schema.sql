PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY,
    username TEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    salt TEXT NOT NULL,
    role TEXT NOT NULL CHECK (role IN ('client', 'operator')),
    created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS sessions (
    token_hash TEXT PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    expires_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS profiles (
    user_id INTEGER PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    plan TEXT NOT NULL CHECK (plan IN ('free', 'pro')),
    diet TEXT NOT NULL CHECK (diet IN ('omnivore', 'vegetarian', 'vegan')),
    address TEXT NOT NULL DEFAULT '',
    completed INTEGER NOT NULL DEFAULT 0 CHECK (completed IN (0, 1)),
    updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS weekly_slots (
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    weekday INTEGER NOT NULL CHECK (weekday BETWEEN 0 AND 6),
    slot TEXT NOT NULL CHECK (slot IN ('desayuno', 'comida', 'cena', 'merienda')),
    PRIMARY KEY (user_id, weekday, slot)
);

CREATE TABLE IF NOT EXISTS profile_allergens (
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    allergen_code TEXT NOT NULL,
    PRIMARY KEY (user_id, allergen_code)
);

CREATE TABLE IF NOT EXISTS excluded_ingredients (
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    ingredient_code TEXT NOT NULL,
    PRIMARY KEY (user_id, ingredient_code)
);

CREATE TABLE IF NOT EXISTS ingredient_preferences (
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    ingredient_code TEXT NOT NULL,
    weight INTEGER NOT NULL CHECK (weight IN (-1, 1)),
    PRIMARY KEY (user_id, ingredient_code)
);

CREATE TABLE IF NOT EXISTS menu_cycles (
    id INTEGER PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    month TEXT NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('pending_review', 'approved')),
    origin TEXT NOT NULL CHECK (origin IN ('test', 'ai')),
    provider TEXT,
    model TEXT,
    catalog_hash TEXT NOT NULL,
    created_at TEXT NOT NULL,
    approved_at TEXT,
    UNIQUE (user_id, month)
);

CREATE TABLE IF NOT EXISTS menu_items (
    id INTEGER PRIMARY KEY,
    cycle_id INTEGER NOT NULL REFERENCES menu_cycles(id) ON DELETE CASCADE,
    day TEXT NOT NULL,
    slot TEXT NOT NULL CHECK (slot IN ('desayuno', 'comida', 'cena', 'merienda')),
    recipe_code TEXT NOT NULL,
    source TEXT NOT NULL CHECK (source IN ('generated', 'operator', 'client')),
    version INTEGER NOT NULL DEFAULT 1,
    UNIQUE (cycle_id, day, slot)
);

CREATE TABLE IF NOT EXISTS initial_reviews (
    user_id INTEGER PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    cycle_id INTEGER NOT NULL UNIQUE REFERENCES menu_cycles(id),
    operator_id INTEGER NOT NULL REFERENCES users(id),
    reviewed_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS swaps (
    id INTEGER PRIMARY KEY,
    item_id INTEGER NOT NULL REFERENCES menu_items(id) ON DELETE CASCADE,
    actor_id INTEGER NOT NULL REFERENCES users(id),
    old_recipe_code TEXT NOT NULL,
    new_recipe_code TEXT NOT NULL,
    created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS feedback (
    id INTEGER PRIMARY KEY,
    item_id INTEGER NOT NULL REFERENCES menu_items(id) ON DELETE CASCADE,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    rating INTEGER NOT NULL CHECK (rating IN (-1, 1)),
    comment TEXT NOT NULL DEFAULT '',
    created_at TEXT NOT NULL,
    UNIQUE (item_id, user_id)
);

CREATE TABLE IF NOT EXISTS generation_attempts (
    id INTEGER PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    month TEXT NOT NULL,
    origin TEXT NOT NULL CHECK (origin IN ('test', 'ai')),
    provider TEXT,
    model TEXT,
    status TEXT NOT NULL CHECK (status IN ('success', 'error')),
    error_code TEXT,
    created_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_sessions_user ON sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_cycles_status ON menu_cycles(status, user_id);
CREATE INDEX IF NOT EXISTS idx_items_day ON menu_items(day, cycle_id);
CREATE INDEX IF NOT EXISTS idx_feedback_user ON feedback(user_id, created_at);
