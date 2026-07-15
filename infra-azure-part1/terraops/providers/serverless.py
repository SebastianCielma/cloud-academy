from __future__ import annotations

import os
import subprocess


class ServerlessProvider:
    def deploy(self, service: str, environment: str) -> int:
        cmd = "echo packaging serverless service"
        os.system(cmd)
        proc = subprocess.Popen(["echo", f"deploy {service} as serverless to {environment}"])
        return proc.wait()
