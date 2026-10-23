#!/usr/bin/env python3
"""Local fixture of the GitHub releases API for the v1 major update gate.

Serves the two endpoints the CodeWalk 1 updater reads:

* ``GET /repos/verseles/codewalk/releases/latest`` -> a stable ``v2.0.0``
  release, so the stable channel sees CodeWalk 2 as GitHub's latest.
* ``GET /repos/verseles/codewalk/releases?per_page=N&page=N`` -> a list with
  v2.0.0, v1.266.0, a ``v1.266.0-native.1`` prerelease and a draft, so the
  CodeWalk-1-only selector has real candidates to filter.

Every request is appended to a JSON Lines log (time, method, path, the
``page``/``per_page`` parameters and the status) as manual evidence. Only the
standard library is used.
"""

from __future__ import annotations

import argparse
import json
import signal
import sys
import threading
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlsplit

REPO_PATH = "/repos/verseles/codewalk"
LATEST_PATH = f"{REPO_PATH}/releases/latest"
LIST_PATH = f"{REPO_PATH}/releases"
RELEASE_PAGE = "https://github.com/verseles/codewalk/releases/tag/"
DOWNLOAD_BASE = "https://github.com/verseles/codewalk/releases/download/"
LOGGED_PARAMS = ("page", "per_page")


def _release(tag: str, *, body: str, prerelease: bool = False,
             draft: bool = False, release_id: int = 1) -> dict:
    return {
        "id": release_id,
        "tag_name": tag,
        "name": tag,
        "html_url": RELEASE_PAGE + tag,
        "draft": draft,
        "prerelease": prerelease,
        "published_at": None if draft else "2026-10-20T12:00:00Z",
        "body": body,
        "assets": [
            {
                "name": "codewalk-linux-x64.tar.gz",
                "browser_download_url":
                    f"{DOWNLOAD_BASE}{tag}/codewalk-linux-x64.tar.gz",
            },
            {
                "name": "codewalk-android-arm64.apk",
                "browser_download_url":
                    f"{DOWNLOAD_BASE}{tag}/codewalk-android-arm64.apk",
            },
        ],
    }


def latest_release() -> dict:
    return _release(
        "v2.0.0",
        release_id=2000,
        body=(
            "CodeWalk 2 requires OpenCode 2 servers; OpenCode 1 servers "
            "keep working only in CodeWalk 1.\n\n"
            "Fixture release served by the v1 update gate evidence run."
        ),
    )


def release_list() -> list[dict]:
    return [
        latest_release(),
        _release("v1.266.0-native.1", release_id=1267, prerelease=True,
                 body="Fixture prerelease; never offered by the updater."),
        _release("v1.267.0", release_id=1268, draft=True,
                 body="Fixture draft; never offered by the updater."),
        _release("v1.266.0", release_id=1266,
                 body="Last CodeWalk 1 transition release (fixture)."),
    ]


def route(raw_path: str) -> tuple[int, object]:
    """Returns the status and JSON payload for a request path."""
    parts = urlsplit(raw_path)
    path = parts.path.rstrip("/") or "/"
    if path == LATEST_PATH:
        return 200, latest_release()
    if path == LIST_PATH:
        query = parse_qs(parts.query)
        try:
            page = int(query.get("page", ["1"])[0])
            per_page = int(query.get("per_page", ["30"])[0])
        except ValueError:
            return 400, {"message": "Invalid pagination parameters"}
        if page < 1 or per_page < 1:
            return 400, {"message": "Invalid pagination parameters"}
        releases = release_list()
        start = (page - 1) * per_page
        return 200, releases[start:start + per_page]
    return 404, {
        "message": "Not Found",
        "documentation_url": "https://docs.github.com/rest",
    }


def log_entry(method: str, raw_path: str, status: int) -> dict:
    """Builds a log record that keeps only the path and pagination params."""
    parts = urlsplit(raw_path)
    query = parse_qs(parts.query)
    params = {key: query[key][0] for key in LOGGED_PARAMS if key in query}
    return {
        "time": datetime.now(timezone.utc).isoformat(timespec="milliseconds"),
        "method": method,
        "path": parts.path,
        "params": params,
        "status": status,
    }


class FixtureHandler(BaseHTTPRequestHandler):
    server_version = "CodeWalkUpdateGateFixture/1"
    log_path: str | None = None
    _log_lock = threading.Lock()

    def do_GET(self) -> None:  # noqa: N802 (http.server API)
        status, payload = route(self.path)
        body = json.dumps(payload).encode("utf-8")
        # Logged before answering, so a client that has the body also finds
        # its request in the log.
        self._record(status)
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_HEAD(self) -> None:  # noqa: N802
        status, _ = route(self.path)
        self._record(status)
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.end_headers()

    def _record(self, status: int) -> None:
        line = json.dumps(log_entry(self.command, self.path, status))
        with self._log_lock:
            if self.log_path:
                with open(self.log_path, "a", encoding="utf-8") as handle:
                    handle.write(line + "\n")
            else:
                print(line, flush=True)

    def log_message(self, format: str, *args: object) -> None:  # noqa: A002
        # The JSON log replaces the default stderr access log, which would
        # also echo raw query strings.
        return


def make_server(bind: str, port: int, log_path: str | None) -> ThreadingHTTPServer:
    handler = type("BoundFixtureHandler", (FixtureHandler,),
                   {"log_path": log_path})
    return ThreadingHTTPServer((bind, port), handler)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--port", type=int, default=8765)
    parser.add_argument("--bind", default="127.0.0.1")
    parser.add_argument("--log", default=None, help="JSON Lines request log")
    args = parser.parse_args(argv)

    server = make_server(args.bind, args.port, args.log)

    def stop(signum: int, _frame: object) -> None:
        # shutdown() blocks until serve_forever() returns, so run it off the
        # serving thread.
        threading.Thread(target=server.shutdown, daemon=True).start()

    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)
    host, port = server.server_address[:2]
    print(f"update-gate fixture ready on http://{host}:{port}", flush=True)
    try:
        server.serve_forever()
    finally:
        server.server_close()
    print("update-gate fixture stopped", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
