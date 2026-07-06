from __future__ import annotations

from terraops.core import logger
from terraops.core.command_runner import CommandExecutionError, run_command


class VMProvider:
    def deploy(self, environment: str) -> int:
        logger.info(f"Starting VM deployment for environment: {environment}")
        try:
            result = run_command(
                command=["echo", f"deploy vm academy-control-api to {environment}"],
                context=f"VM deployment ({environment})",
                check=True
            )
            print(result.stdout.strip())
            return 0
        except CommandExecutionError:
            return 1