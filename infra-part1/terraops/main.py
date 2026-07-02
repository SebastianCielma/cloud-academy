from __future__ import annotations

import argparse

from terraops.commands import apply, deploy, deploy_serverless, destroy, notifications, status, validate


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="terraops")
    sub = parser.add_subparsers(dest="command", required=True)

    for name in ("apply", "deploy", "destroy", "validate", "status"):
        cmd = sub.add_parser(name)
        cmd.add_argument("--cloud", required=True)
        cmd.add_argument("--env", required=True)
        cmd.add_argument("--stack", default="vm")
        if name == "destroy":
            cmd.add_argument("--confirm-prod-destroy", action="store_true")

    serverless = sub.add_parser("deploy-serverless")
    serverless.add_argument("--cloud", required=True)
    serverless.add_argument("--env", required=True)
    serverless.add_argument("--service", required=True)

    notif = sub.add_parser("notifications")
    notif_sub = notif.add_subparsers(dest="notifications_command", required=True)
    read = notif_sub.add_parser("read")
    read.add_argument("--cloud", required=True)
    read.add_argument("--env", required=True)

    return parser


def main() -> int:
    args = build_parser().parse_args()

    handlers = {
        "apply": apply.run,
        "deploy": deploy.run,
        "destroy": destroy.run,
        "validate": validate.run,
        "status": status.run,
        "deploy-serverless": deploy_serverless.run,
        "notifications": notifications.run,
    }
    return handlers[args.command](args)


if __name__ == "__main__":
    raise SystemExit(main())

