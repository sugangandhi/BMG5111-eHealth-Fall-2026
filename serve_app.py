import os
import sys
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer

class ReusableServer(ThreadingHTTPServer):
    allow_reuse_address = True

class CustomHandler(SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS, HEAD')
        self.send_header('Access-Control-Allow-Headers', '*')
        self.send_header('Cache-Control', 'no-cache, no-store, must-revalidate')
        super().end_headers()

    def do_OPTIONS(self):
        self.send_response(200)
        self.end_headers()

if __name__ == '__main__':
    web_dir = os.path.abspath(r"flutter_smart_health\src\app\build\web")
    os.chdir(web_dir)
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8000
    server = ReusableServer(('0.0.0.0', port), CustomHandler)
    server.daemon_threads = True
    print(f"Serving {web_dir} on http://0.0.0.0:{port}...", flush=True)
    server.serve_forever()
