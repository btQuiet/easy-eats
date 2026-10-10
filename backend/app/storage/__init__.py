import sqlite3
import os
from datetime import datetime, timezone
from contextlib import contextmanager
from pathlib import Path


class Database:
    def __init__(self, path):
        self.path = path
        path.parent.mkdir(parents=True, exist_ok=True)
        migrations = sorted((Path(__file__).resolve().parents[2] / "migrations").glob("[0-9]*.sql"))
        with sqlite3.connect(path) as probe:
            has_versions = probe.execute("SELECT 1 FROM sqlite_master WHERE type='table' AND name='schema_migrations'").fetchone()
            applied = {r[0] for r in probe.execute("SELECT version FROM schema_migrations")} if has_versions else set()
            pending = [(int(m.name.split('_')[0]), m) for m in migrations if int(m.name.split('_')[0]) not in applied]
            if pending and applied:
                backup = path.with_name(path.name + f".before_v{pending[0][0]}.bak")
                with sqlite3.connect(backup) as target:
                    probe.backup(target)
        with self.transaction() as db:
            for number, migration in pending:
                db.executescript("BEGIN IMMEDIATE;\n" + migration.read_text(encoding="utf-8"))
                db.execute("INSERT OR IGNORE INTO schema_migrations VALUES(?,?)",
                           (number, datetime.now(timezone.utc).isoformat()))
                db.commit()

    @contextmanager
    def instance(self):
        """An OS lock enforces the single embedded worker across processes."""
        lock = open(str(self.path) + ".lock", "a+b")
        try:
            if os.name == "nt":
                import msvcrt
                lock.seek(0)
                lock.write(b"0")
                lock.flush()
                lock.seek(0)
                msvcrt.locking(lock.fileno(), msvcrt.LK_NBLCK, 1)
            else:
                import fcntl
                fcntl.flock(lock.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
            yield
        finally:
            lock.close()

    @contextmanager
    def transaction(self):
        db = sqlite3.connect(self.path, timeout=5)
        db.row_factory = sqlite3.Row
        db.execute("PRAGMA foreign_keys=ON")
        db.execute("PRAGMA journal_mode=WAL")
        db.execute("PRAGMA busy_timeout=5000")
        db.execute("BEGIN IMMEDIATE")
        try:
            yield db
            db.commit()
        except BaseException:
            db.rollback()
            raise
        finally:
            db.close()
