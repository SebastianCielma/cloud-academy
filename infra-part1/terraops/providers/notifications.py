from __future__ import annotations

import json
from pathlib import Path

from terraops.core.paths import GENERATED


class NotificationProvider:
    def read(self, environment: str) -> list[dict[str, object]]:
        queue_file = GENERATED / f"notifications.{environment}.jsonl"
        if not queue_file.exists():
            return []
        return [json.loads(line) for line in queue_file.read_text(encoding="utf-8").splitlines() if line]

