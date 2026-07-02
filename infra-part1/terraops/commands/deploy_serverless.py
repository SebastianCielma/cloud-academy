from __future__ import annotations

from terraops.core.config_loader import load_config
from terraops.providers.serverless import ServerlessProvider


def run(args) -> int:
    load_config(args.cloud, args.env)
    return ServerlessProvider().deploy(args.service, args.env)

