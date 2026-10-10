ALTER TABLE plan_events ADD COLUMN event_kind TEXT NOT NULL DEFAULT 'effective'
  CHECK(event_kind IN('initial','scheduled','cancelled','effective'));
