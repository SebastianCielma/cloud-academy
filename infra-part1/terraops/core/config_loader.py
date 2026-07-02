from __future__ import annotations

from pathlib import Path
from typing import Any

from terraops.core.paths import CONFIGS


def _load_yaml(path: Path) -> dict[str, Any]:
    data: dict[str, Any] = {}
    current_section: dict[str, Any] | None = None

    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.split("#", 1)[0].rstrip()
        if not line.strip():
            continue
        if not line.startswith(" "):
            key, _, value = line.partition(":")
            key = key.strip()
            value = value.strip()
            if value:
                data[key] = _parse_scalar(value)
                current_section = None
            else:
                current_section = {}
                data[key] = current_section
            continue
        if current_section is None:
            continue
        key, _, value = line.strip().partition(":")
        current_section[key.strip()] = _parse_scalar(value.strip())

    return data


def _parse_scalar(value: str) -> Any:
    value = value.strip().strip('"').strip("'")
    if value.lower() == "true":
        return True
    if value.lower() == "false":
        return False
    if value.isdigit():
        return int(value)
    return value


def load_config(cloud: str, env: str) -> dict[str, Any]:
    """Load environment config."""
    env_file = CONFIGS / f"{cloud}.{env}.yaml"
    if not env_file.exists():
        raise FileNotFoundError(f"Missing config file: {env_file}")

    config = _load_yaml(env_file)
    config["cloud"] = cloud
    config["environment"] = env

    dev_defaults = _load_yaml(CONFIGS / f"{cloud}.dev.yaml")
    if "database" not in config:
        config["database"] = dev_defaults.get("database", {})
    if "runtime" not in config:
        config["runtime"] = dev_defaults.get("runtime", {})

    return config
