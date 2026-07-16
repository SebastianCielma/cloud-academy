from __future__ import annotations

from terraops.core import logger
from terraops.core.command_runner import run_command, CommandExecutionError


class ServerlessProvider:
    def deploy(self, service: str, environment: str) -> int:
        logger.info("Starting serverless deployment pipeline", service=service, environment=environment)
        try:
            run_command(["echo", "packaging serverless service"])
            result = run_command(["echo", f"deploy {service} as serverless to {environment}"])
            print(result.stdout)
            return 0
        except CommandExecutionError as e:
            logger.error(
                f"Serverless deployment failed for service '{service}' in environment '{environment}'. Exit code: {e.returncode}",
                stderr=e.stderr
            )
            return e.returncode