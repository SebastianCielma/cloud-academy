from __future__ import annotations

from terraops.core.config_loader import load_config
from terraops.core import logger
from terraops.providers.serverless import ServerlessProvider

def run(args) -> int:
    logger.info("Starting serverless deployment", cloud=args.cloud, env=args.env, service=args.service)
    try:
        config = load_config(args.cloud, args.env)
        logger.info("Configuration validated and loaded successfully", sections=list(config.keys()))
        
        return ServerlessProvider().deploy(args.service, args.env)
    except Exception as e:
        logger.error("Serverless deployment failed", error=str(e))
        return 1