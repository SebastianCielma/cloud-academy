from __future__ import annotations

import json

from terraops.providers.notifications import NotificationProvider


def run(args) -> int:
    if args.notifications_command == "read":
        notifications = NotificationProvider().read(args.env)
        print(json.dumps(notifications, indent=2))
        return 0
    print("unknown notifications command")
    return 2

