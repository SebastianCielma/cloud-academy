from __future__ import annotations

import subprocess
from dataclasses import dataclass
from pathlib import Path


@dataclass
class CommandResult:
    command: list[str]
    returncode: int
    stdout: str
    stderr: str


def run_command(command: list[str], cwd: Path | None = None, timeout: int | None = None) -> CommandResult:
    """Run a command and capture its result."""
    completed = subprocess.run(
        command,
        cwd=str(cwd) if cwd else None,
        timeout=timeout,
        text=True,
        capture_output=True,
        check=False,
    )
    return CommandResult(command, completed.returncode, completed.stdout, completed.stderr)
