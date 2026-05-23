import http.server
import socketserver
import os

DIR = os.path.dirname(os.path.abspath(__file__))
PORT = 55556

class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DIR, **kwargs)

    def log_message(self, format, *args):
        pass

with socketserver.TCPServer(("", PORT), Handler) as httpd:
    print(f"TODO: http://localhost:{PORT}")
    httpd.serve_forever()
