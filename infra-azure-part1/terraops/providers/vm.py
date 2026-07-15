from __future__ import annotations

import subprocess


class VMProvider:
    def deploy(self, environment: str) -> int:
        try:
            output = subprocess.check_output(["echo", f"deploy vm academy-control-api to {environment}"])
            print(output.decode().strip())
            return 0
        except Exception as exc:
            print(f"vm failed: {exc}")
            return 1

