from __future__ import annotations

from datetime import datetime, timezone


def log(level: str, message: str, **context: object) -> None:
    timestamp = datetime.now(timezone.utc).isoformat()
    extras = " ".join(f"{key}={value}" for key, value in context.items())
    suffix = f" {extras}" if extras else ""
    print(f"{timestamp} {level.upper()} {message}{suffix}")


def info(message: str, **context: object) -> None:
    log("info", message, **context)


def warning(message: str, **context: object) -> None:
    log("warning", message, **context)


def error(message: str, **context: object) -> None:
    log("error", message, **context)

