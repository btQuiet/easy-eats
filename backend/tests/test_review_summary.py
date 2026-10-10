import pytest
from test_app import env, setup_user, generate, approve, call


def test_review_summary_matches_publication_and_resolves_selected_names(env):
    headers, profile = setup_user(env)
    profile = call(env[1], "PATCH", "/profile", headers, {
        "expected_version": profile["version"], "liked_ingredient_codes": ["arroz"],
    })
    cycle = generate(env, headers)
    env[2].set("2026-10-16")
    review = call(env[1], "GET", "/operator/cycles/" + cycle["id"], env[3])
    summary = review["review_summary"]
    assert summary == {"future_item_count": 30, "elapsed_item_count": 10,
                       "first_future_date": "2026-10-17", "can_approve": True, "blocking_reasons": []}
    assert review["profile_labels"]["liked_ingredients"] == [{"code": "arroz", "name": "Arroz", "known": True}]
    published = approve(env, cycle)
    assert published["item_count"] - published["cancelled_count"] == summary["future_item_count"]


@pytest.mark.parametrize("condition,code", [
    ("profile_changed", "INPUT_CHANGED"),
    ("inactive_recipe", "RECIPE_INCOMPATIBLE"),
    ("generation_active", "GENERATION_IN_PROGRESS"),
])
def test_review_readiness_and_approval_enforce_the_same_blocker(env, condition, code):
    headers, profile = setup_user(env)
    cycle = generate(env, headers)
    if condition == "profile_changed":
        call(env[1], "PATCH", "/profile", headers, {"expected_version": profile["version"], "diet": "vegan"})
    elif condition == "generation_active":
        call(env[1], "POST", "/operator/cycles/" + cycle["id"] + "/regenerate", env[3],
             {"expected_version": cycle["version"]}, idem=True, expected=202)
    else:
        review = call(env[1], "GET", "/operator/cycles/" + cycle["id"], env[3])
        env[0].state.menus.catalog.recipes[review["items"][0]["recipe_code"]]["is_active"] = False
    review = call(env[1], "GET", "/operator/cycles/" + cycle["id"], env[3])
    assert not review["review_summary"]["can_approve"]
    assert review["review_summary"]["blocking_reasons"][0]["code"] == code
    failure = call(env[1], "POST", "/operator/cycles/" + cycle["id"] + "/approve", env[3],
                   {"expected_version": review["version"]}, idem=True, expected=409)
    assert failure["code"] == code


def test_expired_review_leaves_the_queue_and_cannot_be_published(env):
    headers, _ = setup_user(env)
    cycle = generate(env, headers)
    env[2].set("2026-10-31")
    session = call(env[1], "POST", "/auth/login", body={"alias": "operator", "password": "test-pass-123"})
    env[3]["Authorization"] = "Bearer " + session["access_token"]
    assert call(env[1], "GET", "/operator/reviews", env[3]) == []
    call(env[1], "GET", "/operator/cycles/" + cycle["id"], env[3], expected=409)
    with env[0].state.database.transaction() as db:
        current = env[0].state.menus.cycle(db, cycle["id"])
    failure = call(env[1], "POST", "/operator/cycles/" + cycle["id"] + "/approve", env[3],
                   {"expected_version": current["version"]}, idem=True, expected=409)
    assert failure["code"] == "CYCLE_EXPIRED"


def test_review_search_is_literal_paginated_and_operator_only(env):
    headers, _ = setup_user(env, alias="alpha_name")
    generate(env, headers)
    other, _ = setup_user(env, alias="beta_name")
    generate(env, other)
    response = env[1].get("/api/v1/operator/reviews?q=ALPHA_&limit=1", headers=env[3])
    assert response.status_code == 200
    result = response.json()
    assert result["meta"]["total"] == 1
    assert result["data"][0]["user"]["alias"] == "alpha_name"
    assert len(call(env[1], "GET", "/operator/reviews?q=_", env[3])) == 2
    call(env[1], "GET", "/operator/reviews?q=" + "a" * 81, env[3], expected=422)
    call(env[1], "GET", "/operator/reviews?q=alpha", headers, expected=403)


def test_week_summary_does_not_expose_private_proposal_and_updates_restrictions(env):
    headers, profile = setup_user(env)
    cycle = generate(env, headers)
    query = "/menus/week?start=2026-10-12"
    pending = call(env[1], "GET", query, headers)
    assert pending["summary"]["published_item_count"] == 0
    assert pending["summary"]["next_item_id"] is None
    approve(env, cycle)
    published = call(env[1], "GET", query, headers)
    assert published["summary"]["published_item_count"] == published["summary"]["future_item_count"] == 14
    assert published["summary"]["next_item_id"] == published["days"][0]["items"][0]["id"]
    codes = [item["code"] for item in env[0].state.menus.catalog.ingredients]
    call(env[1], "PATCH", "/profile", headers, {"expected_version": profile["version"], "excluded_ingredient_codes": codes})
    assert call(env[1], "GET", query, headers)["summary"]["attention_item_count"] == 14
