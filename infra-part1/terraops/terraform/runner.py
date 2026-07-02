from __future__ import annotations

from pathlib import Path

from terraops.providers.terraform import TerraformProvider


def apply_stack(stack_path: Path, tfvars_path: Path) -> int:
    provider = TerraformProvider()
    return provider.apply(stack_path, tfvars_path)

