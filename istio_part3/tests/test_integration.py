import json
import os
import socket
import subprocess
import sys
import tempfile
import time
import unittest
import urllib.error
import urllib.request
import uuid
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def free_port():
    with socket.socket() as listener:
        listener.bind(("127.0.0.1", 0))
        return listener.getsockname()[1]


def call(url, method="GET", headers=None, payload=None, timeout=5):
    data = None if payload is None else json.dumps(payload).encode()
    request = urllib.request.Request(url, method=method, headers=headers or {}, data=data)
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            return response.status, json.load(response)
    except urllib.error.HTTPError as error:
        return error.code, json.load(error)


class IntegrationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.directory = tempfile.TemporaryDirectory()
        cls.ports = {name: free_port() for name in ("api-gateway", "order-service", "payment-service", "inventory-service")}
        cls.urls = {name: f"http://127.0.0.1:{port}" for name, port in cls.ports.items()}
        cls.processes = []
        for name, port in cls.ports.items():
            environment = {**os.environ,
                "SERVICE_NAME": name,
                "PORT": str(port),
                "ORDER_URL": cls.urls["order-service"],
                "PAYMENT_URL": cls.urls["payment-service"],
                "INVENTORY_URL": cls.urls["inventory-service"],
                "PAYMENT_DATABASE": str(Path(cls.directory.name) / "payments.db"),
            }
            cls.processes.append(subprocess.Popen(
                [sys.executable, "-B", str(ROOT / "apps/server.py")],
                env=environment,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.PIPE,
            ))
        for name, url in cls.urls.items():
            for _ in range(50):
                try:
                    status, _ = call(url + "/healthz", timeout=0.2)
                    if status == 200:
                        break
                except (OSError, TimeoutError):
                    time.sleep(0.05)
            else:
                raise RuntimeError(f"Service did not start: {name}")

    @classmethod
    def tearDownClass(cls):
        for process in cls.processes:
            process.terminate()
        for process in cls.processes:
            try:
                process.communicate(timeout=3)
            except subprocess.TimeoutExpired:
                process.kill()
                process.communicate()
        cls.directory.cleanup()

    def test_end_to_end_order(self):
        status, body = call(self.urls["api-gateway"] + "/order")
        self.assertEqual(status, 200)
        self.assertEqual(body["order"]["inventory"]["stock_status"], "available")
        self.assertEqual(body["order"]["payment"]["payment_status"], "available")

    def test_inventory_failure_propagation(self):
        status, body = call(self.urls["api-gateway"] + "/order", headers={"X-Lab-Inventory-Fail-Every": "1"})
        self.assertEqual(status, 502)
        self.assertEqual(body["order"]["dependency"], "inventory")

    def test_idempotent_checkout_recovery(self):
        payload = {"order_id": str(uuid.uuid4()), "amount_cents": 1999, "currency": "USD"}
        before = call(self.urls["payment-service"] + "/stats")[1]
        status, response = call(self.urls["api-gateway"] + "/checkout", method="POST", payload=payload, headers={
            "Idempotency-Key": str(uuid.uuid4()),
            "X-Request-ID": str(uuid.uuid4()),
            "X-Lab-Drop-First-Response": "true",
            "X-Lab-App-Retries": "1",
        })
        after = call(self.urls["payment-service"] + "/stats")[1]
        self.assertEqual(status, 200)
        self.assertTrue(response["order"]["payment"]["replayed"])
        self.assertEqual(after["payments_created"] - before["payments_created"], 1)
        self.assertEqual(after["payment_attempts"] - before["payment_attempts"], 2)

    def test_checkout_without_key_creates_duplicate(self):
        payload = {"order_id": str(uuid.uuid4()), "amount_cents": 1999, "currency": "USD"}
        before = call(self.urls["payment-service"] + "/stats")[1]
        status, _ = call(self.urls["api-gateway"] + "/checkout", method="POST", payload=payload, headers={
            "X-Request-ID": str(uuid.uuid4()),
            "X-Lab-Drop-First-Response": "true",
            "X-Lab-App-Retries": "1",
        })
        after = call(self.urls["payment-service"] + "/stats")[1]
        self.assertEqual(status, 201)
        self.assertEqual(after["payments_created"] - before["payments_created"], 2)


if __name__ == "__main__":
    unittest.main()
