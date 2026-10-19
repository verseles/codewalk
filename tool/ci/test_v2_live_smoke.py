import base64
import hashlib
import io
import json
import sys
import tarfile
import urllib.error
import urllib.request
from pathlib import Path
from typing import cast
from unittest import mock
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from tool.ci import live_smoke_v2_opencode as smoke


def _member(name, *, isfile=True, issym=False):
    m = tarfile.TarInfo(name)
    m.type = tarfile.REGTYPE if isfile else tarfile.SYMTYPE
    if issym:
        m.type = tarfile.SYMTYPE
    return m


class TarFilterTests(unittest.TestCase):
    def test_accepts_only_package_binary(self):
        self.assertTrue(smoke._is_safe_binary_member(_member("package/bin/opencode")))

    def test_rejects_absolute_traversal_symlink_and_other_files(self):
        self.assertFalse(smoke._is_safe_binary_member(_member("/abs")))
        self.assertFalse(smoke._is_safe_binary_member(_member("package/../../evil")))
        self.assertFalse(smoke._is_safe_binary_member(_member("package/bin/opencode", issym=True)))
        self.assertFalse(smoke._is_safe_binary_member(_member("package/bin/other")))
        d = tarfile.TarInfo("package/bin/opencode")
        d.type = tarfile.DIRTYPE
        self.assertFalse(smoke._is_safe_binary_member(d))


class IntegrityTests(unittest.TestCase):
    def test_sha512_sri_roundtrip(self):
        data = b"cw060b-integrity-fixture"
        expected = "sha512-" + base64.b64encode(hashlib.sha512(data).digest()).decode()
        self.assertEqual(smoke._sha512_sri(data), expected)

    def test_acquire_rejects_tampered_integrity(self):
        meta = {
            "versions": {
                "2.0.22": {
                    "dist": {
                        "tarball": "https://example.invalid/cli-linux-arm64-2.0.22.tgz",
                        "integrity": "sha512-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=",
                        "shasum": "0" * 40,
                    }
                }
            }
        }
        with mock.patch.object(
            smoke, "_http_get_json", return_value=meta
        ), mock.patch.object(
            urllib.request, "urlopen"
        ) as urlopen:
            fake = mock.Mock()
            fake.read.side_effect = [b"tampered-bytes", b""]
            urlopen.return_value.__enter__.return_value = fake
            import tempfile

            with tempfile.TemporaryDirectory() as tmp:
                with self.assertRaises(SystemExit):
                    smoke.acquire(Path(tmp))


class ConfigInvariantTests(unittest.TestCase):
    def test_deny_all_but_stub_cost_zero_no_always(self):
        cfg = smoke._build_server_config(18080)
        policies = cfg["experimental"]["policies"]
        self.assertIn(
            {"action": "provider.use", "resource": "*", "effect": "deny"}, policies
        )
        self.assertIn(
            {"action": "provider.use", "resource": "cw060b", "effect": "allow"},
            policies,
        )
        self.assertEqual(
            cfg["providers"]["cw060b"]["models"]["stub"]["cost"],
            {"input": 0, "output": 0},
        )
        self.assertNotIn("always", json.dumps(cfg))
        self.assertTrue(
            cfg["providers"]["cw060b"]["settings"]["baseURL"].startswith(
                "http://127.0.0.1:18080/"
            )
        )


class StubScenarioTests(unittest.TestCase):
    def setUp(self):
        self.stub = smoke.StubProvider()
        self.stub.start()
        self.addCleanup(self.stub.stop)
        self.base = f"http://127.0.0.1:{self.stub.port}"

    def _post(self, marker, tools=None):
        body = json.dumps(
            {
                "model": "cw060b/stub",
                "messages": [{"role": "user", "content": marker}],
                "tools": tools or [],
                "stream": True,
            }
        ).encode()
        req = urllib.request.Request(
            self.base + "/v1/chat/completions",
            data=body,
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        with urllib.request.urlopen(req, timeout=15) as resp:
            return resp.status, resp.read().decode()

    def test_send_scenario_streams_marker_text(self):
        status, text = self._post("hello CW060B_SCENARIO_SEND")
        self.assertEqual(status, 200)
        self.assertIn("CW060B_STUB_SEND_OK", text)
        self.assertEqual(self.stub.ledger[-1]["marker"], "hello CW060B_SCENARIO_SEND")

    def test_approval_scenario_first_request_emits_tool_call(self):
        status, text = self._post(
            "go CW060B_SCENARIO_APPROVAL",
            tools=[{"type": "function", "function": {"name": "read"}}],
        )
        self.assertEqual(status, 200)
        self.assertIn("tool_calls", text)
        self.assertIn("approval-marker.txt", text)
        self.assertEqual(self.stub.ledger[-1]["tools"], ["read"])

    def test_most_recent_marker_wins_over_history(self):
        body = json.dumps(
            {
                "model": "cw060b/stub",
                "messages": [
                    {"role": "user", "content": "old CW060B_SCENARIO_SEND"},
                    {"role": "assistant", "content": "CW060B_STUB_SEND_OK"},
                    {"role": "user", "content": "now CW060B_SCENARIO_APPROVAL"},
                ],
                "tools": [{"type": "function", "function": {"name": "read"}}],
                "stream": True,
            }
        ).encode()
        req = urllib.request.Request(
            self.base + "/v1/chat/completions",
            data=body,
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        with urllib.request.urlopen(req, timeout=15) as resp:
            text = resp.read().decode()
        self.assertIn("tool_calls", text)
        self.assertTrue(
            self.stub.ledger[-1]["marker"].endswith("CW060B_SCENARIO_APPROVAL")
        )

    def test_unknown_path_is_404(self):
        req = urllib.request.Request(
            self.base + "/v1/models",
            data=b"{}",
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        with self.assertRaises(urllib.error.HTTPError) as ctx:
            urllib.request.urlopen(req, timeout=15)
        self.assertEqual(ctx.exception.code, 404)

    def test_request_cap_exceeded(self):
        for _ in range(smoke.MAX_STUB_REQUESTS + 2):
            try:
                self._post("CW060B_SCENARIO_SEND")
            except urllib.error.HTTPError as e:
                if e.code == 429:
                    return
                raise
        self.fail("stub request cap never tripped")


class RedactionTests(unittest.TestCase):
    def test_password_value_redacted_field_names_kept(self):
        out = cast(
            dict,
            smoke._sanitize(
                {"status": "ok", "password": "s3cr3t", "nested": {"token": "abc"}},
                "s3cr3t",
            ),
        )
        self.assertEqual(out["password"], "[REDACTED]")
        self.assertEqual(out["nested"]["token"], "[REDACTED]")
        self.assertEqual(out["status"], "ok")
        self.assertNotIn("s3cr3t", json.dumps(out))


class EgressClassifierTests(unittest.TestCase):
    def test_loopback_estab_is_clean(self):
        sample = (
            "ESTAB 0 0 127.0.0.1:51234 127.0.0.1:8080 users:((\"opencode\",pid=123,fd=9))\n"
        )
        with mock.patch.object(
            smoke.subprocess, "run",
            return_value=mock.Mock(stdout=sample),
        ):
            self.assertIsNone(smoke._egress_violation(123))

    def test_non_loopback_estab_is_violation(self):
        sample = (
            "ESTAB 0 0 127.0.0.1:51234 93.184.216.34:443 users:((\"opencode\",pid=123,fd=9))\n"
        )
        with mock.patch.object(
            smoke.subprocess, "run",
            return_value=mock.Mock(stdout=sample),
        ):
            violation = smoke._egress_violation(123)
            self.assertIsNotNone(violation)
            self.assertIn("93.184.216.34", violation or "")


if __name__ == "__main__":
    unittest.main()
