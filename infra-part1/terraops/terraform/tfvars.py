from __future__ import annotations

from pathlib import Path
from typing import Any

from terraops.core.paths import GENERATED
from terraops.terraform import tfvars_aws, tfvars_azure


def build_runtime_env(config: dict[str, Any]) -> dict[str, str]:
    runtime = config.get("runtime", {})
    database = config.get("database", {})
    environment = config["environment"]

    db_path = database.get("path")
    if not db_path:
        db_path = "/opt/academy-control-api/dev.sqlite"

    return {
        "ENVIRONMENT": runtime.get("environment", environment),
        "APP_PORT": str(runtime.get("port", 8000)),
        "DATABASE_URL": f"sqlite:///{db_path}",
    }


def _common_lines(config: dict[str, Any]) -> list[str]:
    return [
        f'cloud = "{config["cloud"]}"',
        f'environment = "{config["environment"]}"',
    ]


def _stack_lines(config: dict[str, Any], stack: str) -> list[str]:
    cloud = config["cloud"]
    runtime_env = build_runtime_env(config)

    # Provider-specific variable mapping stays in separate modules so AWS and Azure
    # schemas do not blur together while students trace the deployment flow.
    if cloud == "aws" and stack == "network":
        return tfvars_aws.network_lines(config)
    if cloud == "aws" and stack == "vm":
        return tfvars_aws.vm_lines(runtime_env)
    if cloud == "azure" and stack == "network":
        return tfvars_azure.network_lines(config)
    if cloud == "azure" and stack == "vm":
        return tfvars_azure.vm_lines(config, runtime_env)
    return []


def write_tfvars(config: dict[str, Any], stack: str) -> Path:
    GENERATED.mkdir(exist_ok=True)
    path = GENERATED / f"{config['cloud']}.{config['environment']}.{stack}.tfvars"
    lines = [*_common_lines(config), *_stack_lines(config, stack)]
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return path
