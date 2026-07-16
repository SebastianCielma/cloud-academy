from __future__ import annotations

import json
from pathlib import Path

from terraops.core import logger
from terraops.core.paths import GENERATED


class NotificationProvider:
    def read(self, environment: str) -> list[dict[str, object]]:
        logger.info("Reading notifications queue", environment=environment)
        queue_file = GENERATED / f"notifications.{environment}.jsonl"
        
        if not queue_file.exists():
            logger.warning("Notification queue file not found, returning empty list", file=str(queue_file))
            return []
            
        try:
            notifications = [
                json.loads(line) 
                for line in queue_file.read_text(encoding="utf-8").splitlines() 
                if line
            ]
            logger.info("Successfully read notifications", count=len(notifications))
            return notifications
        except Exception as e:
            logger.error("Failed to parse notifications queue", error=str(e))
            return []