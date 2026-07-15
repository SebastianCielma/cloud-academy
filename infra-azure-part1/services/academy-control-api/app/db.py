from __future__ import annotations

import os
import sqlite3
import sys
from pathlib import Path


SEED_STUDENTS = [
    ("john.doe", "John Doe"),
    ("anna.nowak", "Anna Nowak"),
    ("maria.dev", "Maria Dev"),
]

SEED_ASSIGNMENTS = [
    ("john.doe", "terraform-basics", "in_progress"),
    ("anna.nowak", "linux-runtime", "todo"),
    ("maria.dev", "debugging", "completed"),
    ("john.doe", "platform-observability", "failed"),
]


def database_url() -> str:
    return os.getenv("DATABASE_URL", "sqlite:///./academy.sqlite")


def sqlite_path(url: str | None = None) -> Path:
    value = url or database_url()
    if not value.startswith("sqlite:///"):
        raise ValueError(f"Only sqlite URLs are supported, got: {value}")
    return Path(value.replace("sqlite:///", "", 1))


def connect() -> sqlite3.Connection:
    path = sqlite_path()
    return sqlite3.connect(path)


def migrate() -> None:
    path = sqlite_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    with sqlite3.connect(path) as conn:
        conn.execute(
            "create table if not exists students (id integer primary key, username text unique, full_name text)"
        )
        conn.execute(
            "create table if not exists assignments (id integer primary key, student text, module text, status text)"
        )
        for username, full_name in SEED_STUDENTS:
            conn.execute(
                "insert or ignore into students(username, full_name) values (?, ?)",
                (username, full_name),
            )
        for student, module, status in SEED_ASSIGNMENTS:
            conn.execute(
                "insert into assignments(student, module, status) "
                "select ?, ?, ? where not exists "
                "(select 1 from assignments where student = ? and module = ?)",
                (student, module, status, student, module),
            )
        conn.commit()


def ready() -> tuple[bool, str]:
    try:
        with connect() as conn:
            conn.execute("select count(*) from assignments").fetchone()
        return True, "connected"
    except Exception as exc:
        return False, str(exc)


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "migrate":
        migrate()
    else:
        print(sqlite_path())

