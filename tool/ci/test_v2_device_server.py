import http.client
import io
import json
import os
import signal
import sys
import tempfile
import threading
import time
import unittest
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from types import SimpleNamespace
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from tool.ci import live_smoke_v2_opencode as smoke
from tool.ci import v2_device_server as device


class _Upstream(BaseHTTPRequestHandler):
    """A stand-in server: one JSON read and one event stream that ends."""

    protocol_version = "HTTP/1.1"

    def log_message(self, *args):
        return

    def do_GET(self):  # noqa: N802
        if self.path == "/api/empty":
            self.send_response(204)
            self.end_headers()
            return
        if self.path == "/api/event?cut":
            # A chunked stream whose server dies mid-stream.
            self.send_response(200)
            self.send_header("Content-Type", "text/event-stream")
            self.send_header("Transfer-Encoding", "chunked")
            self.end_headers()
            self.wfile.write(b"9\r\ndata: 0\n\n\r\n")
            self.wfile.flush()
            self.close_connection = True
            return
        if self.path == "/api/event":
            self.send_response(200)
            self.send_header("Content-Type", "text/event-stream")
            self.end_headers()
            self.close_connection = True
            for n in range(2):
                self.wfile.write(f"data: {n}\n\n".encode())
                self.wfile.flush()
            return
        body = json.dumps({"auth": self.headers.get("Authorization")}).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


def _serve(handler):
    server = ThreadingHTTPServer(("127.0.0.1", 0), handler)
    server.daemon_threads = True
    threading.Thread(target=server.serve_forever, daemon=True).start()
    return server


class RouteTests(unittest.TestCase):
    def test_native_ids_are_templated_and_queries_dropped(self):
        self.assertEqual(
            device.route("/api/session/ses_abc123/message?order=asc&dir=/home/x"),
            "/api/session/{id}/message",
        )
        self.assertEqual(device.route("/api/event"), "/api/event")
        self.assertEqual(device.session_of("/api/session/ses_abc123/prompt"), "ses_abc123")
        self.assertIsNone(device.session_of("/api/session/active"))
        self.assertIsNone(device.session_of("/api/info"))


class PinTests(unittest.TestCase):
    def test_arm64_reuses_the_accepted_launcher_pins(self):
        pin = device.PINS["aarch64"]
        self.assertEqual(pin["tarball_sha256"], smoke.PINNED_TARBALL_SHA256)
        self.assertEqual(pin["binary_sha256"], smoke.PINNED_BINARY_SHA256)

    def test_x64_pins_a_registry_integrity(self):
        pin = device.PINS["x86_64"]
        self.assertTrue(pin["integrity"].startswith("sha512-"))
        self.assertEqual(len(pin["tarball_sha256"]), 64)
        self.assertEqual(len(pin["binary_sha256"]), 64)

    def test_a_changed_registry_integrity_refuses_to_download(self):
        meta = {
            "name": "@opencode/cli-linux-x64",
            "version": "2.0.22",
            "dist": {"tarball": "https://example.invalid/x.tgz", "integrity": "sha512-other"},
        }
        response = mock.MagicMock()
        response.__enter__.return_value.read.return_value = json.dumps(meta).encode()
        with tempfile.TemporaryDirectory() as root, mock.patch.object(
            device.platform, "machine", return_value="x86_64"
        ), mock.patch.object(device.urllib.request, "urlopen", return_value=response) as urlopen:
            with self.assertRaises(SystemExit):
                device.acquire(Path(root))
            self.assertEqual(urlopen.call_count, 1, "the tarball is never fetched")


class StubTests(unittest.TestCase):
    def test_answers_at_once_and_refuses_other_paths(self):
        stub = device.Stub()
        self.addCleanup(stub.stop)
        connection = http.client.HTTPConnection("127.0.0.1", stub.port, timeout=10)
        payload = {"messages": [{"role": "user", "content": "hello"}]}
        connection.request("POST", "/v1/chat/completions", body=json.dumps(payload))
        response = connection.getresponse()
        body = response.read().decode()
        self.assertEqual(response.status, 200)
        self.assertIn('"content": "CW-OK"', body)
        self.assertIn('"cost": 0', body)
        self.assertTrue(body.endswith("data: [DONE]\n\n"))
        connection = http.client.HTTPConnection("127.0.0.1", stub.port, timeout=10)
        connection.request("POST", "/elsewhere", body="{}")
        self.assertEqual(connection.getresponse().status, 404)

    def test_the_rich_marker_streams_the_whole_sample(self):
        stub = device.Stub()
        self.addCleanup(stub.stop)
        connection = http.client.HTTPConnection("127.0.0.1", stub.port, timeout=10)
        payload = {"messages": [{"role": "user", "content": [{"type": "text", "text": "CW-RICH"}]}]}
        connection.request("POST", "/v1/chat/completions", body=json.dumps(payload))
        body = connection.getresponse().read().decode()
        chunks = [json.loads(line[6:]) for line in body.split("\n\n")
                  if line.startswith("data: {")]
        text = "".join(c["choices"][0]["delta"]["content"] for c in chunks)
        self.assertEqual(text, device.RICH_SAMPLE)
        self.assertEqual(chunks[-1]["choices"][0]["finish_reason"], "stop")
        self.assertEqual(chunks[-1]["usage"]["cost"], 0)
        for block in ("```mermaid", "```dart", "$$", "| Name | Value |", "\\int_0^1"):
            self.assertIn(block, text)
        # One line per chunk, so a client renders it while it streams.
        lines = [c["choices"][0]["delta"]["content"] for c in chunks]
        self.assertEqual(len(lines), len(device.RICH_SAMPLE.splitlines()))
        self.assertTrue(all(line.endswith("\n") for line in lines))

    def test_the_slow_marker_wins_over_the_rich_one(self):
        stub = device.Stub()
        self.addCleanup(stub.stop)
        connection = http.client.HTTPConnection("127.0.0.1", stub.port, timeout=10)
        payload = {"messages": [{"role": "user", "content": "CW-SLOW1 CW-RICH"}]}
        connection.request("POST", "/v1/chat/completions", body=json.dumps(payload))
        body = connection.getresponse().read().decode()
        self.assertIn('"content": "tick 1 "', body)
        self.assertNotIn("Heading", body)


class RelayTests(unittest.TestCase):
    def setUp(self):
        self.root = Path(tempfile.mkdtemp())
        self.upstream = _serve(_Upstream)
        self.addCleanup(self.upstream.server_close)
        self.addCleanup(self.upstream.shutdown)
        self.owner = SimpleNamespace(
            log=device.Log(self.root / "requests.jsonl"),
            upstream_port=self.upstream.server_address[1],
        )
        self.relay = _serve(device.RelayHandler)
        self.relay.device = self.owner
        self.addCleanup(self.relay.server_close)
        self.addCleanup(self.relay.shutdown)

    def _get(self, path):
        connection = http.client.HTTPConnection("127.0.0.1", self.relay.server_address[1], timeout=10)
        try:
            connection.request("GET", path, headers={"Authorization": "Basic c2VjcmV0LXZhbHVl"})
            response = connection.getresponse()
            return response.status, response.read().decode()
        finally:
            connection.close()

    def _records(self, count):
        # The relay logs after the answer has left, so the client can read
        # the whole body before the record is written.
        deadline = time.monotonic() + 5
        while True:
            path = self.root / "requests.jsonl"
            log = path.read_text() if path.is_file() else ""
            if len(log.splitlines()) >= count or time.monotonic() > deadline:
                return log
            time.sleep(0.02)

    def test_forwards_reads_and_streams_and_records_only_metadata(self):
        status, body = self._get("/api/session/ses_abc123/message?order=asc")
        self.assertEqual(status, 200)
        self.assertEqual(json.loads(body)["auth"], "Basic c2VjcmV0LXZhbHVl")
        status, body = self._get("/api/event")
        self.assertEqual((status, body), (200, "data: 0\n\ndata: 1\n\n"))
        log = self._records(3)
        self.assertNotIn("c2VjcmV0", log)
        self.assertNotIn("127.0.0.1", log)
        records = [json.loads(line) for line in log.splitlines()]
        self.assertEqual(
            [(r["kind"], r["route"]) for r in records],
            [
                ("request", "/api/session/{id}/message"),
                ("stream-open", "/api/event"),
                ("stream-close", "/api/event"),
            ],
        )
        self.assertEqual({r["client"] for r in records}, {"client-1"})
        self.assertEqual(records[2]["reason"], "upstream-end")

    def test_a_stream_cut_by_the_server_is_recorded_as_broken(self):
        # The client sees the cut too: the relay never ends it cleanly.
        with self.assertRaises(http.client.IncompleteRead) as cut:
            self._get("/api/event?cut")
        self.assertEqual(cut.exception.partial, b"data: 0\n\n")
        records = [json.loads(line) for line in self._records(2).splitlines()]
        self.assertEqual(
            [(r["kind"], r.get("reason")) for r in records],
            [("stream-open", None), ("stream-close", "upstream-broken")],
        )

    def test_a_bodiless_answer_is_not_a_stream(self):
        status, body = self._get("/api/empty")
        self.assertEqual((status, body), (204, ""))
        record = json.loads(self._records(1).splitlines()[-1])
        self.assertEqual((record["kind"], record["status"]), ("request", 204))

    def test_an_open_relay_authenticates_any_client(self):
        self.owner.open_relay = True
        self.owner.password = "pw"
        connection = http.client.HTTPConnection("127.0.0.1", self.relay.server_address[1], timeout=10)
        try:
            connection.request("GET", "/api/session/ses_abc123/message")
            body = json.loads(connection.getresponse().read())
        finally:
            connection.close()
        self.assertEqual(body["auth"], "Basic b3BlbmNvZGU6cHc=")
        # Whatever password a client sends, the server gets the real one.
        status, body = self._get("/api/session/ses_abc123/message")
        self.assertEqual(json.loads(body)["auth"], "Basic b3BlbmNvZGU6cHc=")

    def test_a_stopped_server_answers_502(self):
        self.upstream.shutdown()
        self.upstream.server_close()
        status, _ = self._get("/api/info")
        self.assertEqual(status, 502)


class ReadBodyTests(unittest.TestCase):
    def _handler(self, headers, raw):
        return SimpleNamespace(headers=headers, rfile=io.BytesIO(raw))

    def test_chunked_and_sized_bodies_are_read_whole(self):
        chunked = self._handler(
            {"Transfer-Encoding": "chunked"},
            b'4\r\n{"a"\r\n3;ext=1\r\n:1}\r\n0\r\n\r\n',
        )
        self.assertEqual(device.read_body(chunked), b'{"a":1}')
        sized = self._handler({"Content-Length": "7"}, b'{"a":1}rest')
        self.assertEqual(device.read_body(sized), b'{"a":1}')
        self.assertIsNone(device.read_body(self._handler({}, b"")))


class DeviceServerTests(unittest.TestCase):
    def setUp(self):
        self.server = device.DeviceServer(Path(tempfile.mkdtemp()), "127.0.0.1", 0)

    def test_the_report_counts_extra_copies_and_never_the_prompt(self):
        self.server.log.write(
            kind="request", session="ses_a1", method="POST", route="/api/session/{id}/prompt"
        )
        history = {
            "data": [
                {"type": "user", "text": "CW-7 private words"},
                {"type": "user", "text": "CW-7 private words"},
                {"type": "user", "text": "CW-8"},
                {"type": "assistant", "text": "CW-OK"},
            ]
        }

        def api(method, path, body=None):
            if path == "/api/session/active":
                return 200, json.dumps({"data": {"ses_a1": {"type": "running"}}})
            return 200, json.dumps(history)

        with mock.patch.object(self.server, "api", side_effect=api):
            report = self.server.report()
        self.assertEqual(
            report["sessions"]["ses_a1"],
            {"user_prompts": 3, "duplicates": 1, "prompt_posts": 1, "active": True},
        )
        self.assertNotIn("private words", json.dumps(report))

        def unreadable(method, path, body=None):
            if path == "/api/session/active":
                return 500, ""
            return 200, json.dumps(history)

        with mock.patch.object(self.server, "api", side_effect=unreadable):
            report = self.server.report()
        self.assertIsNone(report["active_sessions"])
        self.assertIsNone(report["sessions"]["ses_a1"]["active"])

    def test_a_permission_opens_on_the_session_a_client_prompted_last(self):
        for session in ("ses_a1", "ses_b2"):
            self.server.log.write(
                kind="request", session=session, method="POST", route="/api/session/{id}/prompt"
            )
        calls = []

        def api(method, path, body=None):
            calls.append((method, path, body))
            return 200, json.dumps({"data": {"id": "per_1", "effect": "ask"}})

        with mock.patch.object(self.server, "api", side_effect=api):
            record = self.server.command("permission")
        self.assertEqual(record, {"session": "ses_b2", "permission": "per_1", "effect": "ask"})
        method, path, body = calls[0]
        self.assertEqual((method, path), ("POST", "/api/session/ses_b2/permission"))
        self.assertEqual(body["action"], "read")
        self.assertEqual(body["resources"], body["save"])
        with mock.patch.object(self.server, "api", side_effect=api):
            self.assertEqual(
                self.server.command("permission", {"session": "ses_a1"})["session"], "ses_a1"
            )

    def test_a_permission_needs_a_session(self):
        self.assertIn("error", self.server.command("permission"))
        self.server.log.write(
            kind="request", session="ses_a1", method="POST", route="/api/session/{id}/prompt"
        )
        # A malformed explicit session never falls back to another one.
        with mock.patch.object(self.server, "api") as api:
            self.assertIn("error", self.server.command("permission", {"session": "../x"}))
            self.assertIn("error", self.server.command("permissions", {"session": None}))
        api.assert_not_called()
        with mock.patch.object(self.server, "api", return_value=(200, "not json")):
            self.assertIn("error", self.server.command("permission", {"session": "ses_a1"}))
            self.assertIn("error", self.server.command("permissions", {"session": "ses_a1"}))

    def test_permissions_reports_pending_and_saved(self):
        def api(method, path, body=None):
            if path == "/api/permission/saved":
                return 200, json.dumps({"data": []})
            return 200, json.dumps({"data": [{"id": "per_1"}]})

        for status in (204, 400):
            self.server.log.write(kind="request", session="ses_a1", method="POST",
                                  route="/api/session/{id}/permission/{id}/reply", status=status)
        with mock.patch.object(self.server, "api", side_effect=api):
            state = self.server.command("permissions", {"session": "ses_a1"})
        self.assertEqual(
            state, {"session": "ses_a1", "pending": ["per_1"], "saved": 0, "client_replies": 1}
        )
        with mock.patch.object(self.server, "api", return_value=(500, "")):
            self.assertIn("error", self.server.command("permissions", {"session": "ses_a1"}))

    def test_only_a_created_session_asks_for_read(self):
        self.assertEqual(device.server_config(1)["permissions"],
                         [{"action": "*", "resource": "*", "effect": "deny"}])
        self.server.project = Path("/tmp/project")
        with mock.patch.object(self.server, "api",
                               return_value=(200, json.dumps({"data": {"id": "ses_c3"}}))) as api:
            self.assertEqual(self.server.command("create")["session"], "ses_c3")
        self.assertEqual(api.call_args.args[2]["permissions"],
                         [{"action": "read", "resource": "*", "effect": "ask"}])

    def test_a_closed_server_never_starts_again(self):
        self.server.close()
        self.assertEqual(self.server.restart(), {"error": "the server is closed"})
        with mock.patch.object(self.server, "_start") as start, self.assertRaises(SystemExit):
            self.server.start()
        start.assert_not_called()


class ServeTests(unittest.TestCase):
    def test_a_sigterm_while_booting_still_cleans_up(self):
        previous = signal.getsignal(signal.SIGTERM)
        self.addCleanup(signal.signal, signal.SIGTERM, previous)
        root = Path(tempfile.mkdtemp())
        args = SimpleNamespace(
            root=str(root), bind="127.0.0.1", port=0, control_port=None,
            console=False, adb_serial=None, app_package="com.verseles.codewalk",
            open=False,
        )

        def booting(_self):
            (root / "password").write_text("left over\n")
            os.kill(os.getpid(), signal.SIGTERM)
            time.sleep(1)

        with mock.patch.object(device.DeviceServer, "prepare", booting), \
                mock.patch.object(device.DeviceServer, "start") as start, \
                mock.patch.object(device.DeviceServer, "close") as close:
            self.assertEqual(device.serve(args), 130)
        start.assert_not_called()
        close.assert_called_once()
        self.assertFalse((root / "password").exists())


class HostActionTests(unittest.TestCase):
    def setUp(self):
        self.actions = device.HostActions(
            "emulator-5554", "com.verseles.codewalk", device.Log(Path(tempfile.mkdtemp()) / "r.jsonl")
        )

    def test_an_unparsed_transport_is_never_a_change(self):
        changed = device.HostActions.changed
        self.assertTrue(changed("WIFI", "CELLULAR"))
        self.assertFalse(changed("WIFI", "WIFI"))
        self.assertFalse(changed("WIFI", "none"))
        self.assertFalse(changed("network 100: transports not reported", "CELLULAR"))
        self.assertFalse(changed("WIFI", "network 101: transports not reported"))

    def test_bad_seconds_are_refused_without_running(self):
        for seconds in ("ten", None, 0, 301):
            with self.subTest(seconds=seconds):
                self.assertEqual(
                    self.actions.run("drop", {"seconds": seconds}),
                    {"error": "seconds must be 1..300"},
                )

    def test_a_warning_on_stderr_still_applies(self):
        done = SimpleNamespace(returncode=0, stdout="ok\n", stderr="warning: slow\n")
        with mock.patch.object(device.subprocess, "run", return_value=done):
            self.assertEqual(self.actions.shell("svc", "wifi", "enable"), (True, "ok\n"))
        done.returncode = 1
        with mock.patch.object(device.subprocess, "run", return_value=done):
            self.assertEqual(self.actions.shell("svc", "wifi", "enable")[0], False)


class ControlTests(unittest.TestCase):
    def test_a_non_object_body_gets_a_json_error(self):
        control = _serve(device.ControlHandler)
        self.addCleanup(control.server_close)
        self.addCleanup(control.shutdown)
        control.device = mock.Mock()
        control.stopping = threading.Event()
        control.actions = None
        connection = http.client.HTTPConnection("127.0.0.1", control.server_address[1], timeout=10)
        try:
            connection.request("POST", "/quit", body="[1]", headers={"Content-Length": "3"})
            response = connection.getresponse()
            self.assertEqual(response.status, 400)
            self.assertEqual(json.loads(response.read()), {"error": "the body must be a JSON object"})
        finally:
            connection.close()
        self.assertFalse(control.stopping.is_set())
        control.device.command.assert_not_called()


if __name__ == "__main__":
    unittest.main()
