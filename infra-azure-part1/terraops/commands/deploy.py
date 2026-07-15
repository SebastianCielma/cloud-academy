from __future__ import annotations

from terraops.core.config_loader import load_config
from terraops.core.paths import STACKS
from terraops.providers.vm import VMProvider
from terraops.terraform.runner import apply_stack
from terraops.terraform.tfvars import write_tfvars


def run(args) -> int:
    config = load_config(args.cloud, args.env)
    tfvars_path = write_tfvars(config, args.stack)
    stack_path = STACKS / args.cloud / args.stack
    rc = apply_stack(stack_path, tfvars_path)
    if rc != 0:
        return rc
    if args.stack != "vm":
        return 0
    return VMProvider().deploy(args.env)
