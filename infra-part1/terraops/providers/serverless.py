from __future__ import annotations

from terraops.core import logger
from terraops.core.command_runner import CommandExecutionError, run_command


class ServerlessProvider:
    def deploy(self, service: str, environment: str) -> int:
        logger.info(f"Starting Serverless deployment for service '{service}' in '{environment}'")
        try:
            run_command(
                command=["echo", "packaging serverless service"],
                context=f"Serverless packaging ({service})",
                check=True
            )
            
            result = run_command(
                command=["echo", f"deploy {service} as serverless to {environment}"],
                context=f"Serverless deployment ({service} -> {environment})",
                check=True
            )
            print(result.stdout.strip())
            return 0
        except CommandExecutionError:
            return 1