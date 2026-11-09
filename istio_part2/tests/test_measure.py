import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
from measure import extract_version, parse_headers, percentile, validate


class MeasurementTests(unittest.TestCase):
    def test_nested_version_success(self):
        payload = {"service": "api-gateway", "order": {"service": "order-service", "payment": {"service": "payment-service", "version": "v2", "status": "success"}}}
        self.assertEqual(extract_version(payload), "v2")

    def test_nested_version_error(self):
        payload = {"service": "api-gateway", "order": {"service": "order-service", "payment": {"service": "payment-service", "version": "v2", "status": "error"}}}
        self.assertEqual(extract_version(payload), "v2")

    def test_unknown_version(self):
        self.assertEqual(extract_version({"service": "api-gateway", "order": {"error": "upstream_unavailable"}}), "unknown")

    def test_nearest_rank_percentile(self):
        self.assertEqual(percentile(list(range(1, 101)), 95), 95)
        self.assertEqual(percentile(list(range(1, 101)), 99), 99)

    def test_header_parser(self):
        self.assertEqual(parse_headers(["X-Release-Channel: beta"]), {"X-Release-Channel": "beta"})
        with self.assertRaises(ValueError):
            parse_headers(["broken-header"])

    def test_weighted_routing_within_statistical_tolerance(self):
        summary = {"requests": 1000, "versions": {"v1": 894, "v2": 106}, "error_rate": 0}
        self.assertTrue(validate(summary, expected_v2=10, max_errors=0))
        self.assertTrue(summary["assertions_passed"])

    def test_weighted_routing_detects_missing_waypoint(self):
        summary = {"requests": 1000, "versions": {"v1": 1000}, "error_rate": 0}
        self.assertFalse(validate(summary, expected_v2=10, max_errors=0))
        self.assertFalse(summary["assertions_passed"])

    def test_header_routing_is_deterministic(self):
        summary = {"requests": 150, "versions": {"v2": 150}, "error_rate": 0}
        self.assertTrue(validate(summary, expected_version="v2", max_errors=0))

    def test_regression_error_range(self):
        summary = {"requests": 1000, "versions": {"v1": 750, "v2": 250}, "error_rate": 0.25}
        self.assertTrue(validate(summary, expected_v2=25, min_errors=0.12, max_errors=0.4))

    def test_rollback_detects_regression(self):
        summary = {"requests": 1000, "versions": {"v1": 1000}, "error_rate": 0.02}
        self.assertFalse(validate(summary, expected_version="v1", max_errors=0))
