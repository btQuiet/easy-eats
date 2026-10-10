import json
from datetime import date, datetime, time, timedelta
from zoneinfo import ZoneInfo

from ..domain import dump, monday, uid


class Deliveries:
    def __init__(self, profiles, clock):
        self.profiles, self.clock = profiles, clock

    def pro_on(self, db, user, day, include_pending=True):
        events = db.execute("SELECT new_plan FROM plan_events WHERE user_id=? AND effective_date<=? AND event_kind IN('initial','effective') ORDER BY effective_date DESC,created_at DESC LIMIT 1", (user, day)).fetchone()
        plan = self.profiles.plan(db, user)
        selected = events[0] if events else "free"
        if include_pending and plan["pending_plan"] and plan["effective_date"] <= day:
            selected = plan["pending_plan"]
        return selected == "pro"

    def boundaries(self, scheduled):
        d = date.fromisoformat(scheduled)
        tz = ZoneInfo("Europe/Madrid")
        return (datetime.combine(d - timedelta(days=1), time(9), tz),
                datetime.combine(d, time(9), tz), datetime.combine(d, time(18), tz))

    def sync(self, db, user):
        plan = self.profiles.plan(db, user)
        now = self.clock.local()
        include_pending = plan["pending_plan"] == "pro"
        rows = [dict(x) for x in db.execute(
            "SELECT i.id,i.date,i.recipe_code,i.recipe_snapshot_json FROM menu_items i JOIN menu_cycles c ON c.id=i.cycle_id WHERE c.user_id=? AND c.status='approved' AND i.cancelled=0 AND i.compatibility='compatible' ORDER BY i.date,i.id", (user,))]
        groups = {}
        for item in rows:
            if self.pro_on(db, user, item["date"], include_pending=include_pending):
                groups.setdefault(monday(date.fromisoformat(item["date"])).isoformat(), []).append(item)
        for week, items in groups.items():
            old = db.execute("SELECT * FROM deliveries WHERE user_id=? AND week_start=?", (user, week)).fetchone()
            if not old:
                db.execute("INSERT INTO deliveries(id,user_id,week_start,scheduled_date) VALUES(?,?,?,?)", (uid(), user, week, items[0]["date"]))
            elif not old["snapshot_taken_at"]:
                prepare, _, _ = self.boundaries(items[0]["date"])
                # A restored future plan/menu can revive an unfrozen simulation.
                # Completed or prepared snapshots remain historical records.
                if not old["cancelled_reason"] or now < prepare:
                    db.execute("UPDATE deliveries SET scheduled_date=?,cancelled_reason=NULL WHERE id=?", (items[0]["date"], old["id"]))
        for row in db.execute("SELECT * FROM deliveries WHERE user_id=?", (user,)).fetchall():
            prepare, transit, _ = self.boundaries(row["scheduled_date"])
            items = groups.get(row["week_start"], [])
            if row["cancelled_reason"]:
                continue
            ceased_before_transit = not self.pro_on(db, user, row["scheduled_date"], include_pending=include_pending)
            if (not items and now < prepare) or ceased_before_transit:
                db.execute("UPDATE deliveries SET cancelled_reason=? WHERE id=?", ("PLAN_FREE" if ceased_before_transit else "NO_VALID_MEALS", row["id"]))
                continue
            if now >= prepare and not row["snapshot_taken_at"]:
                address = self.profiles.address(db, user)
                snapshots = [{"item_id": i["id"], "date": i["date"], "recipe": json.loads(i["recipe_snapshot_json"])} for i in items]
                db.execute("UPDATE deliveries SET address_snapshot_json=?,items_snapshot_json=?,snapshot_taken_at=? WHERE id=?", (dump(address), dump(snapshots), self.clock.stamp(), row["id"]))

    def list(self, db, user, start=None):
        self.sync(db, user)
        result = []
        for row in db.execute("SELECT * FROM deliveries WHERE user_id=? ORDER BY week_start DESC", (user,)):
            if start and row["week_start"] < start:
                continue
            prepare, transit, done = self.boundaries(row["scheduled_date"])
            now = self.clock.local()
            state = "cancelled" if row["cancelled_reason"] else (
                "scheduled" if now < prepare else "preparing" if now < transit else "in_delivery" if now < done else "delivered")
            if row["items_snapshot_json"]:
                count = len(json.loads(row["items_snapshot_json"]))
            else:
                count = db.execute("SELECT COUNT(*) FROM menu_items i JOIN menu_cycles c ON c.id=i.cycle_id WHERE c.user_id=? AND c.status='approved' AND i.cancelled=0 AND i.compatibility='compatible' AND i.date>=? AND i.date<=?", (user, row["week_start"], (date.fromisoformat(row["week_start"]) + timedelta(days=6)).isoformat())).fetchone()[0]
            result.append({"id": row["id"], "week_start": row["week_start"], "scheduled_date": row["scheduled_date"],
                           "status": state, "simulated": True,
                           "address_snapshot": json.loads(row["address_snapshot_json"]) if row["address_snapshot_json"] else None,
                           "meal_count": count, "cancelled_reason": row["cancelled_reason"]})
        return result
