import json
import os
import sys
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

SERVICE = os.getenv("SERVICE_NAME", "unknown")
PORT = int(os.getenv("PORT", "8080"))

ORDER_URL = os.getenv("ORDER_URL", "http://order-service:8080")
PAYMENT_URL = os.getenv("PAYMENT_URL", "http://payment-service:8080")
INVENTORY_URL = os.getenv("INVENTORY_URL", "http://inventory-service:8080")


def fetch_json(url):
    with urllib.request.urlopen(url, timeout=5) as response:
        return json.load(response)


class Handler(BaseHTTPRequestHandler):
    def respond(self, status, payload):
        body = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format_string, *args):
        print(
            f"HTTP service={SERVICE} client={self.client_address[0]} "
            f"message={format_string % args}",
            flush=True,
        )

    def do_GET(self):
        print(f"REQUEST service={SERVICE} path={self.path}", flush=True)

        if self.path == "/health":
            return self.respond(200, {
                "service": SERVICE,
                "status": "healthy",
            })

        if self.path == "/":
            return self.respond(200, {
                "service": SERVICE,
                "status": "ready",
            })

        try:
            if SERVICE == "api-gateway" and self.path == "/order":
                order = fetch_json(f"{ORDER_URL}/order")
                return self.respond(200, {
                    "service": SERVICE,
                    "order": order,
                })

            if SERVICE == "order-service" and self.path == "/order":
                payment = fetch_json(f"{PAYMENT_URL}/payment")
                inventory = fetch_json(f"{INVENTORY_URL}/inventory")
                return self.respond(200, {
                    "service": SERVICE,
                    "payment": payment,
                    "inventory": inventory,
                })

            if SERVICE == "payment-service" and self.path == "/payment":
                return self.respond(200, {
                    "service": SERVICE,
                    "payment_status": "approved",
                })

            if SERVICE == "inventory-service" and self.path == "/inventory":
                return self.respond(200, {
                    "service": SERVICE,
                    "stock_status": "available",
                })

            return self.respond(404, {"error": "not_found"})

        except (urllib.error.URLError, TimeoutError, ValueError) as error:
            print(f"DOWNSTREAM_ERROR service={SERVICE} error={error}", flush=True)
            return self.respond(502, {
                "service": SERVICE,
                "error": "downstream_unavailable",
            })


if __name__ == "__main__":
    print(f"START service={SERVICE} port={PORT}", flush=True)
    try:
        ThreadingHTTPServer(("0.0.0.0", PORT), Handler).serve_forever()
    except KeyboardInterrupt:
        sys.exit(0)
