import http.server, socketserver, sys, os

port = int(sys.argv[1])

class CORSRequestHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('X-Frame-Options', 'ALLOWALL')
        self.send_header('Content-Security-Policy', 'frame-ancestors *')
        super().end_headers()

os.chdir('/home/user/flutter_app/build/web')
with socketserver.TCPServer(('0.0.0.0', port), CORSRequestHandler) as httpd:
    httpd.serve_forever()
