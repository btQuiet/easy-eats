from app.admin import seed_demo
from app.config import Settings
from app.storage import Database
from test_app import FixedClock


def test_historical_demo_is_explicit_and_reproducible(tmp_path):
    settings = Settings(db_path=tmp_path / "demo.sqlite")
    database = Database(settings.db_path)
    accounts = seed_demo(database, settings, "demo", "fictional-password", FixedClock())
    assert accounts == ["demo_free", "demo_pro", "demo_operator"]
    with database.transaction() as db:
        assert db.execute("SELECT COUNT(*) FROM initial_reviews").fetchone()[0] == 2
        assert db.execute("SELECT COUNT(*) FROM feedback").fetchone()[0] == 2
        assert db.execute("SELECT COUNT(*) FROM menu_items WHERE date<='2026-10-10' AND cancelled=0").fetchone()[0] > 0
