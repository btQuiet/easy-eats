import asyncio
import json
import time
import httpx

from ..domain import Problem, eligible_tier, score, validate_output


class TestGenerator:
    async def generate(self, snapshot, catalog):
        history, result = list(snapshot["history"]), []
        for slot in snapshot["slots"]:
            pool = catalog.candidates(snapshot["profile"], slot["meal_slot"])
            tier, _ = eligible_tier(pool, history, slot["date"], snapshot["profile"]["repetition_tolerance"])
            recipe = min(tier, key=lambda r: (-score(r, snapshot["profile"], history,
                                                    snapshot["ratings"], slot["date"]), r["code"]))
            item = dict(slot, recipe_code=recipe["code"])
            result.append(item)
            history.append(item)
        return validate_output(result, snapshot, catalog)


class GroqGenerator:
    def __init__(self, settings, client_factory=httpx.AsyncClient):
        self.settings, self.client_factory = settings, client_factory

    async def generate(self, snapshot, catalog):
        if not self.settings.groq_key:
            raise Problem("AI_NOT_CONFIGURED", "Falta configurar la clave de Groq.", 503)
        # No identity, address, credentials or free-text feedback leaves this service.
        safe_profile = {k: snapshot["profile"][k] for k in (
            "diet", "allergen_codes", "excluded_ingredient_codes", "liked_ingredient_codes",
            "disliked_ingredient_codes", "preferred_categories", "repetition_tolerance")}
        schema = {"type": "object", "additionalProperties": False, "required": ["items"],
                  "properties": {"items": {"type": "array", "items": {
                      "type": "object", "additionalProperties": False,
                      "required": ["date", "meal_slot", "recipe_code"],
                      "properties": {k: {"type": "string"} for k in ("date", "meal_slot", "recipe_code")}}}}}
        candidates = {m: [{"code": r["code"], "category": r["category"],
                          "ingredients": [i["code"] for i in r["ingredients"]]}
                         for r in catalog.candidates(snapshot["profile"], m)]
                      for m in {x["meal_slot"] for x in snapshot["slots"]}}
        instructions = (
            "Plan every supplied slot exactly once using candidate codes. Apply hard constraints. "
            "Process chronologically. Avoid same-day repeats and prefer below rolling 7-day recipe limit "
            "(low=1,normal=2,high=3). Only relax the weekly limit if no candidate remains; only allow "
            "same-day repeat if no distinct code exists. Score: +2 per liked ingredient capped6, "
            "-2 per disliked capped6,+3 preferred category,+4 mean rating,-2 occurrences prior14days. "
            "Include history and previous selections in repetition counts. Return only schema JSON.")
        messages = [{"role": "system", "content": instructions},
                    {"role": "user", "content": json.dumps({
                        "profile": safe_profile, "slots": snapshot["slots"], "candidates": candidates,
                        "history": snapshot["history"], "ratings": snapshot["ratings"]})}]
        deadline = time.monotonic() + 120
        async with self.client_factory(timeout=45) as client:
            for call in range(2):
                try:
                    response = await asyncio.wait_for(client.post("https://api.groq.com/openai/v1/chat/completions",
                        headers={"Authorization": f"Bearer {self.settings.groq_key}"},
                        json={"model": self.settings.groq_model, "messages": messages,
                              "reasoning_effort": "low", "max_completion_tokens": 8192,
                              "response_format": {"type": "json_schema", "json_schema": {
                                  "name": "monthly_menu", "strict": True, "schema": schema}}}), timeout=45)
                    if response.status_code == 429:
                        try:
                            retry = max(1, int(response.headers.get("retry-after", "1")))
                        except ValueError:
                            retry = 1
                        if call == 0 and retry + 45 < deadline - time.monotonic():
                            await asyncio.sleep(retry)
                            continue
                        raise Problem("AI_RATE_LIMITED", "Groq ha alcanzado un límite temporal.", 503, retry_after=retry)
                    if response.status_code >= 500:
                        if call == 0:
                            continue
                        raise Problem("AI_UNAVAILABLE", "El proveedor no está disponible.", 503)
                    if response.status_code != 200:
                        raise Problem("AI_UNAVAILABLE", "El proveedor ha rechazado la solicitud; revisa su configuración.", 503)
                    try:
                        content = json.loads(response.json()["choices"][0]["message"]["content"])
                        if not isinstance(content, dict) or set(content) != {"items"}:
                            raise ValueError("Invalid response envelope")
                        return validate_output(content["items"], snapshot, catalog)
                    except (KeyError, IndexError, TypeError, ValueError, Problem):
                        if call == 1:
                            raise Problem("AI_INVALID_OUTPUT", "La IA no produjo un menú válido tras dos intentos.", 503)
                        messages.append({"role": "user", "content": "Previous output failed validation. Return complete coverage, strict schema, compatible codes and the available variety tier."})
                except (httpx.HTTPError, asyncio.TimeoutError):
                    if call == 1:
                        raise Problem("AI_UNAVAILABLE", "No se pudo conectar con el proveedor.", 503)
        raise Problem("AI_UNAVAILABLE", "La generación no terminó.", 503)
