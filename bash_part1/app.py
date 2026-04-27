#!/usr/bin/env python3
import os
from http.server import BaseHTTPRequestHandler, HTTPServer

PORT = int(os.getenv("APP_PORT", "8080"))
BROKEN_HEALTH = os.getenv("BROKEN_HEALTH", "false").lower() == "true"

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/health":
            if BROKEN_HEALTH:
                self.send_response(500)
                self.end_headers()
                self.wfile.write(b'{"status":"DOWN"}')
            else:
                self.send_response(200)
                self.end_headers()
                self.wfile.write(b'{"status":"UP"}')
        else:
            self.send_response(404)
            self.end_headers()

    def log_message(self, format, *args):
        return

if __name__ == "__main__":
    server = HTTPServer(("0.0.0.0", PORT), Handler)
    print(f"Fake Payment API listening on port {PORT}")
    server.serve_forever()
