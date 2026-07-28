"""Static server for the Godot web export, tuned for tunnelling.

Three things a plain `python -m http.server` gets wrong here:

  MIME     .wasm must be application/wasm or the browser refuses to stream-compile
           it, and .pck must not be guessed as text.
  gzip     index.wasm is ~37 MB raw. Over a tunnel that is a minute of staring at
           a blank page; gzipped it is closer to 10 MB. Compressed once, cached
           on disk, reused.
  headers  The export sets ensureCrossOriginIsolationHeaders, so COOP/COEP are
           sent here rather than leaving the page to install a service worker
           and reload itself on first visit.
"""
import gzip
import http.server
import shutil
import subprocess
import os
import socketserver
import sys
from pathlib import Path

ROOT = Path(sys.argv[1]).resolve()
PORT = int(sys.argv[2])
CACHE = Path(sys.argv[3]).resolve()
CACHE.mkdir(parents=True, exist_ok=True)
HAVE_BROTLI = shutil.which("brotli") is not None
if not HAVE_BROTLI:
    print("  (no brotli on PATH — falling back to gzip, ~2 MB heavier)", flush=True)

TYPES = {
    ".wasm": "application/wasm",
    ".pck": "application/octet-stream",
    ".js": "text/javascript",
    ".html": "text/html; charset=utf-8",
    ".png": "image/png",
    ".json": "application/json",
    ".txt": "text/plain; charset=utf-8",
}
# Already-compressed formats gain nothing and cost CPU.
COMPRESS = {".wasm", ".js", ".html", ".json", ".txt", ".pck"}


def _cached(path: Path, suffix: str, build) -> Path:
    """Compress once, keep it on disk, reuse until the source changes."""
    out = CACHE / (path.name + suffix)
    if out.exists() and out.stat().st_mtime >= path.stat().st_mtime:
        return out
    raw = path.read_bytes()
    out.write_bytes(build(raw))
    print(f"  {suffix[1:]} {path.name}: {len(raw)/1048576:.1f} MB -> "
          f"{out.stat().st_size/1048576:.1f} MB", flush=True)
    return out


def gzipped(path: Path) -> Path:
    return _cached(path, ".gz", lambda raw: gzip.compress(raw, 6))


def brotlied(path: Path) -> Path:
    """Brotli, which every browser that can run this build also accepts.

    Worth its own branch: the engine binary is 37.7 MB of wasm and dominates the
    download. gzip takes it to 9.6 MB, brotli to 7.5 — two megabytes off every
    first visit for a header. Quality 9 rather than 11 because 11 spends over a
    minute on this file and buys very little more."""
    return _cached(path, ".br", lambda raw: subprocess.run(
        ["brotli", "-q", "9", "-c"], input=raw, stdout=subprocess.PIPE, check=True).stdout)


class Handler(http.server.BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, fmt, *args):
        print("  %s" % (fmt % args), flush=True)

    def do_GET(self):
        self._respond(body=True)

    def do_HEAD(self):
        self._respond(body=False)

    def _respond(self, body: bool):
        rel = self.path.split("?", 1)[0].lstrip("/") or "index.html"
        target = (ROOT / rel).resolve()
        # Never serve outside the export directory.
        if not str(target).startswith(str(ROOT)) or not target.is_file():
            self.send_error(404)
            return

        ext = target.suffix.lower()
        payload = target
        encoding = None
        accept = self.headers.get("Accept-Encoding", "")
        if ext in COMPRESS:
            if HAVE_BROTLI and "br" in accept:
                payload = brotlied(target)
                encoding = "br"
            elif "gzip" in accept:
                payload = gzipped(target)
                encoding = "gzip"

        self.send_response(200)
        self.send_header("Content-Type", TYPES.get(ext, "application/octet-stream"))
        self.send_header("Content-Length", str(payload.stat().st_size))
        if encoding:
            self.send_header("Content-Encoding", encoding)
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cross-Origin-Resource-Policy", "cross-origin")
        self.send_header("Cache-Control", "no-cache")
        self.end_headers()
        if body:
            with payload.open("rb") as f:
                while chunk := f.read(1 << 20):
                    self.wfile.write(chunk)


class Server(socketserver.ThreadingTCPServer):
    allow_reuse_address = True
    daemon_threads = True


print(f"serving {ROOT} on http://127.0.0.1:{PORT}", flush=True)
# Warm the cache for the big files so the first visitor doesn't wait on gzip.
for name in ("index.wasm", "index.pck", "index.js"):
    p = ROOT / name
    if p.is_file():
        gzipped(p)
print("READY", flush=True)
Server(("127.0.0.1", PORT), Handler).serve_forever()
