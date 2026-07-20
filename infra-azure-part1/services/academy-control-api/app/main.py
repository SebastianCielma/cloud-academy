from __future__ import annotations

import json
import logging
import os
import sqlite3
from collections import Counter

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

from app import db

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="Academy Control API", version="1.3.0")

class StatusUpdate(BaseModel):
    status: str

@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}

@app.get("/ready")
def ready() -> dict[str, object]:
    ok, detail = db.ready()
    if not ok:
        raise HTTPException(status_code=503, detail=f"database connection failed: {detail}")
    return {
        "status": "ready",
        "environment": os.getenv("ENVIRONMENT", "dev"),
        "database": {"status": detail, "engine": "sqlite"},
    }

@app.get("/version")
def version() -> dict[str, str]:
    return {"version": "1.3.0", "environment": os.getenv("ENVIRONMENT", "dev")}

@app.get("/students")
def students() -> list[dict[str, object]]:
    with db.connect() as conn:
        rows = conn.execute("select id, username, full_name from students order by id").fetchall()
    return [{"id": row[0], "username": row[1], "full_name": row[2]} for row in rows]

@app.get("/assignments")
def assignments() -> list[dict[str, object]]:
    with db.connect() as conn:
        rows = conn.execute("select id, student, module, status from assignments order by id").fetchall()
    return [{"id": row[0], "student": row[1], "module": row[2], "status": row[3]} for row in rows]

@app.patch("/assignments/{assignment_id}/status")
def update_assignment_status(assignment_id: int, payload: StatusUpdate) -> dict[str, object]:
    with db.connect() as conn:
        row = conn.execute("select id, student, status from assignments where id = ?", (assignment_id,)).fetchone()
        if not row:
            raise HTTPException(status_code=404, detail="assignment not found")
        
        student = row[1]
        old_status = row[2]
        new_status = payload.status
        
        conn.execute("update assignments set status = ? where id = ?", (new_status, assignment_id))
        conn.commit()

    environment = os.getenv("ENVIRONMENT", "dev")
    event_payload = {
        "event_type": "AssignmentStatusChanged",
        "assignment_id": str(assignment_id),
        "old_status": old_status,
        "new_status": new_status,
        "environment": environment,
        "student": student
    }


    queue_file_path = os.getenv(
        "NOTIFICATIONS_QUEUE_FILE",
        os.path.abspath(os.path.join(os.path.dirname(__file__), f"../../../generated/notifications.{environment}.jsonl"))
    )
    
    try:
        os.makedirs(os.path.dirname(queue_file_path), exist_ok=True)
        with open(queue_file_path, "a", encoding="utf-8") as f:
            f.write(json.dumps(event_payload) + "\n")
        logger.info(f"Published event: {event_payload['event_type']} for assignment {assignment_id}")
    except Exception as e:
        logger.error(f"Failed to publish event to queue: {e}")

    return {"assignment_id": assignment_id, "old_status": old_status, "new_status": new_status}

@app.get("/stats")
def stats() -> dict[str, object]:
    with db.connect() as conn:
        student_count = conn.execute("select count(*) from students").fetchone()[0]
        rows = conn.execute("select status from assignments").fetchall()
    counts = Counter(row[0] for row in rows)
    return {
        "environment": os.getenv("ENVIRONMENT", "dev"),
        "version": "1.3.0",
        "students": student_count,
        "modules": 4,
        "assignments": {
            "todo": counts.get("todo", 0),
            "in_progress": counts.get("in_progress", 0),
            "completed": counts.get("completed", 0),
            "failed": counts.get("failed", 0),
        },
        "database": {"status": "connected", "engine": "sqlite"},
    }

@app.get("/metrics")
def metrics() -> str:
    try:
        with db.connect() as conn:
            assignments_count = conn.execute("select count(*) from assignments").fetchone()[0]
    except sqlite3.Error:
        assignments_count = 0
    return f"academy_assignments_total {assignments_count}\n"