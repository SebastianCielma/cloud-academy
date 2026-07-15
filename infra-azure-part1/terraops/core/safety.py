from __future__ import annotations

import shutil
from pathlib import Path

def confirm_destroy_allowed(env: str, confirm_prod_destroy: bool = False) -> bool:
    """Return whether a destroy operation is allowed. Protect production."""
    if env == "prod" and not confirm_prod_destroy:
        return False
    return True

def validate_external_dependencies() -> None:
    """Verify required CLI tools exist on the local machine."""
    required_tools = ["terraform", "python3", "docker"]
    for tool in required_tools:
        if tool == "python3" and (shutil.which("python3") or shutil.which("python")):
            continue
            
        if not shutil.which(tool):
            raise SystemError(f"Required tool '{tool}' is not installed or not in PATH.")

def validate_stack_files(stack_path: Path) -> None:
    """Verify required Terraform files exist before deployment."""
    if not stack_path.exists():
        raise FileNotFoundError(f"Stack path does not exist: {stack_path}")
        
    required_files = ["main.tf", "variables.tf"]
    for file_name in required_files:
        if not (stack_path / file_name).exists():
            raise FileNotFoundError(f"Missing required file '{file_name}' in stack '{stack_path}'")