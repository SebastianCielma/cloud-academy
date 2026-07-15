from __future__ import annotations

from terraops.core.config_loader import load_config
from terraops.core.paths import STACKS
from terraops.core.safety import confirm_destroy_allowed
from terraops.providers.terraform import TerraformProvider
from terraops.terraform.tfvars import write_tfvars


def run(args) -> int:
    if not confirm_destroy_allowed(args.env, getattr(args, "confirm_prod_destroy", False)):
        print("Destroy blocked by safety policy")
        return 2
    config = load_config(args.cloud, args.env)
    tfvars_path = write_tfvars(config, args.stack)
    return TerraformProvider().destroy(STACKS / args.cloud / args.stack, tfvars_path)

