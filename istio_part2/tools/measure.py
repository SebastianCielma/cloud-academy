import argparse
import csv
import json
import math
import statistics
import time
import urllib.error
import urllib.request
import uuid
from collections import Counter
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path


def extract_version(payload):
    if not isinstance(payload, dict):
        return "unknown"
    if payload.get("service") == "payment-service" and payload.get("version") in {"v1", "v2"}:
        return payload["version"]
    for key in ("order", "payment"):
        if key in payload:
            value = extract_version(payload[key])
            if value != "unknown":
                return value
    return "unknown"


def percentile(values, percentage):
    if not values:
        return 0.0
    ordered = sorted(values)
    return ordered[max(0, math.ceil(percentage / 100 * len(ordered)) - 1)]


def parse_headers(entries):
    headers = {}
    for entry in entries:
        name, separator, value = entry.partition(":")
        if not separator or not name.strip() or not value.strip():
            raise ValueError(f"Invalid header: {entry}")
        headers[name.strip()] = value.strip()
    return headers


def fetch_one(index, url, headers, timeout):
    started = time.perf_counter()
    request_id = str(uuid.uuid4())
    request = urllib.request.Request(url, headers={**headers, "X-Request-ID": request_id}, method="GET")
    status = 0
    payload = {}
    error_message = ""
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            status = response.status
            payload = json.load(response)
    except urllib.error.HTTPError as error:
        status = error.code
        try:
            payload = json.load(error)
        except (ValueError, OSError):
            error_message = "invalid_error_response"
    except (urllib.error.URLError, TimeoutError, OSError, ValueError) as error:
        error_message = type(error).__name__
    elapsed = round((time.perf_counter() - started) * 1000, 3)
    return {
        "index": index,
        "request_id": request_id,
        "status": status,
        "version": extract_version(payload),
        "latency_ms": elapsed,
        "error": error_message,
    }


def measure(url, requests, workers, timeout, headers):
    started = time.perf_counter()
    records = []
    with ThreadPoolExecutor(max_workers=workers) as executor:
        futures = [executor.submit(fetch_one, i, url, headers, timeout) for i in range(1, requests + 1)]
        for future in as_completed(futures):
            records.append(future.result())
    records.sort(key=lambda record: record["index"])
    elapsed = time.perf_counter() - started
    versions = Counter(record["version"] for record in records)
    statuses = Counter(str(record["status"]) for record in records)
    errors = sum(record["status"] < 200 or record["status"] >= 400 for record in records)
    latencies = [record["latency_ms"] for record in records]
    return records, {
        "requests": requests,
        "duration_seconds": round(elapsed, 3),
        "throughput_rps": round(requests / elapsed, 3) if elapsed else 0,
        "error_count": errors,
        "error_rate": round(errors / requests, 5),
        "versions": dict(versions),
        "statuses": dict(statuses),
        "v1_percent": round(100 * versions["v1"] / requests, 3),
        "v2_percent": round(100 * versions["v2"] / requests, 3),
        "mean_latency_ms": round(statistics.fmean(latencies), 3),
        "p50_latency_ms": round(percentile(latencies, 50), 3),
        "p95_latency_ms": round(percentile(latencies, 95), 3),
        "p99_latency_ms": round(percentile(latencies, 99), 3),
        "max_latency_ms": max(latencies),
    }


def validate(summary, expected_v2=None, expected_version=None, min_errors=None, max_errors=None):
    findings = []
    total = summary["requests"]
    versions = summary["versions"]
    unknown = versions.get("unknown", 0)
    if unknown:
        findings.append(f"Unclassified payment responses: {unknown}")
    if expected_v2 is not None:
        probability = expected_v2 / 100
        observed = versions.get("v2", 0)
        expected = total * probability
        sigma = math.sqrt(total * probability * (1 - probability))
        tolerance = max(3, 4 * sigma)
        if abs(observed - expected) > tolerance:
            findings.append(f"v2 count {observed} is outside the four-sigma limit for {expected_v2}%")
        summary["expected_v2_percent"] = expected_v2
        summary["expected_v2_count"] = round(expected, 2)
        summary["v2_four_sigma_tolerance_count"] = round(tolerance, 2)
    if expected_version is not None and versions.get(expected_version, 0) != total:
        findings.append(f"Expected all requests to reach {expected_version}")
    if min_errors is not None and summary["error_rate"] < min_errors:
        findings.append(f"Error rate {summary['error_rate']} below {min_errors}")
    if max_errors is not None and summary["error_rate"] > max_errors:
        findings.append(f"Error rate {summary['error_rate']} above {max_errors}")
    summary["assertions_passed"] = not findings
    summary["assertion_failures"] = findings
    return not findings


def save_report(prefix, records, summary):
    destination = Path(prefix)
    destination.parent.mkdir(parents=True, exist_ok=True)
    (destination.parent / f"{destination.name}.json").write_text(
        json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    with (destination.parent / f"{destination.name}.csv").open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=["index", "request_id", "status", "version", "latency_ms", "error"])
        writer.writeheader()
        writer.writerows(records)
    lines = [
        f"Scenario: {summary['scenario']}",
        f"Requests: {summary['requests']}",
        f"Duration: {summary['duration_seconds']} s",
        f"Throughput: {summary['throughput_rps']} requests/s",
        f"Mean latency: {summary['mean_latency_ms']} ms",
        f"p50 latency: {summary['p50_latency_ms']} ms",
        f"p95 latency: {summary['p95_latency_ms']} ms",
        f"p99 latency: {summary['p99_latency_ms']} ms",
        f"Errors: {summary['error_count']} ({summary['error_rate'] * 100:.2f}%)",
        f"Version v1: {summary['versions'].get('v1', 0)} ({summary['v1_percent']:.2f}%)",
        f"Version v2: {summary['versions'].get('v2', 0)} ({summary['v2_percent']:.2f}%)",
        f"Unknown versions: {summary['versions'].get('unknown', 0)}",
        f"HTTP statuses: {json.dumps(summary['statuses'], sort_keys=True)}",
        f"Assertions: {'PASS' if summary['assertions_passed'] else 'FAIL'}",
    ]
    lines.extend(f"Failure: {failure}" for failure in summary["assertion_failures"])
    report = "\n".join(lines) + "\n"
    (destination.parent / f"{destination.name}.log").write_text(report, encoding="utf-8")
    print(report, end="")


def main(argv=None):
    parser = argparse.ArgumentParser()
    parser.add_argument("--url", default="http://127.0.0.1:18080/order")
    parser.add_argument("--scenario", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--requests", type=int, default=1000)
    parser.add_argument("--workers", type=int, default=10)
    parser.add_argument("--timeout", type=float, default=12)
    parser.add_argument("--header", action="append", default=[])
    parser.add_argument("--expected-v2", type=int)
    parser.add_argument("--expect-version", choices=["v1", "v2"])
    parser.add_argument("--min-error-rate", type=float)
    parser.add_argument("--max-error-rate", type=float)
    args = parser.parse_args(argv)
    if args.requests < 1 or args.workers < 1 or args.timeout <= 0:
        parser.error("Requests, workers and timeout must be positive")
    if args.expected_v2 is not None and not 0 <= args.expected_v2 <= 100:
        parser.error("Expected v2 percentage must be between 0 and 100")
    headers = parse_headers(args.header)
    records, summary = measure(args.url, args.requests, args.workers, args.timeout, headers)
    summary.update({"scenario": args.scenario, "headers": headers, "workers": args.workers})
    passed = validate(summary, args.expected_v2, args.expect_version, args.min_error_rate, args.max_error_rate)
    save_report(args.out, records, summary)
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
