"""A tiny static server for a Flutter web build, for local testing only.

Usage: python tool/serve.py <folder> <port>

Python's built-in server is enough for a JavaScript build, but a WebAssembly
build needs two things it does not do by default:
  * .mjs files must be served as JavaScript, or the browser refuses the module;
  * the page must be "cross-origin isolated" (two headers, below) for the
    WebAssembly renderer to use several threads.
"""
import http.server
import sys
from functools import partial


class Handler(http.server.SimpleHTTPRequestHandler):
    extensions_map = {
        **http.server.SimpleHTTPRequestHandler.extensions_map,
        ".mjs": "text/javascript",
        ".js": "text/javascript",
        ".wasm": "application/wasm",
    }

    def end_headers(self):
        self.send_header("Cross-Origin-Embedder-Policy", "credentialless")
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        super().end_headers()


if __name__ == "__main__":
    folder, port = sys.argv[1], int(sys.argv[2])
    http.server.ThreadingHTTPServer(("127.0.0.1", port), partial(Handler, directory=folder)).serve_forever()
