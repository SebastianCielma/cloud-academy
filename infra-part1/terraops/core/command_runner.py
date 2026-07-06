from __future__ import annotations

import os
import subprocess
from dataclasses import dataclass
from pathlib import Path

from terraops.core import logger


class CommandExecutionError(Exception):
    """Unified exception for actionable error handling across the platform."""
    pass


@dataclass
class CommandResult:
    command: list[str]
    returncode: int
    stdout: str
    stderr: str


def run_command(
    command: list[str],
    cwd: Path | None = None,
    timeout: int | None = None,
    env: dict[str, str] | None = None,
    check: bool = True,
    context: str = "Command execution",
) -> CommandResult:
    """
    Centralized execution mechanism.
    Standardizes subprocess execution, logging, and error handling.
    """
    cmd_str = " ".join(command)
    logger.info(f"[{context}] Executing command: {cmd_str}")

    process_env = os.environ.copy()
    if env:
        process_env.update(env)

    try:
        completed = subprocess.run(
            command,
            cwd=str(cwd) if cwd else None,
            env=process_env,
            timeout=timeout,
            text=True,
            capture_output=True,
            check=False,
        )
    except subprocess.TimeoutExpired as e:
        msg = f"{context} failed due to timeout ({timeout}s)."
        logger.error(msg)
        raise CommandExecutionError(msg) from e
    except Exception as e:
        msg = f"{context} failed unexpectedly: {str(e)}"
        logger.error(msg)
        raise CommandExecutionError(msg) from e

    if completed.returncode != 0:
        logger.error(f"[{context}] Failed with exit code {completed.returncode}")
        if completed.stderr:
            logger.error(f"[{context}] Stderr output:\n{completed.stderr.strip()}")
            
        if check:
            raise CommandExecutionError(
                f"{context} failed.\nExit code: {completed.returncode}\nDetails: {completed.stderr.strip()}"
            )
    else:
        logger.info(f"[{context}] Completed successfully.")

    return CommandResult(
        command=command,
        returncode=completed.returncode,
        stdout=completed.stdout,
        stderr=completed.stderr,
    )