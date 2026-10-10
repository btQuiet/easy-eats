import os
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from zoneinfo import ZoneInfo

ROOT = Path(__file__).resolve().parents[2]


@dataclass
class Settings:
    mode: str = field(default_factory=lambda: os.getenv("GENERATION_MODE", "test"))
    catalog_path: Path = ROOT / "data/catalog.sqlite"
    db_path: Path | None = None
    groq_key: str = field(default_factory=lambda: os.getenv("GROQ_API_KEY", ""))
    groq_model: str = field(default_factory=lambda: os.getenv("GROQ_MODEL", "openai/gpt-oss-120b"))
    origins: tuple = field(default_factory=lambda: tuple(
        x.strip() for x in os.getenv("CORS_ORIGINS", "http://localhost:8080,http://127.0.0.1:8080").split(",") if x.strip()))
    cookie_secure: bool = field(default_factory=lambda: os.getenv("COOKIE_SECURE", "false").lower() == "true")

    def __post_init__(self):
        if self.mode not in ("test", "ai"):
            raise ValueError("GENERATION_MODE must be test or ai")
        if self.db_path is None:
            self.db_path = ROOT / f"backend/var/app_{self.mode}.sqlite"
        self.db_path = Path(self.db_path)


class Clock:
    def now(self):
        return datetime.now(timezone.utc)

    def local(self):
        return self.now().astimezone(ZoneInfo("Europe/Madrid"))

    def today(self):
        return self.local().date()

    def stamp(self):
        return self.now().isoformat()
