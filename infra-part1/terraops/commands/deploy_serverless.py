from __future__ import annotations

import argparse

from terraops.core.config_loader import load_config
from terraops.providers.serverless import ServerlessProvider


def run(args: argparse.Namespace) -> int:
    """Execute the serverless deployment command."""
    config = load_config(args.cloud, args.env)
    
    provider = ServerlessProvider()
    return provider.deploy(
        cloud=args.cloud,
        environment=args.env,
        service=args.service,
        config=config
    )