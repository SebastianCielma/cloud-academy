from __future__ import annotations

import subprocess
from pathlib import Path

from terraops.core import logger


class TerraformProvider:
    def apply(self, stack_path: Path, tfvars_path: Path) -> int:
        logger.info("running terraform apply", stack=stack_path, tfvars=tfvars_path)
        init = subprocess.run(
            ["terraform", "init", "-input=false"],
            cwd=stack_path,
            text=True,
            capture_output=True,
        )
        if init.returncode != 0:
            logger.error("Terraform init failed", stderr=init.stderr.strip())
            return init.returncode

        apply = subprocess.run(
            ["terraform", "apply", "-auto-approve", "-var-file", str(tfvars_path.resolve())],
            cwd=stack_path,
            text=True,
            capture_output=True,
        )
        if apply.returncode != 0:
            logger.error("Terraform apply failed", stderr=apply.stderr.strip())
            return apply.returncode
        print(apply.stdout.strip())
        return 0

    def destroy(self, stack_path: Path, tfvars_path: Path) -> int:
        init = subprocess.run(
            ["terraform", "init", "-input=false"],
            cwd=stack_path,
            text=True,
            capture_output=True,
        )
        if init.returncode != 0:
            logger.error("Terraform init failed", stderr=init.stderr.strip())
            return init.returncode

        destroy = subprocess.run(
            ["terraform", "destroy", "-auto-approve", "-var-file", str(tfvars_path.resolve())],
            cwd=stack_path,
            text=True,
            capture_output=True,
        )
        if destroy.returncode != 0:
            logger.error("Terraform destroy failed", stderr=destroy.stderr.strip())
            return destroy.returncode
        print(destroy.stdout.strip())
        return 0
