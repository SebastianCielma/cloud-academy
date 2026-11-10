import json
import tempfile
import threading
import unittest
import urllib.error
import urllib.request
import uuid
from http.server import ThreadingHTTPServer
from pathlib import Path

from apps import server
from tools.loadtest import percentile


class ServiceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.directory = tempfile.TemporaryDirectory()
        server.SERVICE_NAME = "payment-service"
        server.PAYMENT_DATABASE = str(Path(cls.directory.name) / "payments.db")
        server.STATE = server.State()
        cls.http = ThreadingHTTPServer(("127.0.0.1", 0), server.Handler)
        cls.port = cls.http.server_port
        cls.thread = threading.Thread(target=cls.http.serve_forever, daemon=True)
        cls.thread.start()

    @classmethod
    def tearDownClass(cls):
        cls.http.shutdown()
        cls.http.server_close()
        cls.thread.join(timeout=2)
        cls.directory.cleanup()

    def call(self, path, method="GET", body=None, headers=None):
        data = None if body is None else json.dumps(body).encode()
        request = urllib.request.Request(
            f"http://127.0.0.1:{self.port}{path}",
            method=method,
            data=data,
            headers=headers or {},
        )
        try:
            with urllib.request.urlopen(request, timeout=2) as response:
                return response.status, json.load(response)
        except urllib.error.HTTPError as error:
            return error.code, json.load(error)

    def test_health_and_stats(self):
        status, result = self.call("/healthz")
        self.assertEqual(status, 200)
        self.assertEqual(result["status"], "healthy")
        status, result = self.call("/stats")
        self.assertEqual(status, 200)
        self.assertIn("payment_attempts", result)

    def test_probe_fail_first(self):
        request_id = str(uuid.uuid4())
        headers = {"X-Request-ID": request_id, "X-Lab-Payment-Fail-First": "2"}
        self.assertEqual(self.call("/payment/probe", headers=headers)[0], 503)
        self.assertEqual(self.call("/payment/probe", headers=headers)[0], 503)
        self.assertEqual(self.call("/payment/probe", headers=headers)[0], 200)
        self.assertEqual(server.STATE.snapshot(request_id)["probe_attempts_for_request"], 3)

    def test_idempotency_same_key_same_payload(self):
        key = str(uuid.uuid4())
        body = {"order_id": str(uuid.uuid4()), "amount_cents": 300, "currency": "USD"}
        headers = {"Idempotency-Key": key}
        status, first = self.call("/payment", "POST", body, headers)
        self.assertEqual(status, 201)
        status, second = self.call("/payment", "POST", body, headers)
        self.assertEqual(status, 200)
        self.assertEqual(first["payment_id"], second["payment_id"])
        self.assertTrue(second["replayed"])

    def test_idempotency_conflicting_payload(self):
        key = str(uuid.uuid4())
        body = {"order_id": str(uuid.uuid4()), "amount_cents": 300, "currency": "USD"}
        self.assertEqual(self.call("/payment", "POST", body, {"Idempotency-Key": key})[0], 201)
        changed = {**body, "amount_cents": 400}
        self.assertEqual(self.call("/payment", "POST", changed, {"Idempotency-Key": key})[0], 409)

    def test_concurrent_idempotency(self):
        key = str(uuid.uuid4())
        body = {"order_id": str(uuid.uuid4()), "amount_cents": 400, "currency": "USD"}
        results = []
        lock = threading.Lock()

        def attempt():
            result = self.call("/payment", "POST", body, {"Idempotency-Key": key})
            with lock:
                results.append(result)

        threads = [threading.Thread(target=attempt) for _ in range(8)]
        for thread in threads:
            thread.start()
        for thread in threads:
            thread.join(timeout=3)
        self.assertEqual(len(results), 8)
        self.assertEqual(len({response["payment_id"] for _, response in results}), 1)
        self.assertEqual(sum(status == 201 for status, _ in results), 1)

    def test_invalid_payment(self):
        self.assertEqual(self.call("/payment", "POST", {"order_id": "123", "amount_cents": -1, "currency": "USD"})[0], 400)

    def test_percentiles(self):
        self.assertEqual(percentile([10, 20, 30, 40, 50], 0.5), 30)
        self.assertEqual(percentile([10], 0.99), 10)


if __name__ == "__main__":
    unittest.main()
