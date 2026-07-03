from __future__ import annotations

import shutil
from pathlib import Path
from typing import Any


def confirm_destroy_allowed(env: str, confirm_prod_destroy: bool = False) -> bool:
    """
    Ensure production environments are protected from accidental destruction.
    Requires explicit confirmation to proceed.
    """
    if env == "prod" and not confirm_prod_destroy:
        return False
    return True


def validate_dependencies() -> None:
    """
    Verify that all required external CLI tools are installed and accessible in the system PATH.
    """
    required_tools = ["terraform", "python3", "docker"]
    for tool in required_tools:
        if shutil.which(tool) is None:
            raise RuntimeError(
                f"Missing required external dependency: '{tool}'. "
                f"Please install it before proceeding with TerraOps deployment."
            )


def validate_required_files(stack_path: Path) -> None:
    """
    Verify the presence of essential Terraform configuration files in the target stack directory.
    """
    required_files = ["main.tf", "variables.tf"]
    for file_name in required_files:
        target_file = stack_path / file_name
        if not target_file.exists():
            raise FileNotFoundError(
                f"Missing required deployment file: '{file_name}' in {stack_path}"
            )


def validate_runtime_variables(config: dict[str, Any]) -> None:
    """
    Verify that the loaded configuration contains all mandatory runtime variables.
    """
    runtime = config.get("runtime", {})
    
    if "database_url" not in runtime:
        raise ValueError("Missing required runtime variable: 'database_url' in configuration.")
    
    if "app_port" not in runtime:
        raise ValueError("Missing required runtime variable: 'app_port' in configuration.")
        
    if "environment" not in config:
        raise ValueError("Missing required environment identifier in configuration.")