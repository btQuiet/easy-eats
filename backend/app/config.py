from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path


BACKEND_DIR = Path(__file__).resolve().parents[1]
ROOT_DIR = BACKEND_DIR.parent


@dataclass(frozen=True)
class Settings:
    mode: str
    database_path: Path
    catalog_path: Path
    ai_provider: str
    ai_model: str
    ai_api_key: str
    operator_password: str


def get_settings() -> Settings:
    mode = os.getenv("EASY_EATS_GENERATION_MODE", "test").strip().lower()
    if mode not in {"test", "ai"}:
        raise ValueError("EASY_EATS_GENERATION_MODE debe ser test o ai")
    return Settings(
        mode=mode,
        database_path=BACKEND_DIR / "var" / f"app_{mode}.sqlite",
        catalog_path=ROOT_DIR / "data" / "catalog.sqlite",
        ai_provider=os.getenv("EASY_EATS_AI_PROVIDER", "groq").strip().lower(),
        ai_model=os.getenv("EASY_EATS_AI_MODEL", "openai/gpt-oss-120b").strip(),
        ai_api_key=os.getenv("EASY_EATS_AI_API_KEY", "").strip(),
        operator_password=os.getenv("EASY_EATS_OPERATOR_PASSWORD", "demo1234"),
    )
