from __future__ import annotations

from terraops.core.config_loader import load_config


def run(args) -> int:
    config = load_config(args.cloud, args.env)
    print(f"TerraOps status: cloud={config['cloud']} env={config['environment']} stack={args.stack}")
    return 0

