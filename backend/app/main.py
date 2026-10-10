from __future__ import annotations

from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app.api.routes import router
from app.config import get_settings
from app.services.menus import MenuError
from app.storage.db import init_database


@asynccontextmanager
async def lifespan(app: FastAPI):
    init_database(app.state.settings)
    yield


app = FastAPI(title="Easy Eats API", version="0.1.0", lifespan=lifespan)
app.state.settings = get_settings()
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)
app.include_router(router)


@app.exception_handler(MenuError)
async def menu_error_handler(request: Request, exc: MenuError) -> JSONResponse:
    del request
    return JSONResponse(status_code=exc.status, content={"detail": str(exc), "code": exc.code})
