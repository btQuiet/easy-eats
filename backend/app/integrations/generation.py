from __future__ import annotations

import hashlib
import json
from collections import Counter
from dataclasses import dataclass
from typing import Any

import httpx

from app.config import Settings


class GenerationError(Exception):
    def __init__(self, code: str, message: str):
        self.code = code
        super().__init__(message)


@dataclass
class GenerationRequest:
    month: str
    slots: list[tuple[str, str]]
    candidates: dict[str, list[dict[str, Any]]]
    scores: dict[str, int]


def _stable_tiebreak(value: str) -> int:
    return int(hashlib.sha256(value.encode()).hexdigest()[:12], 16)


def generate_test(request: GenerationRequest) -> list[tuple[str, str, str]]:
    """Reproducible local generator. It does not use artificial intelligence."""
    usage: Counter[str] = Counter()
    chosen = []
    for day, slot in request.slots:
        options = request.candidates[slot]
        recipe = min(
            options,
            key=lambda item: (
                usage[item["code"]],
                -request.scores.get(item["code"], 0),
                _stable_tiebreak(f"{request.month}|{day}|{slot}|{item['code']}"),
            ),
        )
        chosen.append((day, slot, recipe["code"]))
        usage[recipe["code"]] += 1
    return chosen


def generate_ai(request: GenerationRequest, settings: Settings) -> list[tuple[str, str, str]]:
    if settings.ai_provider != "groq":
        raise GenerationError("provider_unsupported", "El proveedor de IA configurado no está disponible")
    if not settings.ai_api_key:
        raise GenerationError("missing_api_key", "El modo IA requiere una clave configurada en el servidor")

    shortlists: dict[str, list[dict[str, str]]] = {}
    for slot in {slot for _, slot in request.slots}:
        ranked = sorted(
            request.candidates[slot],
            key=lambda recipe: (-request.scores.get(recipe["code"], 0), recipe["code"]),
        )[:30]
        shortlists[slot] = [
            {"code": recipe["code"], "name": recipe["name"],
             "category": recipe["category"], "cuisine": recipe["cuisine"]}
            for recipe in ranked
        ]

    payload = {
        "model": settings.ai_model,
        "messages": [
            {"role": "system", "content": (
                "Eres un planificador de menús de demostración. Devuelve SOLO un objeto JSON "
                "con la clave assignments, una lista de [fecha, comida, codigo_plato]. "
                "Rellena exactamente cada hueco una vez. Para cada comida, usa exclusivamente "
                "un codigo de su lista de candidatos. Prioriza variedad y evita repeticiones "
                "cercanas. No añadas comentarios ni platos nuevos."
            )},
            {"role": "user", "content": json.dumps({
                "month": request.month,
                "slots": request.slots,
                "candidates_by_meal": shortlists,
                "preference_scores": {code: score for code, score in request.scores.items() if score},
            }, ensure_ascii=False, separators=(",", ":"))},
        ],
        "response_format": {"type": "json_object"},
        "temperature": 0.3,
        "max_completion_tokens": 7000,
    }
    try:
        with httpx.Client(timeout=90) as client:
            response = client.post(
                "https://api.groq.com/openai/v1/chat/completions",
                headers={"Authorization": f"Bearer {settings.ai_api_key}"},
                json=payload,
            )
            response.raise_for_status()
            content = response.json()["choices"][0]["message"]["content"]
            raw = json.loads(content)["assignments"]
    except (httpx.HTTPError, ValueError, KeyError, IndexError, TypeError) as exc:
        raise GenerationError("ai_unavailable", "No se pudo obtener un menú válido del proveedor de IA") from exc

    if not isinstance(raw, list):
        raise GenerationError("invalid_ai_output", "La IA no devolvió una lista de asignaciones")
    try:
        return [(str(day), str(slot), str(code)) for day, slot, code in raw]
    except (TypeError, ValueError) as exc:
        raise GenerationError("invalid_ai_output", "La IA devolvió asignaciones mal formadas") from exc


def validate_proposal(request: GenerationRequest, proposal: list[tuple[str, str, str]]) -> None:
    expected = set(request.slots)
    actual = [(day, slot) for day, slot, _ in proposal]
    if len(proposal) != len(request.slots) or set(actual) != expected or len(actual) != len(set(actual)):
        raise GenerationError("invalid_coverage", "La propuesta no cubre exactamente todas las comidas del mes")
    allowed = {slot: {recipe["code"] for recipe in recipes}
               for slot, recipes in request.candidates.items()}
    for _, slot, code in proposal:
        if code not in allowed[slot]:
            raise GenerationError("invalid_recipe", "La propuesta contiene un plato no permitido")
