import hashlib
import hmac
import re
import secrets
from datetime import timedelta

from .domain import Problem, dump, uid


def normalize_alias(alias):
    alias = alias.strip().lower()
    if not re.fullmatch(r"[a-z0-9_]{3,30}", alias):
        raise Problem("INVALID_INPUT", "Alias: 3–30 letras minúsculas, números o guion bajo.")
    return alias


def password_fields(password):
    if not isinstance(password, str) or not 8 <= len(password) <= 128:
        raise Problem("INVALID_INPUT", "La contraseña necesita entre 8 y 128 caracteres.")
    salt = secrets.token_bytes(16)
    params = {"n": 16384, "r": 8, "p": 1, "dklen": 32}
    hashed = hashlib.scrypt(password.encode(), salt=salt, **params)
    return hashed.hex(), salt.hex(), dump(params)


def create_user(db, alias, password, role, clock):
    alias = normalize_alias(alias)
    fields = password_fields(password)
    if db.execute("SELECT 1 FROM users WHERE alias_normalized=?", (alias,)).fetchone():
        raise Problem("ALIAS_TAKEN", "Ese alias ya está registrado.", 409)
    ident = uid()
    db.execute("INSERT INTO users VALUES(?,?,?,?,?,?,?)", (ident, alias, role, *fields, clock.stamp()))
    if role == "client":
        db.execute("INSERT INTO profiles(user_id,created_at,updated_at) VALUES(?,?,?)", (ident, clock.stamp(), clock.stamp()))
        db.execute("INSERT INTO plan_memberships(user_id) VALUES(?)", (ident,))
        db.execute("INSERT INTO onboarding_drafts VALUES(?,?,NULL,?)", (ident, "{}", clock.stamp()))
    return db.execute("SELECT * FROM users WHERE id=?", (ident,)).fetchone()


def new_session(db, user, transport, clock):
    if transport not in ("cookie", "bearer"):
        raise Problem("INVALID_INPUT", "Transporte de sesión no válido.")
    token = secrets.token_urlsafe(32)
    csrf = secrets.token_urlsafe(32) if transport == "cookie" else None
    expires = (clock.now() + timedelta(days=7)).isoformat()
    db.execute("INSERT INTO sessions VALUES(?,?,?,?,?,?,NULL)",
               (uid(), user["id"], hashlib.sha256(token.encode()).hexdigest(), transport, csrf, expires))
    result = session_dto(db, user, {"expires_at": expires, "csrf_token": csrf})
    if transport == "bearer":
        result["access_token"] = token
    return token, result


def session_dto(db, user, session):
    profile = db.execute("SELECT completed FROM profiles WHERE user_id=?", (user["id"],)).fetchone()
    return {"user": {"id": user["id"], "alias": user["alias_normalized"], "role": user["role"]},
            "expires_at": session["expires_at"], "csrf_token": session["csrf_token"],
            "onboarding_completed": bool(profile and profile["completed"])}


def verify_password(password, user):
    import json
    try:
        actual = hashlib.scrypt(password.encode(), salt=bytes.fromhex(user["password_salt"]),
                                **json.loads(user["password_parameters"])).hex()
        return hmac.compare_digest(actual, user["password_hash"])
    except (ValueError, TypeError):
        return False
