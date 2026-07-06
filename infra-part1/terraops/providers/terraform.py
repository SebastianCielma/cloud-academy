from __future__ import annotations

from pathlib import Path

from terraops.core import logger
from terraops.core.command_runner import CommandExecutionError, run_command


class TerraformProvider:
    def _init(self, stack_path: Path) -> None:
        """Shared initialization logic for all Terraform executions."""
        run_command(
            command=["terraform", "init", "-input=false"],
            cwd=stack_path,
            context=f"Terraform init (stack '{stack_path.name}')",
            check=True,
        )

    def apply(self, stack_path: Path, tfvars_path: Path) -> int:
        logger.info("running terraform apply", stack=stack_path, tfvars=tfvars_path)
        
        try:
            self._init(stack_path)
            
            result = run_command(
                command=["terraform", "apply", "-auto-approve", "-var-file", str(tfvars_path.resolve())],
                cwd=stack_path,
                context=f"Terraform apply for stack '{stack_path.name}'",
                check=True,
            )
            print(result.stdout.strip())
            return 0
        except CommandExecutionError as e:
            return 1

    def destroy(self, stack_path: Path, tfvars_path: Path) -> int:
        logger.info("running terraform destroy", stack=stack_path, tfvars=tfvars_path)
        
        try:
            self._init(stack_path)

            result = run_command(
                command=["terraform", "destroy", "-auto-approve", "-var-file", str(tfvars_path.resolve())],
                cwd=stack_path,
                context=f"Terraform destroy for stack '{stack_path.name}'",
                check=True,
            )
            print(result.stdout.strip())
            return 0
        except CommandExecutionError as e:
            return 1