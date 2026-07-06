from __future__ import annotations

import json
from pathlib import Path

from terraops.core import logger
from terraops.core.paths import GENERATED


class NotificationProvider:
    def read(self, environment: str) -> list[dict[str, object]]:
        logger.info(f"Reading notifications for environment '{environment}'")
        queue_file = GENERATED / f"notifications.{environment}.jsonl"
        
        if not queue_file.exists():
            logger.warning(f"Notification queue file not found: {queue_file}")
            return []
            
        try:
            lines = queue_file.read_text(encoding="utf-8").splitlines()
            notifications = [json.loads(line) for line in lines if line]
            logger.info(f"Successfully read {len(notifications)} notifications.")
            return notifications
        except json.JSONDecodeError as e:
            msg = f"Failed to parse notifications for environment '{environment}': {str(e)}"
            logger.error(msg)
            raise RuntimeError(msg) from e