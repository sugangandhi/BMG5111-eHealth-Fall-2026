import os
import sys
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler

web_dir = os.path.abspath("flutter_smart_health/src/app/build/web")
if not os.path.exists(web_dir):
    print(f"Error: web dir {web_dir} does not exist!")
    sys.exit(1)

class ThreadedCORSHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=web_dir, **kwargs)

    def end_headers(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', '*')
        self.send_header('Cache-Control', 'no-cache, no-store, must-revalidate')
        super().end_headers()

    def do_OPTIONS(self):
        self.send_response(200)
        self.end_headers()

    def copyfile(self, source, outputfile):
        try:
            super().copyfile(source, outputfile)
        except (ConnectionResetError, BrokenPipeError):
            pass

    def log_message(self, format, *args):
        # Concise logging
        pass

if __name__ == '__main__':
    port = 3000
    server = ThreadingHTTPServer(('0.0.0.0', port), ThreadedCORSHandler)
    print(f"Multi-threaded Web Server listening on http://localhost:{port}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
