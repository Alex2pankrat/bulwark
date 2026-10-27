#!/usr/bin/env python3
"""Serve the exported web build locally.

Godot's single-threaded web export runs on any static host, but it does need correct MIME
types (`.wasm` must be `application/wasm`) and, if you ever enable *Thread Support*, these
two headers:

    Cross-Origin-Opener-Policy: same-origin
    Cross-Origin-Embedder-Policy: require-corp

They are sent unconditionally here so the same command works for both variants.

Usage:
    python3 tools/serve_web.py [--port 8000] [--dir release/web]
"""

from __future__ import annotations

import argparse
import functools
import http.server
import mimetypes
import socketserver

mimetypes.add_type("application/wasm", ".wasm")
mimetypes.add_type("application/octet-stream", ".pck")


class Handler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self) -> None:
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cross-Origin-Resource-Policy", "cross-origin")
        # The engine and its data pack change on every export: never serve them stale.
        if self.path.endswith((".html", ".js", ".pck", ".wasm")):
            self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def log_message(self, fmt: str, *args) -> None:
        print("%s - %s" % (self.address_string(), fmt % args), flush=True)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", type=int, default=8000)
    parser.add_argument("--dir", default="release/web")
    parser.add_argument("--host", default="0.0.0.0")
    args = parser.parse_args()

    handler = functools.partial(Handler, directory=args.dir)
    socketserver.TCPServer.allow_reuse_address = True
    with socketserver.ThreadingTCPServer((args.host, args.port), handler) as httpd:
        print(f"Bulwark web build on http://{args.host}:{args.port} (dir: {args.dir})", flush=True)
        httpd.serve_forever()


if __name__ == "__main__":
    main()
