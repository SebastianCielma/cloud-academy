#!/usr/bin/env python3
import os
from http.server import BaseHTTPRequestHandler, HTTPServer

BROKEN = os.getenv("BROKEN_V2", "false").lower() == "true"

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/health":
            if BROKEN:
                self.send_response(500)
                self.end_headers()
                self.wfile.write(b'{"status":"DOWN","version":"v2"}')
            else:
                self.send_response(200)
                self.end_headers()
                self.wfile.write(b'{"status":"UP","version":"v2"}')
        else:
            self.send_response(404)
            self.end_headers()

    def log_message(self, format, *args):
        return

if __name__ == "__main__":
    server = HTTPServer(("0.0.0.0", 8080), Handler)
    print("Payment API v2 listening on port 8080")
    server.serve_forever()
