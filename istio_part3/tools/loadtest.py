import argparse
import concurrent.futures
import csv
import json
import statistics
import time
import urllib.error
import urllib.request
import uuid
from collections import Counter
from pathlib import Path


def percentile(values, fraction):
    if not values:
        return None
    ordered = sorted(values)
    rank = fraction * (len(ordered) - 1)
    lower = int(rank)
    upper = min(lower + 1, len(ordered) - 1)
    return round(ordered[lower] + (ordered[upper] - ordered[lower]) * (rank - lower), 3)


def request_once(index, url, method, headers, timeout, body):
    outbound = dict(headers)
    outbound.setdefault("X-Request-ID", str(uuid.uuid4()))
    data = None if method == "GET" else json.dumps(body).encode()
    if data is not None:
        outbound["Content-Type"] = "application/json"
    request = urllib.request.Request(url, data=data, headers=outbound, method=method)
    started = time.perf_counter()
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            code = response.status
            payload = response.read(8192)
            error = ""
    except urllib.error.HTTPError as response:
        code = response.code
        payload = response.read(8192)
        error = ""
    except (urllib.error.URLError, TimeoutError, ConnectionError, OSError) as failure:
        code = 0
        payload = b""
        error = type(failure).__name__
    latency_ms = (time.perf_counter() - started) * 1000
    return {
        "index": index,
        "status": code,
        "success": 200 <= code < 300,
        "latency_ms": round(latency_ms, 3),
        "error": error,
        "response": payload.decode("utf-8", errors="replace")[:500],
    }


def run(url, requests=100, concurrency=5, method="GET", headers=None, timeout=15.0, body=None):
    start = time.perf_counter()
    with concurrent.futures.ThreadPoolExecutor(max_workers=concurrency) as executor:
        futures = [
            executor.submit(request_once, i, url, method, headers or {}, timeout, body)
            for i in range(requests)
        ]
        results = sorted((future.result() for future in concurrent.futures.as_completed(futures)), key=lambda x: x["index"])
    elapsed = time.perf_counter() - start
    latencies = [result["latency_ms"] for result in results]
    successful = sum(result["success"] for result in results)
    summary = {
        "url": url,
        "method": method,
        "requests": requests,
        "concurrency": concurrency,
        "success_count": successful,
        "failure_count": requests - successful,
        "error_rate_percent": round((requests - successful) / requests * 100, 3),
        "elapsed_seconds": round(elapsed, 3),
        "throughput_rps": round(requests / elapsed, 3) if elapsed else None,
        "average_latency_ms": round(statistics.mean(latencies), 3),
        "p50_latency_ms": percentile(latencies, 0.50),
        "p95_latency_ms": percentile(latencies, 0.95),
        "p99_latency_ms": percentile(latencies, 0.99),
        "max_latency_ms": round(max(latencies), 3),
        "http_status_counts": dict(sorted(Counter(str(result["status"]) for result in results).items())),
        "sample_failures": [result for result in results if not result["success"]][:3],
    }
    return summary, results


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--url", required=True)
    parser.add_argument("--requests", type=int, default=100)
    parser.add_argument("--concurrency", type=int, default=5)
    parser.add_argument("--method", choices=("GET", "POST"), default="GET")
    parser.add_argument("--timeout", type=float, default=15)
    parser.add_argument("--header", action="append", default=[])
    parser.add_argument("--body", default='{"order_id":"load-test","amount_cents":100,"currency":"USD"}')
    parser.add_argument("--output")
    parser.add_argument("--csv")
    arguments = parser.parse_args()
    if arguments.requests < 1 or arguments.concurrency < 1:
        parser.error("requests and concurrency must be positive")
    headers = {}
    for header in arguments.header:
        if ":" not in header:
            parser.error("headers must use Name:Value format")
        key, value = header.split(":", 1)
        headers[key.strip()] = value.strip()
    summary, samples = run(
        arguments.url,
        arguments.requests,
        arguments.concurrency,
        arguments.method,
        headers,
        arguments.timeout,
        json.loads(arguments.body),
    )
    print(json.dumps(summary, indent=2))
    if arguments.output:
        Path(arguments.output).parent.mkdir(parents=True, exist_ok=True)
        Path(arguments.output).write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    if arguments.csv:
        Path(arguments.csv).parent.mkdir(parents=True, exist_ok=True)
        with open(arguments.csv, "w", newline="", encoding="utf-8") as destination:
            writer = csv.DictWriter(destination, fieldnames=samples[0].keys())
            writer.writeheader()
            writer.writerows(samples)


if __name__ == "__main__":
    main()
