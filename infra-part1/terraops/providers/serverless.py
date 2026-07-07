from __future__ import annotations

import shutil
from pathlib import Path

from terraops.core import logger
from terraops.core.paths import GENERATED, ROOT, STACKS
from terraops.providers.terraform import TerraformProvider
from terraops.terraform.tfvars import write_tfvars


class ServerlessProvider:
    def deploy(self, cloud: str, environment: str, service: str, config: dict) -> int:
        logger.info(f"Starting Serverless deployment for service '{service}' in '{environment}'")
        
        logger.info("Packaging serverless service")
        zip_path = GENERATED / service
        try:
            shutil.make_archive(
                base_name=str(zip_path),
                format='zip',
                root_dir=str(ROOT),
                base_dir="app"
            )
            logger.info(f"Successfully packaged application to {zip_path}.zip")
        except Exception as e:
            logger.error(f"Failed to package serverless application: {e}")
            return 1

        stack_path = STACKS / cloud / "serverless"
        if not stack_path.exists():
            logger.error(f"Serverless infrastructure stack not found at: {stack_path}")
            return 1

        logger.info(f"Applying Terraform configuration for stack '{stack_path.name}'")
        try:
            tfvars_path = write_tfvars(config, "serverless")
            
            tf_provider = TerraformProvider()
            return tf_provider.apply(stack_path, tfvars_path)
            
        except Exception as e:
            logger.error(f"Serverless infrastructure deployment failed: {e}")
            return 1