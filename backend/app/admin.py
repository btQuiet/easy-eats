"""Explicit local provisioning, no public operator registration."""
import argparse
from getpass import getpass
from datetime import timedelta
import asyncio

from .config import Clock, Settings
from .domain import Catalog, DEFAULT_SLOTS, Problem
from .services.profiles import Profiles
from .services.menus import Menus
from .services.deliveries import Deliveries
from .security import create_user
from .storage import Database


def seed_demo(database, settings, prefix, password, clock=None):
    """Fictional historical fixtures; never changes the LAN server clock."""
    if settings.mode != "test":
        raise Problem("INVALID_INPUT", "Las cuentas históricas ficticias solo se crean en modo test.")
    actual = clock or Clock()
    class HistoricalClock(Clock):
        def now(self):
            return actual.now() - timedelta(days=14)
    past = HistoricalClock()
    catalog = Catalog(settings.catalog_path)
    profiles = Profiles(catalog, past)
    menus = Menus(database, catalog, profiles, settings, past)
    with database.transaction() as db:
        operator = create_user(db, prefix + "_operator", password, "operator", actual)
        clients = []
        for plan in ("free", "pro"):
            user = create_user(db, prefix + "_" + plan, password, "client", actual)
            user_id = user["id"]
            p = profiles.get(db, user_id)
            values = [("plan", {"plan": plan}), ("calendar", {"weekly_slots": DEFAULT_SLOTS}),
                      ("restrictions", {"diet": "omnivore", "allergen_codes": [], "excluded_ingredient_codes": []}),
                      ("preferences", {"liked_ingredient_codes": [], "disliked_ingredient_codes": [],
                                       "preferred_categories": [], "repetition_tolerance": "normal"}),
                      ("summary", {"service_start_date": (past.today() + timedelta(days=1)).isoformat(),
                                   **({"address": {"line1": "Calle de demostración 1", "city": "Ciudad ficticia", "postal_code": "00000", "notes": "Datos ficticios"}} if plan == "pro" else {})})]
            for step, fields in values:
                p = profiles.save_draft(db, user_id, p["version"], step, fields)
            profiles.complete(db, user_id, p["version"])
            _, attempt = menus.ensure(db, user_id, user_id, p["service_start_date"][:7])
            clients.append((user_id, attempt["cycle_id"]))
    while asyncio.run(menus.work_one()):
        pass
    with database.transaction() as db:
        for user_id, cycle_id in clients:
            cycle = menus.cycle(db, cycle_id)
            menus.approve(db, cycle_id, operator["id"], cycle["version"])
            Deliveries(profiles, past).sync(db, user_id)
        # Opinions deliberately refer to fictional meals now in the past.
        current_profiles = Profiles(catalog, actual)
        current_menus = Menus(database, catalog, current_profiles, settings, actual)
        for user_id, cycle_id in clients:
            item = db.execute("SELECT id FROM menu_items WHERE cycle_id=? AND cancelled=0 AND date<=? ORDER BY date LIMIT 1",
                              (cycle_id, actual.today().isoformat())).fetchone()
            if item:
                current_menus.feedback(db, item[0], user_id, 0, 1, "Opinión ficticia preparada para la demo.")
    return [prefix + "_" + role for role in ("free", "pro", "operator")]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=["create-operator", "seed-demo"])
    parser.add_argument("--alias")
    args = parser.parse_args()
    settings = Settings()
    alias = args.alias or input("Alias del operario / prefijo de demo: ")
    password = getpass("Contraseña (no se mostrará): ")
    if password != getpass("Repetir contraseña: "):
        raise SystemExit("Las contraseñas no coinciden.")
    try:
        database = Database(settings.db_path)
        if args.command == "seed-demo":
            # Refuse while a server owns this mode's database.
            with database.instance():
                accounts = seed_demo(database, settings, alias, password)
            print("Cuentas ficticias con historial: " + ", ".join(accounts))
        else:
            with database.transaction() as db:
                create_user(db, alias, password, "operator", Clock())
    except Problem as error:
        raise SystemExit(error.message)
    except OSError:
        raise SystemExit("Detén el servidor antes de preparar las cuentas históricas.")
    print(f"Preparación completada en modo {settings.mode}.")


if __name__ == "__main__":
    main()
