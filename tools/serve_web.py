#!/usr/bin/env python3
"""Serve the exported web build locally.

Godot's single-threaded web export runs on any static host, but it does need correct MIME
types (`.wasm` must be `application/wasm`) and, if you ever enable *Thread Support*, these
two headers:

    Cross-Origin-Opener-Policy: same-origin
    Cross-Origin-Embedder-Policy: require-corp

They are sent unconditionally here so the same command works for both variants.

If a pre-compressed sibling exists (`index.wasm.gz`, `index.pck.gz`, …) it is served with
`Content-Encoding: gzip` to clients that accept it. `tools/build.sh` writes those files so a
40 MB wasm ships as ~10 MB over the wire — which is also why the repository can keep the
playable web build inside the release folder.

Usage:
    python3 tools/serve_web.py [--port 8000] [--dir release/web]
"""

from __future__ import annotations

import argparse
import email.utils
import functools
import http.server
import mimetypes
import os
import shutil
import socketserver

mimetypes.add_type("application/wasm", ".wasm")
mimetypes.add_type("application/octet-stream", ".pck")

GZ_TYPES = (".html", ".js", ".pck", ".wasm", ".json", ".svg", ".css")


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

    def _gzip_variant(self, path: str) -> str | None:
        """Return the `.gz` sibling for `path` if it exists and the client accepts gzip."""
        if not path.endswith(GZ_TYPES):
            return None
        if "gzip" not in (self.headers.get("Accept-Encoding") or ""):
            return None
        candidate = path + ".gz"
        return candidate if os.path.isfile(candidate) else None

    def send_head(self):
        path = self.translate_path(self.path)
        gz = self._gzip_variant(path)
        if gz is None:
            return super().send_head()

        content_type = self.guess_type(path) or "application/octet-stream"
        try:
            f = open(gz, "rb")
        except OSError:
            return super().send_head()

        stat = os.fstat(f.fileno())
        self.send_response(200)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Encoding", "gzip")
        self.send_header("Content-Length", str(stat.st_size))
        self.send_header("Last-Modified", email.utils.formatdate(stat.st_mtime, usegmt=True))
        self.send_header("Vary", "Accept-Encoding")
        self.end_headers()
        return f


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", type=int, default=8000)
    parser.add_argument("--dir", default="release/web")
    parser.add_argument("--host", default="0.0.0.0")
    parser.add_argument(
        "--gzip",
        action="store_true",
        help="write .gz siblings for compressible files before serving",
    )
    parser.add_argument(
        "--compress-only",
        action="store_true",
        help="only write the .gz siblings (used by tools/build.sh), then exit",
    )
    args = parser.parse_args()

    if args.gzip or args.compress_only:
        for name in os.listdir(args.dir):
            src = os.path.join(args.dir, name)
            if os.path.isfile(src) and name.endswith(GZ_TYPES):
                # shutil.copyfileobj through gzip keeps this dependency-free and streaming.
                import gzip

                with open(src, "rb") as fh, gzip.open(src + ".gz", "wb", compresslevel=9) as out:
                    shutil.copyfileobj(fh, out, 1 << 20)
                print(f"compressed {name}")
        if args.compress_only:
            return

    handler = functools.partial(Handler, directory=args.dir)
    socketserver.TCPServer.allow_reuse_address = True
    with socketserver.ThreadingTCPServer((args.host, args.port), handler) as httpd:
        print(f"Bulwark web build on http://{args.host}:{args.port} (dir: {args.dir})", flush=True)
        httpd.serve_forever()


if __name__ == "__main__":
    main()
