import asyncio
import json
from copy import deepcopy

import httpx
import pytest

from app.config import Settings
from app.domain import Catalog, DEFAULT_SLOTS, Problem, eligible_tier, score, validate_output
from app.integrations.generation import GroqGenerator, TestGenerator


@pytest.fixture
def generation_input():
    settings = Settings()
    catalog = Catalog(settings.catalog_path)
    profile = {"diet": "vegan", "repetition_tolerance": "normal", "allergen_codes": [],
               "excluded_ingredient_codes": [], "liked_ingredient_codes": [], "disliked_ingredient_codes": [],
               "preferred_categories": [], "alias": "PRIVATE_ALIAS", "address": "PRIVATE_ADDRESS"}
    slots = [{"date": f"2026-10-{day:02}", "meal_slot": slot} for day in range(12, 20) for slot in ("comida", "cena")]
    return catalog, {"profile": profile, "slots": slots, "history": [], "ratings": {}}


def test_determinism_coverage_and_variety(generation_input):
    catalog, snap = generation_input
    a = asyncio.run(TestGenerator().generate(snap, catalog))
    b = asyncio.run(TestGenerator().generate(snap, catalog))
    assert a == b and len(a[0]) == len(snap["slots"])
    assert all(catalog.recipe(i["recipe_code"])["is_vegan"] for i in a[0])
    for day in {x["date"] for x in a[0]}:
        codes = [x["recipe_code"] for x in a[0] if x["date"] == day]
        assert len(codes) == len(set(codes))


def test_validator_rejects_missing_duplicate_unknown_and_incompatible(generation_input):
    catalog, snap = generation_input
    valid, _ = asyncio.run(TestGenerator().generate(snap, catalog))
    invalids = [valid[:-1], [valid[0]] * len(valid), deepcopy(valid), deepcopy(valid), deepcopy(valid)]
    invalids[2][0]["recipe_code"] = "unknown"
    invalids[3][0]["recipe_code"] = next(r["code"] for r in catalog.recipes.values() if not r["is_vegan"])
    invalids[4][0]["recipe_code"] = ["bad_type"]
    for items in invalids:
        with pytest.raises(Problem) as err:
            validate_output(items, snap, catalog)
        assert err.value.code == "AI_INVALID_OUTPUT"


def test_relaxation_only_when_pool_requires_it(generation_input):
    catalog, snap = generation_input
    r = catalog.candidates(snap["profile"], "comida")[0]
    history = [{"date": "2026-10-11", "recipe_code": r["code"]}]
    assert eligible_tier([r], history, "2026-10-12", "low")[1] == 2
    history.append({"date": "2026-10-12", "recipe_code": r["code"]})
    assert eligible_tier([r], history, "2026-10-12", "low")[1] == 3


def test_preference_score_and_history(generation_input):
    catalog, snap = generation_input
    r = catalog.candidates(snap["profile"], "comida")[0]
    p = deepcopy(snap["profile"])
    p["liked_ingredient_codes"] = [x["code"] for x in r["ingredients"]]
    p["preferred_categories"] = [r["category"]]
    expected = min(6, 2 * len(r["ingredients"])) + 3 + 4 - 2
    assert score(r, p, [{"date": "2026-10-11", "recipe_code": r["code"]}], {r["code"]: 1}, "2026-10-12") == expected


def test_groq_contract_privacy_and_repair(generation_input):
    catalog, snap = generation_input
    valid, _ = asyncio.run(TestGenerator().generate(snap, catalog))
    calls = []
    def response(request):
        payload = json.loads(request.content)
        calls.append(payload)
        assert "PRIVATE_ALIAS" not in request.content.decode()
        assert "PRIVATE_ADDRESS" not in request.content.decode()
        assert payload["response_format"]["json_schema"]["strict"] is True
        content = json.dumps({"items": [] if len(calls) == 1 else valid})
        return httpx.Response(200, json={"choices": [{"message": {"content": content}}]})
    factory = lambda **kwargs: httpx.AsyncClient(transport=httpx.MockTransport(response), **kwargs)
    settings = Settings(mode="ai", groq_key="fictional-test-key")
    actual, _ = asyncio.run(GroqGenerator(settings, factory).generate(snap, catalog))
    assert actual == valid and len(calls) == 2


def test_rate_limit_has_no_local_fallback(generation_input):
    catalog, snap = generation_input
    calls = []
    def response(request):
        calls.append(request)
        return httpx.Response(429, headers={"Retry-After": "200"})
    factory = lambda **kwargs: httpx.AsyncClient(transport=httpx.MockTransport(response), **kwargs)
    with pytest.raises(Problem) as err:
        asyncio.run(GroqGenerator(Settings(mode="ai", groq_key="fake"), factory).generate(snap, catalog))
    assert err.value.code == "AI_RATE_LIMITED" and err.value.details["retry_after"] == 200
    assert len(calls) == 1


@pytest.mark.parametrize("payload", [
    {"choices": []},
    {"choices": [{"message": {"content": "[]"}}]},
    {"choices": [{"message": {"content": '{"items":[],"extra":1}'}}]},
])
def test_malformed_provider_response_gets_one_repair_and_controlled_error(generation_input, payload):
    catalog, snap = generation_input
    calls = []
    def response(request):
        calls.append(request)
        return httpx.Response(200, json=payload)
    factory = lambda **kwargs: httpx.AsyncClient(transport=httpx.MockTransport(response), **kwargs)
    with pytest.raises(Problem) as error:
        asyncio.run(GroqGenerator(Settings(mode="ai", groq_key="fake"), factory).generate(snap, catalog))
    assert error.value.code == "AI_INVALID_OUTPUT"
    assert len(calls) == 2


def test_transient_provider_failure_can_recover_once(generation_input):
    catalog, snap = generation_input
    valid, _ = asyncio.run(TestGenerator().generate(snap, catalog))
    calls = []
    def response(request):
        calls.append(request)
        if len(calls) == 1:
            return httpx.Response(503)
        return httpx.Response(200, json={"choices": [{"message": {"content": json.dumps({"items": valid})}}]})
    factory = lambda **kwargs: httpx.AsyncClient(transport=httpx.MockTransport(response), **kwargs)
    result, _ = asyncio.run(GroqGenerator(Settings(mode="ai", groq_key="fake"), factory).generate(snap, catalog))
    assert result == valid and len(calls) == 2
