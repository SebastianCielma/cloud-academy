from __future__ import annotations

from terraops.core import logger
from terraops.core.command_runner import run_command, CommandExecutionError


class VMProvider:
    def deploy(self, environment: str) -> int:
        logger.info("Starting VM deployment", environment=environment)
        try:
            result = run_command(["echo", f"deploy vm academy-control-api to {environment}"])
            print(result.stdout)
            return 0
        except CommandExecutionError as e:
            logger.error(
                f"VM deployment failed for environment '{environment}'. Exit code: {e.returncode}",
                stderr=e.stderr
            )
            return e.returncode