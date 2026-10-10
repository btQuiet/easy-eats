from __future__ import annotations

import hashlib
import re
import secrets
import sqlite3
from datetime import date
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from app.api.schemas import Credentials, FeedbackInput, GenerateInput, ProfileInput, ReplaceInput
from app.config import Settings
from app.domain.catalog import read_catalog
from app.services.menus import (
    MenuError, approve_first, client_swap, cycle_status, generate_cycle, get_delivery,
    get_week, operator_replace, pending_reviews, review_detail, save_feedback,
)
from app.services.profile import get_profile, save_profile
from app.storage.db import connection, hash_password, issue_session, resolve_session, utc_now


router = APIRouter()
bearer = HTTPBearer(auto_error=False)


def settings_for(request: Request) -> Settings:
    return request.app.state.settings


def current_user(
    request: Request,
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer),
) -> dict[str, Any]:
    if credentials is None:
        raise HTTPException(status_code=401, detail="Inicia sesión")
    with connection(settings_for(request)) as db:
        row = resolve_session(db, credentials.credentials)
    if row is None:
        raise HTTPException(status_code=401, detail="Sesión no válida o caducada")
    return dict(row)


def require_role(user: dict[str, Any], role: str) -> None:
    if user["role"] != role:
        raise HTTPException(status_code=403, detail="No tienes acceso a esta función")


def parse_month(month: str) -> str:
    if not re.fullmatch(r"\d{4}-(0[1-9]|1[0-2])", month):
        raise HTTPException(status_code=422, detail="Mes inválido; usa AAAA-MM")
    return month


def parse_day(value: str | None) -> date:
    if value is None:
        from app.services.menus import local_today
        return local_today()
    try:
        return date.fromisoformat(value)
    except ValueError as exc:
        raise HTTPException(status_code=422, detail="Fecha inválida; usa AAAA-MM-DD") from exc


@router.get("/health")
def health(request: Request) -> dict[str, Any]:
    return {"status": "ok", "mode": settings_for(request).mode}


@router.get("/system/capabilities")
def capabilities(request: Request) -> dict[str, Any]:
    settings = settings_for(request)
    return {
        "generation_mode": settings.mode,
        "can_generate": settings.mode == "test" or bool(settings.ai_api_key),
        "label": "Modo de pruebas · sin IA" if settings.mode == "test" else "Modo IA",
        "delivery_simulated": True,
    }


@router.post("/auth/register", status_code=201)
def register(body: Credentials, request: Request) -> dict[str, Any]:
    username = body.username.lower()
    salt = secrets.token_hex(16)
    with connection(settings_for(request)) as db:
        try:
            cursor = db.execute(
                "INSERT INTO users(username, password_hash, salt, role, created_at) "
                "VALUES (?, ?, ?, 'client', ?)",
                (username, hash_password(body.password, salt), salt, utc_now()),
            )
        except sqlite3.IntegrityError as exc:
            raise HTTPException(status_code=409, detail="Ese usuario ya existe") from exc
        token = issue_session(db, cursor.lastrowid)
    return {"token": token, "user": {"id": cursor.lastrowid,
                                      "username": username, "role": "client"}}


@router.post("/auth/login")
def login(body: Credentials, request: Request) -> dict[str, Any]:
    with connection(settings_for(request)) as db:
        row = db.execute("SELECT * FROM users WHERE username = ?", (body.username.lower(),)).fetchone()
        if row is None or hash_password(body.password, row["salt"]) != row["password_hash"]:
            raise HTTPException(status_code=401, detail="Usuario o contraseña incorrectos")
        token = issue_session(db, row["id"])
        user = {"id": row["id"], "username": row["username"], "role": row["role"]}
    return {"token": token, "user": user}


@router.get("/auth/me")
def me(user: dict[str, Any] = Depends(current_user)) -> dict[str, Any]:
    return user


@router.post("/auth/logout")
def logout(request: Request, user: dict[str, Any] = Depends(current_user),
           credentials: HTTPAuthorizationCredentials | None = Depends(bearer)) -> dict[str, bool]:
    del user
    if credentials:
        digest = hashlib.sha256(credentials.credentials.encode()).hexdigest()
        with connection(settings_for(request)) as db:
            db.execute("DELETE FROM sessions WHERE token_hash = ?", (digest,))
    return {"ok": True}


@router.get("/catalog/meta")
def catalog_meta(request: Request) -> dict[str, Any]:
    catalog = read_catalog(settings_for(request))
    return {"ingredients": catalog["ingredients"], "allergens": catalog["allergens"],
            "slots": ["desayuno", "comida", "cena", "merienda"],
            "recipe_count": len(catalog["recipes"]), "verified_for_real_food": False}


@router.get("/catalog/recipes")
def list_recipes(
    request: Request,
    slot: str | None = None,
    q: str = "",
    diet: str | None = None,
    limit: int = Query(default=150, ge=1, le=150),
) -> list[dict[str, Any]]:
    catalog = read_catalog(settings_for(request))
    results = list(catalog["recipes"].values())
    if slot:
        results = [item for item in results if slot in item["slots"]]
    if q.strip():
        term = q.strip().casefold()
        results = [item for item in results if term in item["name"].casefold() or
                   term in item["category"].casefold()]
    if diet == "vegan":
        results = [item for item in results if item["is_vegan"]]
    elif diet == "vegetarian":
        results = [item for item in results if item["is_vegetarian"]]
    return sorted(results, key=lambda item: item["name"])[:limit]


@router.get("/catalog/recipes/{code}")
def recipe_detail(code: str, request: Request) -> dict[str, Any]:
    recipe = read_catalog(settings_for(request))["recipes"].get(code)
    if recipe is None:
        raise HTTPException(status_code=404, detail="Plato no encontrado")
    return recipe


@router.get("/profile")
def profile(request: Request, user: dict[str, Any] = Depends(current_user)) -> dict[str, Any] | None:
    require_role(user, "client")
    return get_profile(settings_for(request), user["id"])


@router.put("/profile")
def update_profile(body: ProfileInput, request: Request,
                   user: dict[str, Any] = Depends(current_user)) -> dict[str, Any]:
    require_role(user, "client")
    catalog = read_catalog(settings_for(request))
    try:
        return save_profile(settings_for(request), user["id"], body,
                            {item["code"] for item in catalog["allergens"]},
                            {item["code"] for item in catalog["ingredients"]})
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc


@router.get("/menus/status")
def menu_status(month: str, request: Request,
                user: dict[str, Any] = Depends(current_user)) -> dict[str, Any]:
    require_role(user, "client")
    return cycle_status(settings_for(request), user["id"], parse_month(month))


@router.post("/menus/generate", status_code=201)
def generate_menu(body: GenerateInput, request: Request,
                  user: dict[str, Any] = Depends(current_user)) -> dict[str, Any]:
    require_role(user, "client")
    return generate_cycle(settings_for(request), user["id"], body.month)


@router.get("/menus/week")
def weekly_menu(request: Request, day: str | None = None,
                user: dict[str, Any] = Depends(current_user)) -> dict[str, Any]:
    require_role(user, "client")
    return get_week(settings_for(request), user["id"], parse_day(day))


@router.post("/menus/items/{item_id}/swap")
def swap_item(item_id: int, body: ReplaceInput, request: Request,
              user: dict[str, Any] = Depends(current_user)) -> dict[str, Any]:
    require_role(user, "client")
    return client_swap(settings_for(request), item_id, user["id"],
                       body.recipe_code, body.expected_version)


@router.post("/feedback")
def feedback(body: FeedbackInput, request: Request,
             user: dict[str, Any] = Depends(current_user)) -> dict[str, Any]:
    require_role(user, "client")
    return save_feedback(settings_for(request), user["id"], body.item_id,
                         body.rating, body.comment)


@router.get("/delivery/week")
def delivery(request: Request, day: str | None = None,
             user: dict[str, Any] = Depends(current_user)) -> dict[str, Any]:
    require_role(user, "client")
    return get_delivery(settings_for(request), user["id"], parse_day(day))


@router.get("/operator/pending")
def operator_pending(request: Request,
                     user: dict[str, Any] = Depends(current_user)) -> list[dict[str, Any]]:
    require_role(user, "operator")
    return pending_reviews(settings_for(request))


@router.get("/operator/cycles/{cycle_id}")
def operator_detail(cycle_id: int, request: Request,
                    user: dict[str, Any] = Depends(current_user)) -> dict[str, Any]:
    require_role(user, "operator")
    return review_detail(settings_for(request), cycle_id)


@router.post("/operator/cycles/{cycle_id}/approve")
def operator_approve(cycle_id: int, request: Request,
                     user: dict[str, Any] = Depends(current_user)) -> dict[str, Any]:
    require_role(user, "operator")
    return approve_first(settings_for(request), cycle_id, user["id"])


@router.post("/operator/cycles/{cycle_id}/regenerate")
def operator_regenerate(cycle_id: int, request: Request,
                        user: dict[str, Any] = Depends(current_user)) -> dict[str, Any]:
    require_role(user, "operator")
    detail = review_detail(settings_for(request), cycle_id)
    if detail["cycle"]["status"] != "pending_review":
        raise MenuError("not_pending", "Solo se puede regenerar una primera propuesta pendiente", 409)
    return generate_cycle(settings_for(request), detail["cycle"]["user_id"],
                          detail["cycle"]["month"], replace_pending=True)


@router.post("/operator/items/{item_id}/replace")
def operator_change(item_id: int, body: ReplaceInput, request: Request,
                    user: dict[str, Any] = Depends(current_user)) -> dict[str, Any]:
    require_role(user, "operator")
    return operator_replace(settings_for(request), item_id, user["id"],
                            body.recipe_code, body.expected_version)
