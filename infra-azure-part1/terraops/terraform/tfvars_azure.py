"""Azure-specific Terraform variable mapping.

Keep this file limited to names expected by stacks/azure/*.
"""

from __future__ import annotations

from typing import Any


def _common_lines(config: dict[str, Any]) -> list[str]:
    network = config.get("network", {})
    return [
        f'location = "{network["location"]}"',
        f'resource_group_name = "{network["resource_group_name"]}"',
    ]


def network_lines(config: dict[str, Any]) -> list[str]:
    network = config.get("network", {})
    return [
        *_common_lines(config),
        f'vnet_cidr = "{network["vnet_cidr"]}"',
        f'subnet_cidr = "{network["subnet_cidr"]}"',
    ]


def vm_lines(config: dict[str, Any], runtime_env: dict[str, str]) -> list[str]:
    vm = config.get("vm", {})
    return [
        *_common_lines(config),
        f'vm_size = "{vm.get("size", "Standard_B1s")}"',
        f'admin_username = "{vm.get("admin_username", "azureuser")}"',
        f'app_port = "{runtime_env["APP_PORT"]}"',
        f'database_url = "{runtime_env["DATABASE_URL"]}"',
    ]
