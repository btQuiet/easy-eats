from __future__ import annotations

import hashlib
import secrets
import sqlite3
from contextlib import contextmanager
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Iterator

from app.config import Settings


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def hash_password(password: str, salt: str) -> str:
    return hashlib.pbkdf2_hmac("sha256", password.encode(), bytes.fromhex(salt), 180_000).hex()


def init_database(settings: Settings) -> None:
    settings.database_path.parent.mkdir(parents=True, exist_ok=True)
    with connection(settings) as db:
        db.executescript((Path(__file__).with_name("runtime_schema.sql")).read_text(encoding="utf-8"))
        existing = db.execute("SELECT id, password_hash, salt FROM users WHERE username = 'operario'").fetchone()
        if existing is None:
            salt = secrets.token_hex(16)
            db.execute(
                "INSERT INTO users(username, password_hash, salt, role, created_at) VALUES (?, ?, ?, 'operator', ?)",
                ("operario", hash_password(settings.operator_password, salt), salt, utc_now()),
            )
        elif hash_password(settings.operator_password, existing["salt"]) != existing["password_hash"]:
            salt = secrets.token_hex(16)
            db.execute(
                "UPDATE users SET password_hash = ?, salt = ? WHERE id = ?",
                (hash_password(settings.operator_password, salt), salt, existing["id"]),
            )
            db.execute("DELETE FROM sessions WHERE user_id = ?", (existing["id"],))


@contextmanager
def connection(settings: Settings) -> Iterator[sqlite3.Connection]:
    db = sqlite3.connect(settings.database_path, timeout=10)
    db.row_factory = sqlite3.Row
    db.execute("PRAGMA foreign_keys = ON")
    db.execute("PRAGMA busy_timeout = 10000")
    try:
        yield db
        db.commit()
    except BaseException:
        db.rollback()
        raise
    finally:
        db.close()


@contextmanager
def catalog_connection(settings: Settings) -> Iterator[sqlite3.Connection]:
    db = sqlite3.connect(settings.catalog_path)
    db.row_factory = sqlite3.Row
    db.execute("PRAGMA query_only = ON")
    try:
        yield db
    finally:
        db.close()


def issue_session(db: sqlite3.Connection, user_id: int) -> str:
    token = secrets.token_urlsafe(32)
    token_hash = hashlib.sha256(token.encode()).hexdigest()
    expires_at = (datetime.now(timezone.utc) + timedelta(days=7)).isoformat()
    db.execute("INSERT INTO sessions(token_hash, user_id, expires_at) VALUES (?, ?, ?)",
               (token_hash, user_id, expires_at))
    return token


def resolve_session(db: sqlite3.Connection, token: str) -> sqlite3.Row | None:
    token_hash = hashlib.sha256(token.encode()).hexdigest()
    return db.execute(
        "SELECT u.id, u.username, u.role FROM sessions AS s JOIN users AS u ON u.id = s.user_id "
        "WHERE s.token_hash = ? AND s.expires_at > ?",
        (token_hash, utc_now()),
    ).fetchone()
