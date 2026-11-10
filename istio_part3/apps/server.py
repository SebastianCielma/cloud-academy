import hashlib
import json
import os
import random
import socket
import sqlite3
import threading
import time
import urllib.error
import urllib.request
import uuid
from collections import OrderedDict
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlsplit

SERVICE_NAME = os.environ.get("SERVICE_NAME", "api-gateway")
PORT = int(os.environ.get("PORT", "8080"))
ORDER_URL = os.environ.get("ORDER_URL", "http://order-service:8080")
PAYMENT_URL = os.environ.get("PAYMENT_URL", "http://payment-service:8080")
INVENTORY_URL = os.environ.get("INVENTORY_URL", "http://inventory-service:8080")
UPSTREAM_TIMEOUT = float(os.environ.get("UPSTREAM_TIMEOUT_SECONDS", "12"))
PAYMENT_DATABASE = os.environ.get("PAYMENT_DATABASE", "/data/payments.db")
PAYMENT_MAX_IN_FLIGHT = int(os.environ.get("PAYMENT_MAX_IN_FLIGHT", "32"))

CONTROL_HEADERS = (
    "X-Request-ID",
    "X-Lab-Payment-Delay-Ms",
    "X-Lab-Payment-Fail-First",
    "X-Lab-Payment-Always-503",
    "X-Lab-Inventory-Fail-Every",
    "X-Lab-App-Retries",
    "X-Lab-Drop-First-Response",
    "Idempotency-Key",
    "traceparent",
)


class State:
    def __init__(self):
        self.lock = threading.RLock()
        self.requests = 0
        self.active = 0
        self.peak_active = 0
        self.completed = 0
        self.rejected = 0
        self.payment_attempts = 0
        self.payments_created = 0
        self.payments_replayed = 0
        self.payment_conflicts = 0
        self.inventory_requests = 0
        self.probe_attempts = OrderedDict()
        self.probes_received = 0
        self.dropped_responses = set()

    def enter(self):
        with self.lock:
            self.requests += 1
            self.active += 1
            self.peak_active = max(self.peak_active, self.active)
            return self.requests

    def leave(self):
        with self.lock:
            self.active -= 1
            self.completed += 1

    def probe(self, request_id):
        with self.lock:
            self.probes_received += 1
            count = self.probe_attempts.get(request_id, 0) + 1
            self.probe_attempts[request_id] = count
            self.probe_attempts.move_to_end(request_id)
            while len(self.probe_attempts) > 2000:
                self.probe_attempts.popitem(last=False)
            return count

    def drop_first(self, request_id):
        with self.lock:
            if request_id in self.dropped_responses:
                return False
            self.dropped_responses.add(request_id)
            return True

    def snapshot(self, request_id=None):
        with self.lock:
            result = {
                "service": SERVICE_NAME,
                "requests_received": self.requests,
                "requests_completed": self.completed,
                "active_requests": self.active,
                "peak_active_requests": self.peak_active,
                "overload_rejections": self.rejected,
                "payment_attempts": self.payment_attempts,
                "payments_created": self.payments_created,
                "payments_replayed": self.payments_replayed,
                "payment_conflicts": self.payment_conflicts,
                "inventory_requests": self.inventory_requests,
                "probe_requests_received": self.probes_received,
            }
            if request_id is not None:
                result["probe_attempts_for_request"] = self.probe_attempts.get(request_id, 0)
            return result


STATE = State()


def database():
    os.makedirs(os.path.dirname(PAYMENT_DATABASE), exist_ok=True)
    connection = sqlite3.connect(PAYMENT_DATABASE, timeout=15, isolation_level=None)
    connection.execute("PRAGMA busy_timeout=15000")
    connection.execute(
        "CREATE TABLE IF NOT EXISTS payments ("
        "idempotency_key TEXT PRIMARY KEY, "
        "payload_hash TEXT NOT NULL, "
        "payment_id TEXT NOT NULL, "
        "created_at TEXT NOT NULL)"
    )
    return connection


def create_payment(key, payload):
    fingerprint = hashlib.sha256(
        json.dumps(payload, sort_keys=True, separators=(",", ":")).encode()
    ).hexdigest()
    connection = database()
    try:
        connection.execute("BEGIN IMMEDIATE")
        existing = connection.execute(
            "SELECT payload_hash, payment_id FROM payments WHERE idempotency_key = ?",
            (key,),
        ).fetchone()
        if existing is not None:
            connection.execute("COMMIT")
            if existing[0] != fingerprint:
                with STATE.lock:
                    STATE.payment_conflicts += 1
                return 409, {"error": "idempotency_key_conflict"}
            with STATE.lock:
                STATE.payments_replayed += 1
            return 200, {"payment_id": existing[1], "replayed": True, "payment_status": "approved"}
        payment_id = str(uuid.uuid4())
        connection.execute(
            "INSERT INTO payments VALUES (?, ?, ?, datetime('now'))",
            (key, fingerprint, payment_id),
        )
        connection.execute("COMMIT")
        with STATE.lock:
            STATE.payments_created += 1
        return 201, {"payment_id": payment_id, "replayed": False, "payment_status": "approved"}
    except BaseException:
        if connection.in_transaction:
            connection.execute("ROLLBACK")
        raise
    finally:
        connection.close()


def forwarded_headers(source):
    headers = {name: source[name] for name in CONTROL_HEADERS if name in source}
    headers.setdefault("X-Request-ID", str(uuid.uuid4()))
    return headers


def call_service(url, method="GET", payload=None, headers=None, retries=0):
    encoded = None if payload is None else json.dumps(payload, separators=(",", ":")).encode()
    outbound_headers = dict(headers or {})
    if encoded is not None:
        outbound_headers["Content-Type"] = "application/json"
    for attempt in range(retries + 1):
        request = urllib.request.Request(
            url, data=encoded, headers=outbound_headers, method=method
        )
        try:
            with urllib.request.urlopen(request, timeout=UPSTREAM_TIMEOUT) as response:
                return response.status, json.load(response)
        except urllib.error.HTTPError as error:
            status = error.code
            try:
                body = json.load(error)
            except (ValueError, OSError):
                body = {"error": "invalid_downstream_response"}
            if status not in (502, 503, 504) or attempt == retries:
                return status, body
        except (urllib.error.URLError, TimeoutError, ConnectionError, OSError, ValueError) as error:
            if attempt == retries:
                return 502, {"error": "downstream_unavailable", "detail": type(error).__name__}
        time.sleep(min(0.05 * (2 ** attempt), 0.5) + random.uniform(0, 0.02))
    return 502, {"error": "downstream_unavailable"}


def retry_count(headers):
    try:
        return max(0, min(3, int(headers.get("X-Lab-App-Retries", "0"))))
    except ValueError:
        return 0


def lab_integer(headers, name, maximum=15000):
    try:
        return max(0, min(maximum, int(headers.get(name, "0"))))
    except ValueError:
        return 0


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, format_string, *args):
        print(
            json.dumps(
                {
                    "service": SERVICE_NAME,
                    "event": "http_access",
                    "request_id": self.headers.get("X-Request-ID", ""),
                    "message": format_string % args,
                },
                separators=(",", ":"),
            ),
            flush=True,
        )

    def respond(self, status, body):
        encoded = json.dumps(body, separators=(",", ":")).encode()
        try:
            self.send_response(status)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(encoded)))
            self.end_headers()
            self.wfile.write(encoded)
        except (BrokenPipeError, ConnectionResetError, ConnectionAbortedError):
            print(
                json.dumps(
                    {
                        "service": SERVICE_NAME,
                        "event": "client_disconnected",
                        "request_id": self.headers.get("X-Request-ID", ""),
                    }
                ),
                flush=True,
            )

    def handle_request(self):
        STATE.enter()
        started = time.monotonic()
        request_id = self.headers.get("X-Request-ID") or str(uuid.uuid4())
        path = urlsplit(self.path).path
        try:
            if path in ("/healthz", "/readyz"):
                return self.respond(200, {"service": SERVICE_NAME, "status": "healthy"})
            if path == "/stats":
                if SERVICE_NAME not in ("payment-service", "inventory-service", "order-service", "api-gateway"):
                    return self.respond(404, {"error": "not_found"})
                return self.respond(200, STATE.snapshot(request_id))
            if self.command == "GET":
                return self.handle_get(path, request_id)
            if self.command == "POST":
                return self.handle_post(path, request_id)
            return self.respond(405, {"error": "method_not_allowed"})
        except (ValueError, json.JSONDecodeError):
            return self.respond(400, {"error": "invalid_request"})
        except Exception as error:
            print(
                json.dumps(
                    {"service": SERVICE_NAME, "event": "handler_error", "error": type(error).__name__}
                ),
                flush=True,
            )
            return self.respond(500, {"error": "internal_error"})
        finally:
            STATE.leave()
            print(
                json.dumps(
                    {
                        "service": SERVICE_NAME,
                        "event": "request_complete",
                        "path": path,
                        "request_id": request_id,
                        "duration_ms": round((time.monotonic() - started) * 1000, 2),
                    },
                    separators=(",", ":"),
                ),
                flush=True,
            )

    def handle_get(self, path, request_id):
        headers = forwarded_headers(self.headers)
        if SERVICE_NAME == "api-gateway" and path in ("/order", "/order/payment-only"):
            status, order = call_service(f"{ORDER_URL}{path}", headers=headers)
            return self.respond(status, {"service": SERVICE_NAME, "order": order})
        if SERVICE_NAME == "order-service" and path in ("/order", "/order/payment-only"):
            payment_status, payment = call_service(
                f"{PAYMENT_URL}/payment/probe", headers=headers, retries=retry_count(headers)
            )
            if payment_status != 200:
                return self.respond(502, {"service": SERVICE_NAME, "dependency": "payment", "downstream_status": payment_status})
            if path == "/order/payment-only":
                return self.respond(200, {"service": SERVICE_NAME, "payment": payment})
            inventory_status, inventory = call_service(f"{INVENTORY_URL}/inventory", headers=headers)
            if inventory_status != 200:
                return self.respond(502, {"service": SERVICE_NAME, "dependency": "inventory", "downstream_status": inventory_status})
            return self.respond(200, {"service": SERVICE_NAME, "payment": payment, "inventory": inventory})
        if SERVICE_NAME == "payment-service" and path == "/payment/probe":
            attempt = STATE.probe(request_id)
            with STATE.lock:
                if STATE.active > PAYMENT_MAX_IN_FLIGHT:
                    STATE.rejected += 1
                    return self.respond(503, {"error": "payment_overloaded", "attempt": attempt})
            delay = lab_integer(headers, "X-Lab-Payment-Delay-Ms")
            if delay:
                time.sleep(delay / 1000)
            if self.headers.get("X-Lab-Payment-Always-503") == "true":
                return self.respond(503, {"error": "payment_unavailable", "attempt": attempt})
            if attempt <= lab_integer(headers, "X-Lab-Payment-Fail-First", 20):
                return self.respond(503, {"error": "payment_transient_failure", "attempt": attempt})
            return self.respond(200, {"service": SERVICE_NAME, "payment_status": "available", "attempt": attempt})
        if SERVICE_NAME == "inventory-service" and path == "/inventory":
            with STATE.lock:
                STATE.inventory_requests += 1
                inventory_attempt = STATE.inventory_requests
            fail_every = lab_integer(headers, "X-Lab-Inventory-Fail-Every", 100)
            if fail_every and inventory_attempt % fail_every == 0:
                return self.respond(503, {"service": SERVICE_NAME, "error": "inventory_temporarily_unavailable"})
            return self.respond(200, {"service": SERVICE_NAME, "stock_status": "available"})
        return self.respond(404, {"error": "not_found"})

    def handle_post(self, path, request_id):
        if path not in ("/checkout", "/payment"):
            return self.respond(404, {"error": "not_found"})
        content_length = int(self.headers.get("Content-Length", "0"))
        if not (0 < content_length <= 4096):
            return self.respond(400, {"error": "invalid_content_length"})
        body = json.loads(self.rfile.read(content_length).decode())
        if not isinstance(body, dict):
            return self.respond(400, {"error": "invalid_payload"})
        if not isinstance(body.get("order_id"), str) or not body["order_id"]:
            return self.respond(400, {"error": "invalid_order_id"})
        if type(body.get("amount_cents")) is not int or body["amount_cents"] <= 0:
            return self.respond(400, {"error": "invalid_amount"})
        if body.get("currency") != "USD":
            return self.respond(400, {"error": "invalid_currency"})
        if SERVICE_NAME == "api-gateway" and path == "/checkout":
            status, result = call_service(f"{ORDER_URL}/checkout", "POST", body, forwarded_headers(self.headers))
            return self.respond(status, {"service": SERVICE_NAME, "order": result})
        if SERVICE_NAME == "order-service" and path == "/checkout":
            status, result = call_service(
                f"{PAYMENT_URL}/payment", "POST", body, forwarded_headers(self.headers), retry_count(self.headers)
            )
            return self.respond(status, {"service": SERVICE_NAME, "payment": result})
        if SERVICE_NAME == "payment-service" and path == "/payment":
            with STATE.lock:
                STATE.payment_attempts += 1
                if STATE.active > PAYMENT_MAX_IN_FLIGHT:
                    STATE.rejected += 1
                    return self.respond(503, {"error": "payment_overloaded"})
            idempotency_key = self.headers.get("Idempotency-Key") or str(uuid.uuid4())
            if len(idempotency_key) > 256:
                return self.respond(400, {"error": "invalid_idempotency_key"})
            status, payment = create_payment(idempotency_key, body)
            if self.headers.get("X-Lab-Drop-First-Response") == "true" and STATE.drop_first(request_id):
                self.close_connection = True
                try:
                    self.connection.shutdown(socket.SHUT_RDWR)
                except OSError:
                    pass
                self.connection.close()
                return
            return self.respond(status, {"service": SERVICE_NAME, **payment})
        return self.respond(404, {"error": "not_found"})

    def do_GET(self):
        self.handle_request()

    def do_POST(self):
        self.handle_request()


def main():
    if SERVICE_NAME == "payment-service":
        connection = database()
        connection.close()
    server = ThreadingHTTPServer(("0.0.0.0", PORT), Handler)
    server.daemon_threads = True
    print(json.dumps({"service": SERVICE_NAME, "event": "startup", "port": PORT}), flush=True)
    server.serve_forever(poll_interval=0.2)


if __name__ == "__main__":
    main()
