from __future__ import annotations

import subprocess
import os
from dataclasses import dataclass
from pathlib import Path

from terraops.core import logger


class CommandExecutionError(Exception):
    """Unified exception raised when a system command fails."""
    def __init__(self, message: str, returncode: int, stdout: str, stderr: str):
        super().__init__(message)
        self.returncode = returncode
        self.stdout = stdout
        self.stderr = stderr


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
    check: bool = True
) -> CommandResult:
    """Centralized command execution with standardized logging and error handling."""
    cmd_str = " ".join(command)
    logger.info("Executing command", command=cmd_str, cwd=str(cwd) if cwd else None)

    run_env = os.environ.copy()
    if env:
        run_env.update(env)

    completed = subprocess.run(
        command,
        cwd=str(cwd) if cwd else None,
        env=run_env,
        timeout=timeout,
        text=True,
        capture_output=True,
        check=False,
    )

    result = CommandResult(command, completed.returncode, completed.stdout.strip(), completed.stderr.strip())

    if completed.returncode != 0:
        logger.error(
            "Command execution failed",
            command=cmd_str,
            returncode=completed.returncode,
            stderr=result.stderr
        )
        if check:
            raise CommandExecutionError(
                f"Command '{cmd_str}' failed with exit code {completed.returncode}.",
                returncode=completed.returncode,
                stdout=result.stdout,
                stderr=result.stderr
            )
    else:
        logger.info("Command execution successful", command=cmd_str)

    return result