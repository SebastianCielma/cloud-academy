from __future__ import annotations

import json

from terraops.core import logger
from terraops.providers.notifications import NotificationProvider

def run(args) -> int:
    logger.info("Starting notification read command", env=args.env, cloud=args.cloud)
    
    if args.notifications_command == "read":
        try:
            notifications = NotificationProvider().read(args.env)
            
            debug_output = []
            for notif in notifications:
                debug_output.append({
                    "status": "received",
                    "event_type": notif.get("event_type", "Unknown"),
                    "assignment_id": notif.get("assignment_id", "Unknown"),
                    "new_status": notif.get("new_status", "Unknown"),
                    "environment": notif.get("environment", args.env),
                    "received_from": "queue"
                })
                
            print(json.dumps(debug_output, indent=2))
            logger.info("Successfully displayed notifications", count=len(debug_output))
            return 0
        except Exception as e:
            logger.error("Failed to read notification queue", error=str(e))
            return 1
            
    logger.error("Unknown notifications command", command=args.notifications_command)
    print("unknown notifications command")
    return 2