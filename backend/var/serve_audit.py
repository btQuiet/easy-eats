from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import uvicorn
from app.api.routes import create_app
from app.config import Settings

settings = Settings(mode="test", db_path=Path(__file__).with_name("audit_20261010.sqlite"),
                    origins=("http://127.0.0.1:8280",))
uvicorn.run(create_app(settings), host="127.0.0.1", port=8281, access_log=False)
