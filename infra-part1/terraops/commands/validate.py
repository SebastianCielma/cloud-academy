from __future__ import annotations

import argparse  
import logging
from pathlib import Path
import logging

from terraops.core.config_loader import load_config
from terraops.core.paths import STACKS
from terraops.core.safety import (
    validate_dependencies,
    validate_required_files,
    validate_runtime_variables,
)

logger = logging.getLogger(__name__)
logging.basicConfig(level=logging.INFO, format="%(message)s")


def run(args: argparse.Namespace) -> None:
    """
    Run the validation suite for the specified cloud and environment.
    Fails fast if any validation step does not pass.
    """
    cloud = args.cloud
    env = args.env

    logger.info(f"Starting validation for cloud='{cloud}', env='{env}'")

    try:
        # Step 1: Validate external dependencies
        logger.info("Validating external dependencies")
        validate_dependencies()

        # Step 2: Validate and load configuration
        logger.info("Validating environment configuration files")
        config = load_config(cloud, env)

        # Step 3: Validate runtime variables
        logger.info("Validating runtime variables")
        validate_runtime_variables(config)

        # Step 4: Validate required files in Terraform stacks
        logger.info("Validating required Terraform files")
        for stack in ["network", "vm"]:
            stack_path = STACKS / cloud / stack
            if stack_path.exists():
                validate_required_files(stack_path)
            else:
                logger.warning(f"Stack directory not found skipping file check: {stack_path}")

        logger.info("All validations passed successfully!")

    except (FileNotFoundError, ValueError, RuntimeError) as e:
        logger.error(f"Validation failed: {str(e)}")
        raise SystemExit(1)