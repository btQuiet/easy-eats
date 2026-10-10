import asyncio
from datetime import datetime, timezone
from uuid import uuid4

import pytest
from fastapi.testclient import TestClient

from app.config import Clock, Settings
from app.domain import DEFAULT_SLOTS, Problem
from app.api.routes import create_app
from app.security import create_user


class FixedClock(Clock):
    value = datetime(2026, 10, 10, 10, tzinfo=timezone.utc)

    def now(self):
        return self.value

    def set(self, day, hour=10):
        self.value = datetime.fromisoformat(day + f"T{hour:02}:00:00+00:00")


@pytest.fixture
def env(tmp_path):
    clock = FixedClock()
    app = create_app(Settings(db_path=tmp_path / "test.sqlite"), clock, run_worker=False)
    with app.state.database.transaction() as db:
        create_user(db, "operator", "test-pass-123", "operator", clock)
    with TestClient(app) as client:
        op = client.post("/api/v1/auth/login", json={"alias": "operator", "password": "test-pass-123"}).json()["data"]["access_token"]
        yield app, client, clock, {"Authorization": "Bearer " + op}


def call(client, method, path, headers=None, body=None, idem=False, expected=200, key=None):
    headers = dict(headers or {})
    if idem:
        headers["Idempotency-Key"] = key or str(uuid4())
    response = client.request(method, "/api/v1" + path, headers=headers, json=body)
    assert response.status_code == expected, response.text
    return response.json()["data"] if expected < 300 else response.json()["error"]


def setup_user(env, alias="client1", plan="free", weekly=None, diet="omnivore"):
    _, client, _, _ = env
    session = call(client, "POST", "/auth/register", body={"alias": alias, "password": "test-pass-123"}, expected=201)
    headers = {"Authorization": "Bearer " + session["access_token"]}
    p = call(client, "GET", "/profile", headers)
    fields = [("plan", {"plan": plan}), ("calendar", {"weekly_slots": weekly or DEFAULT_SLOTS}),
              ("restrictions", {"diet": diet, "allergen_codes": [], "excluded_ingredient_codes": []}),
              ("preferences", {"liked_ingredient_codes": [], "disliked_ingredient_codes": [], "preferred_categories": [], "repetition_tolerance": "normal"}),
              ("summary", {"service_start_date": "2026-10-12", **({"address": {"line1": "Calle Demo 1", "city": "Madrid", "postal_code": "28000"}} if plan == "pro" else {})})]
    for step, values in fields:
        p = call(client, "PUT", "/onboarding/draft", headers, {"expected_version": p["version"], "step": step, "fields": values})
    p = call(client, "POST", "/onboarding/complete", headers, {"expected_version": p["version"]})
    return headers, p


def generate(env, headers, month="2026-10"):
    app, client, _, _ = env
    attempt = call(client, "POST", "/menus/ensure", headers, {"month": month}, idem=True, expected=202)
    asyncio.run(app.state.menus.work_one())
    return call(client, "GET", "/menus/cycles/" + attempt["cycle_id"], headers)


def approve(env, cycle):
    _, client, _, op = env
    return call(client, "POST", "/operator/cycles/" + cycle["id"] + "/approve", op,
                {"expected_version": cycle["version"]}, idem=True)


def items(env, headers, start="2026-10-12"):
    week = call(env[1], "GET", "/menus/week?start=" + start, headers)
    return [i for d in week["days"] for i in d["items"]]


def test_complete_flow_and_auto_renewal(env):
    h, _ = setup_user(env)
    cycle = generate(env, h)
    assert cycle["status"] == "pending_review"
    assert not items(env, h)
    detail = call(env[1], "GET", "/operator/cycles/" + cycle["id"], env[3])
    assert detail["items"] and not detail["requires_refresh"]
    approved = approve(env, cycle)
    assert approved["status"] == "approved"
    assert len(items(env, h)) == 14
    following = generate(env, h, "2026-11")
    assert following["status"] == "approved"
    crossing = call(env[1], "GET", "/menus/week?start=2026-10-26", h)
    assert len(crossing["cycle_segments"]) == 2
    assert sum(len(d["items"]) for d in crossing["days"]) == 14
    with env[0].state.database.transaction() as db:
        assert db.execute("SELECT COUNT(*) FROM initial_reviews").fetchone()[0] == 1


def test_idempotent_ensure_and_cross_operation_conflict(env):
    h, _ = setup_user(env)
    key = str(uuid4())
    a = call(env[1], "POST", "/menus/ensure", h, {"month": "2026-10"}, idem=True, expected=202, key=key)
    b = call(env[1], "POST", "/menus/ensure", h, {"month": "2026-10"}, idem=True, expected=202, key=key)
    assert a == b
    assert call(env[1], "POST", "/menus/ensure", h, {"month": "2026-11"}, idem=True, expected=409, key=key)["code"] == "IDEMPOTENCY_CONFLICT"
    asyncio.run(env[0].state.menus.work_one())
    operation = call(env[1], "GET", "/operations/" + key, h)
    assert operation["state"] == "completed" and operation["result"]["data"]["state"] == "succeeded"


def test_swaps_audited_versioned_and_owned(env):
    h, _ = setup_user(env)
    approve(env, generate(env, h))
    item = items(env, h)[0]
    candidates = call(env[1], "GET", f"/menus/items/{item['id']}/candidates?limit=100", h)
    r = next(x for x in candidates if x["code"] != item["recipe_code"])
    key = str(uuid4())
    data = {"expected_version": item["version"], "recipe_code": r["code"]}
    swapped = call(env[1], "PUT", f"/menus/items/{item['id']}/substitution", h, data, idem=True, key=key)
    assert swapped["item"]["version"] == item["version"] + 1
    assert call(env[1], "PUT", f"/menus/items/{item['id']}/substitution", h, data, idem=True, key=key) == swapped
    assert call(env[1], "PUT", f"/menus/items/{item['id']}/substitution", h, data, idem=True, expected=409)["code"] == "VERSION_CONFLICT"
    other, _ = setup_user(env, "client2")
    assert call(env[1], "GET", f"/menus/items/{item['id']}", other, expected=404)["code"] == "NOT_FOUND"
    with env[0].state.database.transaction() as db:
        assert db.execute("SELECT COUNT(*) FROM swaps").fetchone()[0] == 1


def test_restrictions_recheck_and_feedback_dates(env):
    h, p = setup_user(env)
    approve(env, generate(env, h))
    item = items(env, h)[0]
    ingredient = item["recipe_snapshot"]["ingredients"][0]["code"]
    p = call(env[1], "PATCH", "/profile", h, {"expected_version": p["version"], "excluded_ingredient_codes": [ingredient]})
    changed = call(env[1], "GET", f"/menus/items/{item['id']}", h)
    assert changed["compatibility"] == "needs_attention"
    assert call(env[1], "PUT", f"/menus/items/{item['id']}/feedback", h,
                {"expected_version": 0, "rating": 1}, expected=409)["code"] == "ITEM_NOT_EDITABLE"
    env[2].set("2026-10-12")
    changed = call(env[1], "GET", f"/menus/items/{item['id']}", h)
    assert not changed["can_swap"] and changed["can_feedback"]
    feedback = call(env[1], "PUT", f"/menus/items/{item['id']}/feedback", h, {"expected_version": 0, "rating": -1, "comment": "Pocas repeticiones."})
    edited = call(env[1], "PUT", f"/menus/items/{item['id']}/feedback", h, {"expected_version": 1, "rating": 1, "comment": ""})
    assert feedback["id"] == edited["id"] and edited["version"] == 2


def test_approval_cancels_elapsed_and_rejects_old_inputs(env):
    h, p = setup_user(env)
    cycle = generate(env, h)
    call(env[1], "PATCH", "/profile", h, {"expected_version": p["version"], "repetition_tolerance": "low"})
    assert call(env[1], "POST", "/operator/cycles/" + cycle["id"] + "/approve", env[3],
                {"expected_version": cycle["version"]}, idem=True, expected=409)["code"] == "INPUT_CHANGED"
    cycle = generate(env, h)
    env[2].set("2026-10-15")
    approved = approve(env, cycle)
    assert approved["cancelled_count"] == 8
    assert all(i["date"] > "2026-10-15" for i in items(env, h))


def test_input_change_cancels_queued_generation(env):
    h, p = setup_user(env)
    attempt = call(env[1], "POST", "/menus/ensure", h, {"month": "2026-10"}, idem=True, expected=202)
    call(env[1], "PATCH", "/profile", h, {"expected_version": p["version"], "diet": "vegan"})
    asyncio.run(env[0].state.menus.work_one())
    a = call(env[1], "GET", "/menus/generations/" + attempt["id"], h)
    assert a["state"] == "cancelled" and a["error"]["code"] == "INPUT_CHANGED"
    assert not items(env, h)


def test_no_candidates_and_hard_diet(env):
    h, p = setup_user(env, diet="vegan")
    cycle = generate(env, h)
    detail = call(env[1], "GET", "/operator/cycles/" + cycle["id"], env[3])
    assert all(i["recipe_snapshot"]["is_vegan"] for i in detail["items"])
    codes = [x["code"] for x in call(env[1], "GET", "/catalog/options", h)["ingredients"]]
    p = call(env[1], "PATCH", "/profile", h, {"expected_version": p["version"], "excluded_ingredient_codes": codes})
    assert call(env[1], "POST", "/menus/ensure", h, {"month": "2026-10"}, idem=True, expected=422)["code"] == "NO_CANDIDATES"


def test_calendar_effective_after_published_month(env):
    h, p = setup_user(env)
    approve(env, generate(env, h))
    generate(env, h, "2026-11")
    p = call(env[1], "PUT", "/profile/calendar", h, {"expected_version": p["version"],
                 "weekly_slots": [{"weekday": n, "meal_slots": ["comida"] if n == 1 else []} for n in range(1, 8)]})
    assert p["calendar_effective_month"] == "2026-12"
    assert len(items(env, h)) == 14


def test_pending_review_blocks_second_and_expiry_releases(env):
    h, _ = setup_user(env)
    generate(env, h)
    assert call(env[1], "POST", "/menus/ensure", h, {"month": "2026-11"}, idem=True, expected=409)["code"] == "INITIAL_REVIEW_PENDING"
    env[2].set("2026-10-31")
    # Session remains valid only seven days; log in again after advancing time.
    s = call(env[1], "POST", "/auth/login", body={"alias": "client1", "password": "test-pass-123"})
    h = {"Authorization": "Bearer " + s["access_token"]}
    following = generate(env, h, "2026-11")
    assert following["status"] == "pending_review"


def test_plan_upgrade_atomic_and_deliveries(env):
    h, _ = setup_user(env)
    approve(env, generate(env, h))
    assert call(env[1], "GET", "/deliveries", h, expected=403)["code"] == "FORBIDDEN"
    p = call(env[1], "PUT", "/plan", h, {"expected_version": 1, "plan": "pro",
        "expected_address_version": 0, "address": {"line1": "Demo 2", "city": "Madrid", "postal_code": "28000"}})
    assert p["pending_plan"] == "pro" and p["effective_date"] == "2026-10-12"
    env[2].set("2026-10-12")
    d = call(env[1], "GET", "/deliveries", h)
    assert d and all(x["simulated"] for x in d)
    assert call(env[1], "GET", "/plan", h)["can_view_delivery"]


def test_delivery_snapshot_preserved_and_free_capability(env):
    h, _ = setup_user(env, plan="pro")
    approve(env, generate(env, h))
    env[2].set("2026-10-11", 8)  # 10h Madrid, preparation has begun.
    d = call(env[1], "GET", "/deliveries", h)
    current = next(x for x in d if x["week_start"] == "2026-10-12")
    assert current["status"] == "preparing" and current["address_snapshot"]["line1"] == "Calle Demo 1"
    call(env[1], "PUT", "/delivery/address", h, {"expected_version": 1, "line1": "Demo nueva", "city": "Madrid", "postal_code": "28000"})
    d = call(env[1], "GET", "/deliveries", h)
    assert next(x for x in d if x["id"] == current["id"])["address_snapshot"]["line1"] == "Calle Demo 1"
    call(env[1], "PUT", "/plan", h, {"expected_version": 1, "plan": "free"})
    env[2].set("2026-10-12")
    assert call(env[1], "GET", "/deliveries", h, expected=403)["code"] == "FORBIDDEN"


def test_cookie_csrf_roles_and_logout(env):
    client = env[1]
    session = call(client, "POST", "/auth/register", body={"alias": "cookieclient", "password": "test-pass-123", "transport": "cookie"}, expected=201)
    assert "access_token" not in session and session["csrf_token"]
    assert call(client, "GET", "/auth/session")["csrf_token"] == session["csrf_token"]
    assert call(client, "PUT", "/onboarding/draft", body={"expected_version": 1, "step": "plan", "fields": {"plan": "free"}}, expected=403)["code"] == "FORBIDDEN"
    call(client, "PUT", "/onboarding/draft", {"X-CSRF-Token": session["csrf_token"]}, {"expected_version": 1, "step": "plan", "fields": {"plan": "free"}})
    assert call(client, "GET", "/operator/reviews", expected=403)["code"] == "FORBIDDEN"
    response = client.post("/api/v1/auth/logout", headers={"X-CSRF-Token": session["csrf_token"]})
    assert response.status_code == 204
    assert call(client, "GET", "/auth/session", expected=401)["code"] == "AUTH_REQUIRED"


def test_restart_marks_running_failed(env):
    h, _ = setup_user(env)
    attempt = call(env[1], "POST", "/menus/ensure", h, {"month": "2026-10"}, idem=True, expected=202)
    with env[0].state.database.transaction() as db:
        db.execute("UPDATE generation_attempts SET state='running' WHERE id=?", (attempt["id"],))
        env[0].state.menus.recover(db)
    a = call(env[1], "GET", "/menus/generations/" + attempt["id"], h)
    assert a["state"] == "failed" and a["error"]["code"] == "SERVER_RESTARTED"


def test_ai_unconfigured_never_falls_back(tmp_path):
    app = create_app(Settings(mode="ai", db_path=tmp_path / "ai.sqlite", groq_key=""), FixedClock(), run_worker=False)
    with TestClient(app) as client:
        assert not call(client, "GET", "/system/capabilities")["can_generate"]
        env = (app, client, FixedClock(), {})
        h, _ = setup_user(env)
        error = call(client, "POST", "/menus/ensure", h, {"month": "2026-10"}, idem=True, expected=503)
        assert error["code"] == "AI_NOT_CONFIGURED"


def test_login_rate_limit(env):
    for _ in range(10):
        call(env[1], "POST", "/auth/login", body={"alias": "missing", "password": "wrongpass123"}, expected=401)
    call(env[1], "POST", "/auth/login", body={"alias": "missing", "password": "wrongpass123"}, expected=429)


def test_failed_regeneration_preserves_valid_proposal(env):
    h, _ = setup_user(env)
    cycle = generate(env, h)
    before = call(env[1], "GET", "/operator/cycles/" + cycle["id"], env[3])
    class FailingGenerator:
        async def generate(self, snapshot, catalog):
            raise Problem("AI_UNAVAILABLE", "Fallo controlado.", 503)
    env[0].state.menus.generator = FailingGenerator()
    call(env[1], "POST", "/operator/cycles/" + cycle["id"] + "/regenerate", env[3],
         {"expected_version": cycle["version"]}, idem=True, expected=202)
    asyncio.run(env[0].state.menus.work_one())
    after = call(env[1], "GET", "/operator/cycles/" + cycle["id"], env[3])
    assert after["items"] == before["items"]
    assert after["latest_generation"]["error"]["code"] == "AI_UNAVAILABLE"
    assert approve(env, cycle)["status"] == "approved"


def test_concurrent_swap_one_wins(env):
    from concurrent.futures import ThreadPoolExecutor
    h, _ = setup_user(env)
    approve(env, generate(env, h))
    item = items(env, h)[0]
    candidates = call(env[1], "GET", f"/menus/items/{item['id']}/candidates?limit=100", h)
    codes = [r["code"] for r in candidates if r["code"] != item["recipe_code"]][:2]
    def change(code):
        return env[1].put(f"/api/v1/menus/items/{item['id']}/substitution",
                         headers={**h, "Idempotency-Key": str(uuid4())},
                         json={"expected_version": item["version"], "recipe_code": code}).status_code
    with ThreadPoolExecutor(2) as pool:
        statuses = list(pool.map(change, codes))
    assert sorted(statuses) == [200, 409]


def test_operator_correction_is_revalidated_and_bumps_cycle(env):
    h, _ = setup_user(env, diet="vegan")
    c = generate(env, h)
    review = call(env[1], "GET", "/operator/cycles/" + c["id"], env[3])
    item = review["items"][0]
    choices = call(env[1], "GET", f"/operator/items/{item['id']}/candidates?limit=100", env[3])
    code = next(x["code"] for x in choices if x["code"] != item["recipe_code"])
    changed = call(env[1], "PUT", f"/operator/items/{item['id']}", env[3], {"expected_version": item["version"], "recipe_code": code})
    assert changed["cycle_version"] == c["version"] + 1
    c["version"] = changed["cycle_version"]
    approve(env, c)
    assert call(env[1], "PUT", f"/operator/items/{item['id']}", env[3], {"expected_version": changed["item"]["version"], "recipe_code": item["recipe_code"]}, expected=409)["code"] == "ITEM_NOT_EDITABLE"


def test_cancelling_pending_free_preserves_deliveries(env):
    h, _ = setup_user(env, plan="pro")
    approve(env, generate(env, h))
    before = call(env[1], "GET", "/deliveries", h)
    plan = call(env[1], "PUT", "/plan", h, {"expected_version": 1, "plan": "free"})
    scheduled = call(env[1], "GET", "/deliveries", h)
    assert all(d["status"] != "cancelled" for d in scheduled)
    call(env[1], "PUT", "/plan", h, {"expected_version": plan["version"], "plan": "pro"})
    after = call(env[1], "GET", "/deliveries", h)
    assert {d["id"] for d in after} == {d["id"] for d in before}
    assert all(d["status"] != "cancelled" for d in after)
    with env[0].state.database.transaction() as db:
        assert [r[0] for r in db.execute("SELECT event_kind FROM plan_events ORDER BY rowid")] == ["initial", "scheduled", "cancelled"]


def test_unknown_restriction_is_retained_and_can_be_resolved(env):
    h, p = setup_user(env)
    approve(env, generate(env, h))
    with env[0].state.database.transaction() as db:
        user = db.execute("SELECT id FROM users WHERE alias_normalized='client1'").fetchone()[0]
        db.execute("INSERT INTO profile_allergens VALUES(?,'retired_allergen')", (user,))
        env[0].state.profiles.reevaluate(db, user)
    assert items(env, h)[0]["compatibility"] == "needs_attention"
    p = call(env[1], "PATCH", "/profile", h, {"expected_version": p["version"], "repetition_tolerance": "low"})
    assert p["allergen_codes"] == ["retired_allergen"]
    call(env[1], "PATCH", "/profile", h, {"expected_version": p["version"], "allergen_codes": []})
    assert items(env, h)[0]["compatibility"] == "compatible"


def test_pending_pro_deliveries_survive_until_plan_becomes_effective(env):
    h, _ = setup_user(env)
    approve(env, generate(env, h))
    call(env[1], "PUT", "/plan", h, {"expected_version": 1, "plan": "pro",
         "expected_address_version": 0, "address": {"line1": "Calle ficticia 2", "city": "Demo", "postal_code": "00000"}})
    with env[0].state.database.transaction() as db:
        user = db.execute("SELECT id FROM users WHERE alias_normalized='client1'").fetchone()[0]
        scheduled = env[0].state.deliveries.list(db, user)
        assert scheduled and all(d["status"] == "scheduled" for d in scheduled)
    env[2].set("2026-10-12")
    effective = call(env[1], "GET", "/deliveries", h)
    assert all(d["status"] != "cancelled" for d in effective)
    assert {d["id"] for d in effective} == {d["id"] for d in scheduled}


def test_future_deliveries_recover_after_cancelled_pending_upgrade(env):
    h, _ = setup_user(env)
    approve(env, generate(env, h))
    p = call(env[1], "PUT", "/plan", h, {"expected_version": 1, "plan": "pro",
         "expected_address_version": 0, "address": {"line1": "Calle ficticia 2", "city": "Demo", "postal_code": "00000"}})
    p = call(env[1], "PUT", "/plan", h, {"expected_version": p["version"], "plan": "free"})
    call(env[1], "PUT", "/plan", h, {"expected_version": p["version"], "plan": "pro"})
    env[2].set("2026-10-12")
    deliveries = call(env[1], "GET", "/deliveries", h)
    assert deliveries and all(d["status"] != "cancelled" for d in deliveries)


@pytest.mark.parametrize("start", ["2026-10-10", "invalid", "2026-02-30", "9999-12-27"])
def test_invalid_week_returns_controlled_input_error(env, start):
    h, _ = setup_user(env)
    assert call(env[1], "GET", "/menus/week?start=" + start, h, expected=422)["code"] == "INVALID_INPUT"


def test_future_delivery_recovers_when_restrictions_are_relaxed(env):
    h, p = setup_user(env, plan="pro")
    approve(env, generate(env, h))
    before = call(env[1], "GET", "/deliveries", h)
    all_ingredients = [x["code"] for x in env[0].state.menus.catalog.ingredients]
    p = call(env[1], "PATCH", "/profile", h, {"expected_version": p["version"], "excluded_ingredient_codes": all_ingredients})
    assert all(d["status"] == "cancelled" for d in call(env[1], "GET", "/deliveries", h))
    call(env[1], "PATCH", "/profile", h, {"expected_version": p["version"], "excluded_ingredient_codes": []})
    after = call(env[1], "GET", "/deliveries", h)
    assert {d["id"] for d in before} == {d["id"] for d in after}
    assert all(d["status"] == "scheduled" for d in after)
