from __future__ import annotations

from pathlib import Path

from terraops.core import logger
from terraops.core.command_runner import run_command, CommandExecutionError


class TerraformProvider:
    def _init(self, stack_path: Path) -> None:
        """Shared initialization logic to reduce duplication."""
        run_command(["terraform", "init", "-input=false"], cwd=stack_path)

    def apply(self, stack_path: Path, tfvars_path: Path) -> int:
        logger.info("Starting Terraform apply pipeline", stack=stack_path.name, tfvars=tfvars_path.name)
        try:
            self._init(stack_path)
            result = run_command(
                ["terraform", "apply", "-auto-approve", "-var-file", str(tfvars_path.resolve())],
                cwd=stack_path
            )
            print(result.stdout)
            return 0
        except CommandExecutionError as e:
            logger.error(
                f"Terraform apply failed for stack '{stack_path.name}'. Exit code: {e.returncode}",
                stderr=e.stderr
            )
            return e.returncode

    def destroy(self, stack_path: Path, tfvars_path: Path) -> int:
        logger.info("Starting Terraform destroy pipeline", stack=stack_path.name, tfvars=tfvars_path.name)
        try:
            self._init(stack_path)
            result = run_command(
                ["terraform", "destroy", "-auto-approve", "-var-file", str(tfvars_path.resolve())],
                cwd=stack_path
            )
            print(result.stdout)
            return 0
        except CommandExecutionError as e:
            logger.error(
                f"Terraform destroy failed for stack '{stack_path.name}'. Exit code: {e.returncode}",
                stderr=e.stderr
            )
            return e.returncode