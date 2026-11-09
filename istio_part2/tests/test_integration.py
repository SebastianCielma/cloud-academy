import json
import os
import socket
import subprocess
import sys
import time
import unittest
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def open_port():
    with socket.socket() as probe:
        probe.bind(("127.0.0.1", 0))
        return probe.getsockname()[1]


class IntegrationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.ports = {role: open_port() for role in ("payment-v1", "payment-v2", "inventory", "order-v1", "order-v2", "gateway-v1", "gateway-v2")}
        cls.processes = []
        configurations = [
            ("payment-v1", "payment-service", "v1", {}),
            ("payment-v2", "payment-service", "v2", {}),
            ("inventory", "inventory-service", "v1", {}),
            ("order-v1", "order-service", "v1", {"PAYMENT_URL": f"http://127.0.0.1:{cls.ports['payment-v1']}", "INVENTORY_URL": f"http://127.0.0.1:{cls.ports['inventory']}"}),
            ("order-v2", "order-service", "v1", {"PAYMENT_URL": f"http://127.0.0.1:{cls.ports['payment-v2']}", "INVENTORY_URL": f"http://127.0.0.1:{cls.ports['inventory']}"}),
            ("gateway-v1", "api-gateway", "v1", {"ORDER_URL": f"http://127.0.0.1:{cls.ports['order-v1']}"}),
            ("gateway-v2", "api-gateway", "v1", {"ORDER_URL": f"http://127.0.0.1:{cls.ports['order-v2']}"}),
        ]
        try:
            for role, service, version, variables in configurations:
                environment = {**os.environ, "SERVICE_NAME": service, "APP_VERSION": version, "PORT": str(cls.ports[role]), **variables}
                process = subprocess.Popen([sys.executable, "-u", str(ROOT / "apps" / "server.py")], env=environment, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                cls.processes.append(process)
            for role, port in cls.ports.items():
                deadline = time.monotonic() + 8
                while time.monotonic() < deadline:
                    try:
                        with urllib.request.urlopen(f"http://127.0.0.1:{port}/healthz", timeout=0.3) as response:
                            if response.status == 200:
                                break
                    except (OSError, ValueError):
                        time.sleep(0.1)
                else:
                    raise RuntimeError(f"Service {role} failed to start")
        except BaseException:
            cls.tearDownClass()
            raise

    @classmethod
    def tearDownClass(cls):
        for process in getattr(cls, "processes", []):
            if process.poll() is None:
                process.terminate()
        for process in getattr(cls, "processes", []):
            try:
                process.wait(timeout=3)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()

    def get_json(self, role, path, headers=None):
        request = urllib.request.Request(f"http://127.0.0.1:{self.ports[role]}{path}", headers=headers or {})
        try:
            with urllib.request.urlopen(request, timeout=5) as response:
                return response.status, json.load(response)
        except urllib.error.HTTPError as error:
            return error.code, json.load(error)

    def test_full_chain_v1(self):
        status, body = self.get_json("gateway-v1", "/order")
        self.assertEqual(status, 200)
        self.assertEqual(body["order"]["payment"]["version"], "v1")
        self.assertEqual(body["order"]["inventory"]["status"], "available")

    def test_full_chain_v2(self):
        status, body = self.get_json("gateway-v2", "/order")
        self.assertEqual(status, 200)
        self.assertEqual(body["order"]["payment"]["version"], "v2")

    def test_regression_reaches_client(self):
        status, body = self.get_json("gateway-v2", "/order", {"X-Lab-V2-Regression": "true"})
        self.assertEqual(status, 500)
        self.assertEqual(body["order"]["payment"]["version"], "v2")
        self.assertEqual(body["order"]["payment"]["error"], "simulated_regression")

    def test_stable_payment_ignores_regression(self):
        status, body = self.get_json("gateway-v1", "/order", {"X-Lab-V2-Regression": "true"})
        self.assertEqual(status, 200)
        self.assertEqual(body["order"]["payment"]["version"], "v1")

    def test_payment_statistics(self):
        status, body = self.get_json("payment-v2", "/stats")
        self.assertEqual(status, 200)
        self.assertGreaterEqual(body["payment_requests"], 1)
