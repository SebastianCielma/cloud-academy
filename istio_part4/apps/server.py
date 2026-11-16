import json
import os
import threading
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

NAME = os.getenv('SERVICE_NAME', 'api-gateway')
PORT = int(os.getenv('PORT', '8080'))
ORDER = os.getenv('ORDER_URL', 'http://order-service:8080')
PAYMENT = os.getenv('PAYMENT_URL', 'http://payment-service:8080')
INVENTORY = os.getenv('INVENTORY_URL', 'http://inventory-service:8080')
VERSION = os.getenv('APP_VERSION', 'v1')
payments = {}
lock = threading.Lock()


def call(url, method='GET', body=None):
    data = json.dumps(body).encode() if body is not None else None
    request = Request(url, data=data, method=method, headers={'Content-Type': 'application/json'})
    try:
        with urlopen(request, timeout=4) as response:
            return response.status, json.loads(response.read())
    except HTTPError as error:
        try:
            return error.code, json.loads(error.read())
        except (ValueError, UnicodeDecodeError):
            return error.code, {'error': 'upstream_http_error'}
    except (URLError, TimeoutError):
        return 503, {'error': 'upstream_unavailable'}


class Handler(BaseHTTPRequestHandler):
    def respond(self, status, content):
        data = json.dumps(content, separators=(',', ':')).encode()
        self.send_response(status)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        path = self.path.split('?', 1)[0]
        if path in ('/health', '/healthz', '/readyz'):
            return self.respond(200, {'service': NAME, 'status': 'healthy'})
        if NAME == 'inventory-service' and path == '/inventory':
            return self.respond(200, {'service': NAME, 'available': True})
        if NAME == 'payment-service' and path.startswith('/payments/'):
            payment_id = path.rsplit('/', 1)[1]
            with lock:
                payment = payments.get(payment_id)
            return self.respond(200, payment) if payment else self.respond(404, {'error': 'payment_not_found'})
        if NAME == 'payment-service' and path == '/version':
            return self.respond(200, {'service': NAME, 'version': VERSION})
        if NAME == 'api-gateway' and path == '/order':
            status, body = call(ORDER + '/order')
            return self.respond(status, {'service': NAME, 'order': body})
        if NAME == 'order-service' and path == '/order':
            inventory_status, inventory = call(INVENTORY + '/inventory')
            payment_status, payment = call(PAYMENT + '/health')
            if inventory_status != 200 or payment_status != 200:
                return self.respond(502, {'service': NAME, 'inventory_status': inventory_status, 'payment_status': payment_status})
            return self.respond(200, {'service': NAME, 'inventory': inventory, 'payment': payment})
        return self.respond(404, {'error': 'not_found', 'service': NAME})

    def do_POST(self):
        if NAME != 'payment-service' or self.path != '/payments':
            return self.respond(404, {'error': 'not_found'})
        try:
            size = int(self.headers.get('Content-Length', '0'))
            data = json.loads(self.rfile.read(size))
            amount = data['amount']
            if not isinstance(amount, (float, int)) or isinstance(amount, bool) or amount <= 0:
                raise ValueError('amount')
        except (ValueError, KeyError, TypeError, json.JSONDecodeError):
            return self.respond(400, {'error': 'invalid_payment'})
        item = {'payment_id': str(uuid.uuid4()), 'amount': amount, 'status': 'created', 'version': VERSION}
        with lock:
            payments[item['payment_id']] = item
        return self.respond(201, item)

    def log_message(self, fmt, *args):
        print(json.dumps({'service': NAME, 'event': 'http_request', 'message': fmt % args}), flush=True)


if __name__ == '__main__':
    ThreadingHTTPServer(('0.0.0.0', PORT), Handler).serve_forever()
