import importlib.util
import os
import sys
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]


def load_module():
    spec = importlib.util.spec_from_file_location("istio_part2_server", ROOT / "apps" / "server.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class ServiceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.service = load_module()

    def test_payment_v1_success(self):
        with patch.object(self.service, "SERVICE_NAME", "payment-service"), patch.object(self.service, "APP_VERSION", "v1"):
            code, payload = self.service.handle_get("/payment", {"X-Lab-V2-Regression": "true"})
        self.assertEqual(code, 200)
        self.assertEqual(payload["version"], "v1")
        self.assertEqual(payload["status"], "success")

    def test_payment_v2_success(self):
        with patch.object(self.service, "SERVICE_NAME", "payment-service"), patch.object(self.service, "APP_VERSION", "v2"):
            code, payload = self.service.handle_get("/payment", {})
        self.assertEqual(code, 200)
        self.assertEqual(payload["version"], "v2")

    def test_payment_v2_regression(self):
        with patch.object(self.service, "SERVICE_NAME", "payment-service"), patch.object(self.service, "APP_VERSION", "v2"):
            code, payload = self.service.handle_get("/payment", {"X-Lab-V2-Regression": "true"})
        self.assertEqual(code, 500)
        self.assertEqual(payload["error"], "simulated_regression")

    def test_header_forwarding(self):
        headers = {"X-Release-Channel": "beta", "X-Lab-V2-Regression": "true", "Unrelated": "discard"}
        forwarded = self.service.request_headers(headers)
        self.assertEqual(forwarded["X-Release-Channel"], "beta")
        self.assertEqual(forwarded["X-Lab-V2-Regression"], "true")
        self.assertNotIn("Unrelated", forwarded)
        self.assertTrue(forwarded["X-Request-ID"])

    def test_unknown_path_returns_404(self):
        with patch.object(self.service, "SERVICE_NAME", "payment-service"):
            code, payload = self.service.handle_get("/unavailable", {})
        self.assertEqual(code, 404)
        self.assertEqual(payload["error"], "not_found")

    def test_health_is_version_independent(self):
        with patch.object(self.service, "SERVICE_NAME", "payment-service"):
            for path in ("/healthz", "/readyz"):
                code, payload = self.service.handle_get(path, {})
                self.assertEqual(code, 200)
                self.assertEqual(payload["status"], "healthy")

    def test_gateway_preserves_downstream_http_500(self):
        with patch.object(self.service, "SERVICE_NAME", "api-gateway"), patch.object(self.service, "fetch_json", return_value=(500, {"service": "order-service", "status": "failed"})):
            code, payload = self.service.handle_get("/order", {})
        self.assertEqual(code, 500)
        self.assertEqual(payload["order"]["status"], "failed")

    def test_order_forwards_release_header(self):
        calls = []

        def simulate_fetch(url, headers):
            calls.append((url, headers))
            if url.endswith("/payment"):
                return 200, {"service": "payment-service", "version": "v2"}
            return 200, {"service": "inventory-service", "status": "available"}

        with patch.object(self.service, "SERVICE_NAME", "order-service"), patch.object(self.service, "fetch_json", side_effect=simulate_fetch):
            code, payload = self.service.handle_get("/order", {"X-Release-Channel": "beta"})
        self.assertEqual(code, 200)
        self.assertEqual(payload["payment"]["version"], "v2")
        self.assertEqual(len(calls), 2)
        self.assertEqual(calls[0][1]["X-Release-Channel"], "beta")
