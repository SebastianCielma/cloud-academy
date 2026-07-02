from __future__ import annotations

from terraops.core.config_loader import load_config


def run(args) -> int:
    config = load_config(args.cloud, args.env)
    print(f"Loaded config for {config['cloud']}/{config['environment']}")
    return 0
