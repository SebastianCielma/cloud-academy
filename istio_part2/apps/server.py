import json
import os
import threading
import time
import urllib.error
import urllib.request
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlsplit

SERVICE_NAME = os.environ.get("SERVICE_NAME", "api-gateway")
APP_VERSION = os.environ.get("APP_VERSION", "v1")
PORT = int(os.environ.get("PORT", "8080"))
ORDER_URL = os.environ.get("ORDER_URL", "http://order-service:8080")
PAYMENT_URL = os.environ.get("PAYMENT_URL", "http://payment-service:8080")
INVENTORY_URL = os.environ.get("INVENTORY_URL", "http://inventory-service:8080")
UPSTREAM_TIMEOUT = float(os.environ.get("UPSTREAM_TIMEOUT_SECONDS", "5"))
FORWARDED_HEADERS = ("X-Release-Channel", "X-Lab-V2-Regression", "X-Request-ID")


class Counters:
    def __init__(self):
        self.lock = threading.Lock()
        self.requests = 0
        self.payment_requests = 0
        self.failures = 0

    def record(self, path, status):
        with self.lock:
            self.requests += 1
            if SERVICE_NAME == "payment-service" and path == "/payment":
                self.payment_requests += 1
            if status >= 500:
                self.failures += 1

    def snapshot(self):
        with self.lock:
            return {
                "service": SERVICE_NAME,
                "version": APP_VERSION,
                "requests": self.requests,
                "payment_requests": self.payment_requests,
                "server_errors": self.failures,
            }


COUNTERS = Counters()


def request_headers(headers):
    result = {name: headers[name] for name in FORWARDED_HEADERS if name in headers}
    result.setdefault("X-Request-ID", str(uuid.uuid4()))
    return result


def fetch_json(url, headers):
    request = urllib.request.Request(url, headers=headers, method="GET")
    try:
        with urllib.request.urlopen(request, timeout=UPSTREAM_TIMEOUT) as response:
            return response.status, json.load(response)
    except urllib.error.HTTPError as error:
        try:
            payload = json.load(error)
        except (ValueError, OSError):
            payload = {"error": "invalid_upstream_response"}
        return error.code, payload
    except (urllib.error.URLError, TimeoutError, ConnectionError, OSError, ValueError) as error:
        return 502, {"error": "upstream_unavailable", "reason": type(error).__name__}


def regression_enabled(headers):
    return headers.get("X-Lab-V2-Regression", "").strip().lower() in {"true", "1", "enabled"}


def handle_get(path, headers):
    if path in {"/healthz", "/readyz"}:
        return 200, {"service": SERVICE_NAME, "status": "healthy"}

    if path == "/":
        return 200, {"service": SERVICE_NAME, "version": APP_VERSION, "status": "ready"}

    if path == "/stats":
        return 200, COUNTERS.snapshot()

    upstream_headers = request_headers(headers)

    if SERVICE_NAME == "api-gateway" and path == "/order":
        status, order = fetch_json(f"{ORDER_URL}/order", upstream_headers)
        return status, {"service": SERVICE_NAME, "order": order}

    if SERVICE_NAME == "order-service" and path == "/order":
        payment_status, payment = fetch_json(f"{PAYMENT_URL}/payment", upstream_headers)
        if payment_status != 200:
            return payment_status, {"service": SERVICE_NAME, "payment": payment, "status": "failed"}
        inventory_status, inventory = fetch_json(f"{INVENTORY_URL}/inventory", upstream_headers)
        if inventory_status != 200:
            return inventory_status, {"service": SERVICE_NAME, "payment": payment, "inventory": inventory, "status": "failed"}
        return 200, {"service": SERVICE_NAME, "payment": payment, "inventory": inventory, "status": "success"}

    if SERVICE_NAME == "payment-service" and path == "/payment":
        if APP_VERSION == "v2" and regression_enabled(headers):
            return 500, {"service": SERVICE_NAME, "version": APP_VERSION, "status": "error", "error": "simulated_regression"}
        return 200, {"service": SERVICE_NAME, "version": APP_VERSION, "status": "success"}

    if SERVICE_NAME == "inventory-service" and path == "/inventory":
        return 200, {"service": SERVICE_NAME, "status": "available"}

    return 404, {"error": "not_found"}


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, format_string, *args):
        pass

    def do_GET(self):
        started = time.monotonic()
        path = urlsplit(self.path).path
        request_id = self.headers.get("X-Request-ID") or str(uuid.uuid4())
        try:
            status, payload = handle_get(path, self.headers)
        except Exception as error:
            status, payload = 500, {"error": "internal_server_error"}
            print(json.dumps({"event": "handler_exception", "service": SERVICE_NAME, "reason": type(error).__name__}), flush=True)
        COUNTERS.record(path, status)
        data = json.dumps(payload, separators=(",", ":")).encode("utf-8")
        try:
            self.send_response(status)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(data)))
            self.send_header("Cache-Control", "no-store")
            self.send_header("X-Request-ID", request_id)
            self.end_headers()
            self.wfile.write(data)
        except (BrokenPipeError, ConnectionResetError, ConnectionAbortedError):
            pass
        print(json.dumps({
            "event": "request_completed",
            "service": SERVICE_NAME,
            "version": APP_VERSION,
            "path": path,
            "status": status,
            "request_id": request_id,
            "duration_ms": round((time.monotonic() - started) * 1000, 2),
        }, separators=(",", ":")), flush=True)


class Server(ThreadingHTTPServer):
    daemon_threads = True


if __name__ == "__main__":
    print(json.dumps({"event": "service_started", "service": SERVICE_NAME, "version": APP_VERSION, "port": PORT}), flush=True)
    Server(("0.0.0.0", PORT), Handler).serve_forever()
