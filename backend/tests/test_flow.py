"""An end-to-end API journey through both roles and the two mode boundaries."""

from __future__ import annotations

import json as json_module
import tempfile
import unittest
from datetime import date
from pathlib import Path
from unittest.mock import patch

import httpx
from fastapi.testclient import TestClient

from app.config import Settings, get_settings
from app.main import app
from app.services.menus import local_today
from app.storage.db import connection


def month_after(day: date, count: int = 1) -> str:
    value = day.year * 12 + day.month - 1 + count
    return f"{value // 12:04d}-{value % 12 + 1:02d}"


class FullJourneyTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        baseline = get_settings()
        self.settings = Settings(
            mode="test", database_path=Path(self.temp.name) / "test.sqlite",
            catalog_path=baseline.catalog_path, ai_provider="groq",
            ai_model=baseline.ai_model, ai_api_key="", operator_password="demo1234",
        )
        app.state.settings = self.settings
        self.client_context = TestClient(app)
        self.client = self.client_context.__enter__()

    def tearDown(self) -> None:
        self.client_context.__exit__(None, None, None)
        self.temp.cleanup()
        app.state.settings = get_settings()

    def auth(self, username: str, password: str, register: bool = False) -> dict[str, str]:
        path = "/auth/register" if register else "/auth/login"
        result = self.client.post(path, json={"username": username, "password": password})
        self.assertIn(result.status_code, (200, 201), result.text)
        return {"Authorization": f"Bearer {result.json()['token']}"}

    def test_full_client_and_operator_flow(self) -> None:
        self.assertEqual(self.client.get("/catalog/meta").json()["recipe_count"], 125)
        client_headers = self.auth("cliente_demo", "prueba123", register=True)
        operator_headers = self.auth("operario", "demo1234")
        profile = {
            "plan": "free", "diet": "vegan",
            "schedule": [{"weekday": day, "slot": "comida"} for day in range(7)],
            "allergens": ["gluten"], "excluded_ingredients": [],
            "liked_ingredients": ["garbanzo"], "disliked_ingredients": [],
        }
        response = self.client.put("/profile", headers=client_headers, json=profile)
        self.assertEqual(response.status_code, 200, response.text)
        current_month = local_today().strftime("%Y-%m")
        generated = self.client.post("/menus/generate", headers=client_headers,
                                     json={"month": current_month})
        self.assertEqual(generated.status_code, 201, generated.text)
        self.assertEqual(generated.json()["status"], "pending_review")
        self.assertEqual(generated.json()["origin"], "test")
        self.assertEqual(self.client.get("/operator/pending", headers=client_headers).status_code, 403)
        pending = self.client.get("/operator/pending", headers=operator_headers).json()
        self.assertEqual(len(pending), 1)
        detail = self.client.get(f"/operator/cycles/{pending[0]['id']}", headers=operator_headers).json()
        self.assertTrue(detail["items"])
        for item in detail["items"]:
            self.assertTrue(item["recipe"]["is_vegan"])
            self.assertNotIn("gluten", [a["code"] for a in item["recipe"]["allergens"]])
        approved = self.client.post(f"/operator/cycles/{pending[0]['id']}/approve",
                                    headers=operator_headers)
        self.assertEqual(approved.status_code, 200, approved.text)
        self.assertEqual(self.client.get("/operator/pending", headers=operator_headers).json(), [])

        week = self.client.get("/menus/week", headers=client_headers).json()
        self.assertEqual(week["status"], "ready")
        self.assertTrue(week["items"])
        self.assertFalse(week["items"][0]["can_swap"])
        past_item = next(item for item in detail["items"] if item["day"] <= local_today().isoformat())
        feedback = self.client.post("/feedback", headers=client_headers,
                                    json={"item_id": past_item["id"], "rating": 1,
                                          "comment": "Me gustó"})
        self.assertEqual(feedback.status_code, 200, feedback.text)

        next_month = month_after(local_today())
        generated_next = self.client.post("/menus/generate", headers=client_headers,
                                          json={"month": next_month})
        self.assertEqual(generated_next.status_code, 201, generated_next.text)
        self.assertEqual(generated_next.json()["status"], "approved")
        first_of_next_month = date.fromisoformat(f"{next_month}-01")
        future_week = self.client.get("/menus/week", headers=client_headers,
                                      params={"day": first_of_next_month.isoformat()}).json()
        editable = next(item for item in future_week["items"] if item["can_swap"])
        alternatives = self.client.get("/catalog/recipes", params={"slot": editable["slot"]}).json()
        choice = next(recipe for recipe in alternatives if recipe["code"] != editable["recipe_code"])
        swapped = self.client.post(f"/menus/items/{editable['id']}/swap", headers=client_headers,
                                   json={"recipe_code": choice["code"],
                                         "expected_version": editable["version"]})
        self.assertEqual(swapped.status_code, 200, swapped.text)
        self.assertEqual(swapped.json()["version"], 2)
        conflict = self.client.post(f"/menus/items/{editable['id']}/swap", headers=client_headers,
                                    json={"recipe_code": choice["code"],
                                          "expected_version": editable["version"]})
        self.assertEqual(conflict.status_code, 409)
        self.assertEqual(self.client.get("/operator/pending", headers=operator_headers).json(), [])
        self.assertEqual(self.client.get("/delivery/week", headers=client_headers).status_code, 403)

        profile["plan"] = "pro"
        profile["address"] = "Calle de prueba 1"
        self.assertEqual(self.client.put("/profile", headers=client_headers, json=profile).status_code, 200)
        delivery = self.client.get("/delivery/week", headers=client_headers).json()
        self.assertTrue(delivery["simulated"])

    def test_ai_mode_without_key_is_explicitly_unavailable(self) -> None:
        self.settings = Settings(
            mode="ai", database_path=Path(self.temp.name) / "ai.sqlite",
            catalog_path=self.settings.catalog_path, ai_provider="groq",
            ai_model="openai/gpt-oss-120b", ai_api_key="", operator_password="demo1234",
        )
        app.state.settings = self.settings
        self.client_context.__exit__(None, None, None)
        self.client_context = TestClient(app)
        self.client = self.client_context.__enter__()
        self.assertFalse(self.client.get("/system/capabilities").json()["can_generate"])
        headers = self.auth("cliente_ai", "prueba123", register=True)
        profile = {
            "plan": "free", "diet": "omnivore",
            "schedule": [{"weekday": 0, "slot": "comida"}],
        }
        self.assertEqual(self.client.put("/profile", headers=headers, json=profile).status_code, 200)
        result = self.client.post("/menus/generate", headers=headers,
                                  json={"month": local_today().strftime("%Y-%m")})
        self.assertEqual(result.status_code, 503)
        self.assertEqual(result.json()["code"], "missing_api_key")
        self.assertEqual(self.client.get("/menus/status", headers=headers,
                                         params={"month": local_today().strftime("%Y-%m")}).json()["status"],
                         "not_generated")

    def test_operator_regeneration_replaces_pending_cycle(self) -> None:
        client_headers = self.auth("cliente_regen", "prueba123", register=True)
        operator_headers = self.auth("operario", "demo1234")
        profile = {"plan": "free", "diet": "omnivore",
                   "schedule": [{"weekday": 0, "slot": "comida"}]}
        self.client.put("/profile", headers=client_headers, json=profile)
        first = self.client.post("/menus/generate", headers=client_headers,
                                 json={"month": local_today().strftime("%Y-%m")}).json()
        regenerated = self.client.post(f"/operator/cycles/{first['id']}/regenerate",
                                        headers=operator_headers)
        self.assertEqual(regenerated.status_code, 200, regenerated.text)
        second = regenerated.json()
        self.assertEqual(second["status"], "pending_review")
        self.assertEqual(self.client.get("/operator/pending", headers=operator_headers).json()[0]["id"],
                         second["id"])
        with connection(self.settings) as db:
            self.assertEqual(db.execute("SELECT COUNT(*) FROM generation_attempts").fetchone()[0], 2)
            self.assertEqual(db.execute("SELECT COUNT(*) FROM menu_cycles").fetchone()[0], 1)

    def test_ai_adapter_contract_with_mock_provider(self) -> None:
        self.settings = Settings(
            mode="ai", database_path=Path(self.temp.name) / "ai_mock.sqlite",
            catalog_path=self.settings.catalog_path, ai_provider="groq",
            ai_model="openai/gpt-oss-120b", ai_api_key="fake-test-key",
            operator_password="demo1234",
        )
        app.state.settings = self.settings
        self.client_context.__exit__(None, None, None)
        self.client_context = TestClient(app)
        self.client = self.client_context.__enter__()
        headers = self.auth("cliente_mock", "prueba123", register=True)
        profile = {"plan": "free", "diet": "vegetarian",
                   "schedule": [{"weekday": 0, "slot": "comida"}]}
        self.assertEqual(self.client.put("/profile", headers=headers, json=profile).status_code, 200)

        calls = []

        class FakeGroqClient:
            def __init__(self, **kwargs):
                self.timeout = kwargs["timeout"]

            def __enter__(self):
                return self

            def __exit__(self, *_):
                return False

            def post(self, url, *, headers, json):
                calls.append((url, headers, json))
                candidates = json["messages"][1]["content"]
                prompt = json_module.loads(candidates)
                code = prompt["candidates_by_meal"]["comida"][0]["code"]
                assignments = [[day, slot, code] for day, slot in prompt["slots"]]
                content = json_module.dumps({"assignments": assignments})
                return httpx.Response(200, request=httpx.Request("POST", url),
                                      json={"choices": [{"message": {"content": content}}]})

        with patch("app.integrations.generation.httpx.Client", FakeGroqClient):
            response = self.client.post("/menus/generate", headers=headers,
                                        json={"month": local_today().strftime("%Y-%m")})
        self.assertEqual(response.status_code, 201, response.text)
        self.assertEqual(response.json()["origin"], "ai")
        self.assertEqual(response.json()["status"], "pending_review")
        self.assertEqual(calls[0][0], "https://api.groq.com/openai/v1/chat/completions")
        self.assertEqual(calls[0][1]["Authorization"], "Bearer fake-test-key")
        self.assertEqual(calls[0][2]["response_format"], {"type": "json_object"})

        bad_headers = self.auth("otro_mock", "prueba123", register=True)
        self.client.put("/profile", headers=bad_headers, json=profile)

        class BadGroqClient(FakeGroqClient):
            def post(self, url, *, headers, json):
                prompt = json_module.loads(json["messages"][1]["content"])
                invalid = [[day, slot, "plato_inexistente"] for day, slot in prompt["slots"]]
                content = json_module.dumps({"assignments": invalid})
                return httpx.Response(200, request=httpx.Request("POST", url),
                                      json={"choices": [{"message": {"content": content}}]})

        with patch("app.integrations.generation.httpx.Client", BadGroqClient):
            invalid = self.client.post("/menus/generate", headers=bad_headers,
                                       json={"month": local_today().strftime("%Y-%m")})
        self.assertEqual(invalid.status_code, 502, invalid.text)
        self.assertEqual(invalid.json()["code"], "invalid_recipe")
        status = self.client.get("/menus/status", headers=bad_headers,
                                 params={"month": local_today().strftime("%Y-%m")}).json()
        self.assertEqual(status["status"], "not_generated")


if __name__ == "__main__":
    unittest.main()
