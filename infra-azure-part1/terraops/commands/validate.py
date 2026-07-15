from __future__ import annotations

import argparse
import sys

from terraops.core.config_loader import load_config
from terraops.core.safety import validate_external_dependencies, validate_stack_files
from terraops.core.paths import STACKS

def run(args: argparse.Namespace) -> int:
    print(f"Starting validation for {args.cloud} {args.env} (stack: {args.stack})...")
    
    try:
        validate_external_dependencies()
        print("External dependencies (terraform, python, docker) present.")

        config = load_config(args.cloud, args.env)
        print(f" Configuration file for {args.cloud}.{args.env} has required sections.")

        runtime = config.get("runtime", {})
        database = config.get("database", {})
        
        if "environment" not in runtime:
            raise ValueError("Missing required runtime variable: 'environment'")
        if "app_port" not in runtime:
            raise ValueError("Missing required runtime variable: 'app_port'")
        if "url" not in database:
            raise ValueError("Missing required database variable: 'url'")
            
        print("Required runtime and database variables are present.")

        stack_path = STACKS / args.cloud / args.stack
        validate_stack_files(stack_path)
        print(f"Required Terraform files found in {stack_path.relative_to(STACKS.parent)}.")

        print("\nValidation completed successfully!")
        return 0

    except (ValueError, FileNotFoundError, SystemError) as e:
        print(f"\n[VALIDATION ERROR] {e}", file=sys.stderr)
        return 1
    except Exception as e:
        print(f"\n[UNEXPECTED ERROR] {e}", file=sys.stderr)
        return 1