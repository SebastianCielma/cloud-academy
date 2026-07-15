"""AWS-specific Terraform variable mapping.

Keep this file limited to names expected by stacks/aws/*.
"""

from __future__ import annotations

from typing import Any


def network_lines(config: dict[str, Any]) -> list[str]:
    network = config.get("network", {})
    lines: list[str] = []
    if network.get("vpc_cidr"):
        lines.append(f'vpc_cidr = "{network["vpc_cidr"]}"')
    if network.get("public_subnet_cidr"):
        lines.append(f'public_subnet_cidr = "{network["public_subnet_cidr"]}"')
    return lines


def vm_lines(runtime_env: dict[str, str]) -> list[str]:
    return [
        f'app_port = "{runtime_env["APP_PORT"]}"',
        f'database_url = "{runtime_env["DATABASE_URL"]}"',
    ]
