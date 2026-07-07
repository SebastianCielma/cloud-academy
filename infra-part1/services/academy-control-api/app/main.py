from __future__ import annotations

import json
import logging
import os
import sqlite3
from collections import Counter

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

from app import db

# Inicjalizacja loggera dla obserwowalności (Observability)
logger = logging.getLogger("academy-api")
logger.setLevel(logging.INFO)

app = FastAPI(title="Academy Control API", version="1.3.0")


class StatusUpdate(BaseModel):
    status: str


def publish_status_changed_event(assignment_id: int, student: str, old_status: str, new_status: str) -> None:
    """
    Funkcja pomocnicza realizująca wzorzec Event Publishing.
    Buduje i publikuje zdarzenie dla architektury asynchronicznej.
    """
    environment = os.getenv("ENVIRONMENT", "dev")
    
    # 1. Budowa payloadu zgodnie z wymaganiami biznesowymi
    event_payload = {
        "event_type": "AssignmentStatusChanged",
        "assignment_id": str(assignment_id),
        "old_status": old_status,
        "new_status": new_status,
        "environment": environment,
        "student": student
    }
    
    # 2. Logowanie zdarzenia (Runtime Observability)
    logger.info(f"Publishing event: {json.dumps(event_payload)}")

    # 3. Wysłanie zdarzenia (Event Routing)
    # W chmurze AWS użylibyśmy tutaj np. boto3.client('events').put_events(...) do EventBridge.
    # Na potrzeby naszego lokalnego środowiska/TerraOps, symulujemy wrzucenie na kolejkę
    # poprzez zapis do pliku JSONL, z którego czyta komenda "notifications read".
    try:
        # Próba zaimportowania boto3 dla prawdziwego wdrożenia AWS
        import boto3
        event_bus = os.getenv("EVENT_BUS_NAME")
        if event_bus:
            client = boto3.client('events')
            client.put_events(
                Entries=[{
                    'Source': 'academy.api',
                    'DetailType': 'AssignmentStatusChanged',
                    'Detail': json.dumps(event_payload),
                    'EventBusName': event_bus
                }]
            )
            logger.info("Event successfully sent to AWS EventBridge.")
            return
    except ImportError:
        pass # Boto3 niedostępne, przechodzimy do fallbacku lokalnego
    except Exception as e:
        logger.error(f"Failed to publish to AWS EventBridge: {e}")

    # Fallback lokalny dla komendy "terraops notifications read"
    try:
        queue_path = f"generated/notifications.{environment}.jsonl"
        with open(queue_path, "a", encoding="utf-8") as f:
            f.write(json.dumps(event_payload) + "\n")
        logger.info(f"Event written to local queue fallback: {queue_path}")
    except Exception as e:
        logger.error(f"Failed to write event to local queue: {e}")


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

        # Aktualizacja w bazie danych
        conn.execute("update assignments set status = ? where id = ?", (new_status, assignment_id))
        conn.commit()

    # Wywołanie nowej logiki Event Publishing zgodnie z biznesowym wymogiem
    publish_status_changed_event(
        assignment_id=assignment_id, 
        student=student, 
        old_status=old_status, 
        new_status=new_status
    )

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


# ==========================================
# SERVERLESS RUNTIME ADAPTER (MANGUM)
# ==========================================
try:
    from mangum import Mangum
    # Adapter ten pozwala API Gateway na wywoływanie aplikacji FastAPI wewnątrz AWS Lambda
    handler = Mangum(app)
except ImportError:
    logger.warning("Mangum not installed. Serverless handler will not be available.")