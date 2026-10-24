import base64
import hashlib
import io
import json
import sys
import tarfile
import tempfile
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


def _registry_metadata(integrity: str) -> dict:
    """The shape the registry actually returns: dist at the top level."""
    return {
        "name": "@opencode/cli-linux-arm64",
        "version": "2.0.22",
        "dist": {
            "tarball": "https://example.invalid/cli-linux-arm64-2.0.22.tgz",
            "integrity": integrity,
            "shasum": "0" * 40,
        },
    }


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
        """The registry shape must reach the integrity comparison itself."""
        meta = _registry_metadata("sha512-" + "A" * 43 + "=")
        with mock.patch.object(
            smoke, "_http_get_json", return_value=meta
        ), mock.patch.object(
            urllib.request, "urlopen"
        ) as urlopen:
            fake = mock.Mock()
            fake.read.side_effect = [b"tampered-bytes", b""]
            urlopen.return_value.__enter__.return_value = fake
            with tempfile.TemporaryDirectory() as tmp:
                with self.assertRaises(smoke.Fatal) as ctx:
                    smoke.acquire(Path(tmp))
            self.assertIn("SHA-512 integrity mismatch", ctx.exception.message)

    def test_acquire_blocks_when_the_pinned_digest_differs(self):
        meta = _registry_metadata(smoke._sha512_sri(b"tampered-bytes"))
        with mock.patch.object(
            smoke, "_http_get_json", return_value=meta
        ), mock.patch.object(
            urllib.request, "urlopen"
        ) as urlopen:
            fake = mock.Mock()
            fake.read.side_effect = [b"tampered-bytes", b""]
            urlopen.return_value.__enter__.return_value = fake
            with tempfile.TemporaryDirectory() as tmp:
                with self.assertRaises(smoke.Fatal) as ctx:
                    smoke.acquire(Path(tmp))
            self.assertTrue(ctx.exception.blocked)
            self.assertIn("blocked:provenance", ctx.exception.message)

    def test_verify_binary_refuses_a_tampered_binary(self):
        with tempfile.TemporaryDirectory() as tmp:
            fake = Path(tmp) / "opencode"
            fake.write_bytes(b"not the pinned 2.0.22 binary")
            with self.assertRaises(smoke.Fatal) as ctx:
                smoke._verify_binary(fake)
            self.assertTrue(ctx.exception.blocked)

    def test_verify_binary_refuses_a_missing_binary(self):
        with tempfile.TemporaryDirectory() as tmp:
            with self.assertRaises(smoke.Fatal) as ctx:
                smoke._verify_binary(Path(tmp) / "absent")
            self.assertTrue(ctx.exception.blocked)


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
        self.assertEqual(
            cfg["providers"]["cw060b"]["models"]["stub-alt"]["cost"],
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

    def test_error_scenario_returns_401_invalid_api_key(self):
        with self.assertRaises(urllib.error.HTTPError) as ctx:
            self._post("trigger CW060B_SCENARIO_ERROR")
        self.assertEqual(ctx.exception.code, 401)
        body = json.loads(ctx.exception.read().decode())
        self.assertEqual(body["error"]["type"], "invalid_request_error")
        self.assertEqual(body["error"]["code"], "invalid_api_key")
        self.assertIn("simulated provider auth failure", body["error"]["message"])
        self.assertEqual(self.stub.ledger[-1]["marker"], "trigger CW060B_SCENARIO_ERROR")

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

    def test_stop_releases_the_listening_socket(self):
        """The isolation proof is only true when the stub port is gone."""
        port = self.stub.port
        self.assertIn(port, smoke._listening_ports())
        self.stub.stop()
        self.assertNotIn(port, smoke._listening_ports())


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


class IsolationTests(unittest.TestCase):
    def test_user_opencode_pids_excludes_the_owned_pid(self):
        def fake_open(path, *args, **kwargs):
            if path.endswith("/cmdline"):
                return io.BytesIO(b"opencode\x00serve\x00--hostname\x00127.0.0.1\x00")
            raise OSError(path)

        with mock.patch.object(
            smoke.os, "listdir", return_value=["4242"]
        ), mock.patch("builtins.open", side_effect=fake_open):
            self.assertEqual(smoke._user_opencode_pids(), [4242])
            self.assertEqual(smoke._user_opencode_pids({4242}), [])

    def test_only_an_opencode_serve_argv_counts_as_a_server(self):
        self.assertTrue(
            smoke._is_opencode_server(
                ["/home/ubuntu/.opencode/bin/opencode", "serve", "--port=4096"]
            )
        )
        # A shell or an agent that merely mentions the words is not a server.
        self.assertFalse(
            smoke._is_opencode_server(
                ["/usr/bin/zsh", "-c", "grep opencode serve /tmp/log"]
            )
        )
        self.assertFalse(
            smoke._is_opencode_server(
                ["node", "/home/ubuntu/.cache/opencode/pyright-langserver", "--stdio"]
            )
        )
        self.assertFalse(smoke._is_opencode_server(["/usr/bin/opencode"]))

    def test_processes_in_group_finds_the_current_process(self):
        import os as _os

        pgid = _os.getpgid(_os.getpid())
        self.assertIn(_os.getpid(), smoke._processes_in_group(pgid))
        # A group nobody belongs to is empty.
        self.assertEqual(smoke._processes_in_group(999999), [])

    def test_child_env_drops_the_proxy_variables(self):
        env = smoke._child_env(
            {
                "http_proxy": "http://proxy.invalid:3128",
                "ALL_PROXY": "socks5://proxy.invalid:1080",
                "HTTPS_PROXY": "http://proxy.invalid:3128",
                "PATH": "/usr/bin",
            }
        )
        for name in ("http_proxy", "ALL_PROXY", "HTTPS_PROXY"):
            self.assertNotIn(name, env)
        self.assertEqual(env["NO_PROXY"], "127.0.0.1,localhost")
        self.assertEqual(env["no_proxy"], "127.0.0.1,localhost")

    def test_child_env_drops_the_credential_variables(self):
        env = smoke._child_env(
            {
                "OPENCODE_CONFIG": "/home/ubuntu/.config/opencode/opencode.json",
                "OPENCODE_SERVER_PASSWORD": "s3cr3t",
                "ANTHROPIC_API_KEY": "sk-ant-000000000000",
                "GITHUB_TOKEN": "ghp_0000000000000000",
                "CODEWALK_LIVE_SMOKE_PASSWORD": "disposable",
                "HOME": "/home/ubuntu",
                "PATH": "/usr/bin",
            }
        )
        for name in (
            "OPENCODE_CONFIG",
            "OPENCODE_SERVER_PASSWORD",
            "ANTHROPIC_API_KEY",
            "GITHUB_TOKEN",
        ):
            self.assertNotIn(name, env)
        # The disposable password the launcher owns stays: the suite needs it.
        self.assertEqual(env["CODEWALK_LIVE_SMOKE_PASSWORD"], "disposable")
        self.assertEqual(env["HOME"], "/home/ubuntu")

    def test_cleanup_ok_requires_every_invariant(self):
        good = {
            "server_exited": True,
            "temp_root_removed": True,
            "owned_ports_released": True,
            "owned_process_group_survivors": [],
            "user_opencode_service_alive": True,
        }
        self.assertTrue(smoke._cleanup_ok(good))
        for key in (
            "server_exited",
            "temp_root_removed",
            "owned_ports_released",
            "user_opencode_service_alive",
        ):
            broken = dict(good)
            broken[key] = False
            self.assertFalse(smoke._cleanup_ok(broken))
        broken = dict(good)
        broken["owned_process_group_survivors"] = [4242]
        self.assertFalse(smoke._cleanup_ok(broken))

    def test_blocked_and_failed_are_distinguishable(self):
        self.assertEqual(smoke._failure_status(smoke.Fatal("x", blocked=True)), "blocked")
        self.assertEqual(smoke._failure_status(smoke.Fatal("x")), "failed")


class EgressClassifierTests(unittest.TestCase):
    def test_loopback_estab_is_clean(self):
        sample = (
            "ESTAB 0 0 127.0.0.1:51234 127.0.0.1:8080 users:((\"opencode\",pid=123,fd=9))\n"
        )
        with mock.patch.object(
            smoke.subprocess, "run",
            return_value=mock.Mock(stdout=sample, returncode=0),
        ):
            violation, observed = smoke._egress_audit(123)
            self.assertIsNone(violation)
            self.assertEqual(observed, 1)

    def test_non_loopback_estab_is_violation(self):
        sample = (
            "ESTAB 0 0 127.0.0.1:51234 93.184.216.34:443 users:((\"opencode\",pid=123,fd=9))\n"
        )
        with mock.patch.object(
            smoke.subprocess, "run",
            return_value=mock.Mock(stdout=sample, returncode=0),
        ):
            violation, _ = smoke._egress_audit(123)
            self.assertIsNotNone(violation)
            self.assertIn("93.184.216.34", violation or "")

    def test_the_pid_match_is_exact(self):
        sample = (
            "ESTAB 0 0 127.0.0.1:51234 93.184.216.34:443 users:((\"opencode\",pid=1234,fd=9))\n"
        )
        with mock.patch.object(
            smoke.subprocess, "run",
            return_value=mock.Mock(stdout=sample, returncode=0),
        ):
            violation, observed = smoke._egress_audit(123)
            self.assertIsNone(violation)
            self.assertEqual(observed, 0)

    def test_the_audit_fails_closed_when_ss_is_unavailable(self):
        with mock.patch.object(
            smoke.subprocess, "run", side_effect=FileNotFoundError
        ):
            violation, observed = smoke._egress_audit(123)
            self.assertIsNotNone(violation)
            self.assertIn("audit unavailable", violation or "")
            self.assertEqual(observed, 0)


class FixtureTests(unittest.TestCase):
    def test_a_capability_without_its_marker_is_missing(self):
        events = [
            'CODEWALK_LIVE_QA {"phase": "pairing", "status": "passed"}',
            'CODEWALK_LIVE_QA {"phase": "native-cost", "status": "passed", "cost": 0}',
        ]
        states = smoke._capability_states(events)
        self.assertEqual(states["pairing"], "passed")
        self.assertEqual(states["send"], "missing")
        self.assertEqual(states["stopIdle"], "missing")

    def test_a_missing_cost_marker_is_not_a_measured_zero(self):
        self.assertIsNone(smoke._native_cost([]))
        self.assertIsNone(
            smoke._native_cost(['CODEWALK_LIVE_QA {"phase": "pairing", "status": "passed"}'])
        )
        self.assertEqual(
            smoke._native_cost(
                ['CODEWALK_LIVE_QA {"phase": "native-cost", "status": "passed", "cost": 0}']
            ),
            0,
        )

    def test_the_secret_scan_catches_a_credential_shape(self):
        with self.assertRaises(smoke.Fatal):
            smoke._assert_no_secret(
                'Authorization: Basic b3BlbmNvZGU6c2VjcmV0cGFzcw==', None, "log"
            )
        with self.assertRaises(smoke.Fatal):
            smoke._assert_no_secret('{"token": "abcdefghijkl"}', None, "log")
        with self.assertRaises(smoke.Fatal):
            smoke._assert_no_secret("the password is s3cr3t", "s3cr3t", "log")
        # Prose that names a credential is not a leak.
        smoke._assert_no_secret(
            "No Authorization header, pairing code or paired token was recorded.",
            None,
            "log",
        )
        smoke._assert_no_secret('{"token": "[REDACTED]"}', None, "log")

    def test_the_capability_map_is_total_and_unique(self):
        self.assertEqual(
            set(smoke.CAPABILITY_PHASES),
            {
                "pairing",
                "send",
                "approval",
                "approval-manual",
                "approval-auto",
                "reconnect-detection",
                "stop-reconnect",
                "stop-idle",
            },
        )
        self.assertEqual(
            len(set(smoke.CAPABILITY_PHASES.values())), len(smoke.CAPABILITY_PHASES)
        )
        self.assertEqual(
            set(smoke.CAPABILITY_PHASES_060C),
            set(smoke.CAPABILITY_PHASES) | {
                "workspace-pairing",
                "workspace",
                "workspace-tab",
                "workspace-send",
                "workspace-steer",
                "workspace-stop",
                "workspace-approval",
                "workspace-form",
                "workspace-model-switch",
                "workspace-error",
            },
        )
        self.assertEqual(
            len(set(smoke.CAPABILITY_PHASES_060C.values())),
            len(smoke.CAPABILITY_PHASES_060C),
        )
        self.assertTrue(
            set(smoke.CAPABILITY_PHASES).issubset(set(smoke.CAPABILITY_PHASES_060C))
        )

    def test_baseline_markers_do_not_prove_the_workspace_flow(self):
        events = [
            'CODEWALK_LIVE_QA ' + json.dumps({"phase": phase, "status": "passed"})
            for phase in smoke.CAPABILITY_PHASES
        ]
        states = smoke._capability_states(events, smoke.CAPABILITY_PHASES_060C)
        self.assertEqual(states["pairing"], "passed")
        self.assertEqual(states["send"], "passed")
        self.assertEqual(states["workspacePairing"], "missing")
        self.assertEqual(states["workspaceSend"], "missing")
        self.assertEqual(states["workspaceApproval"], "missing")

    def test_the_committed_fixture_uses_the_launcher_phase_map(self):
        fixture = (
            smoke.REPO_ROOT
            / "test/contract/fixtures/opencode/2.0.22/live-smoke-060b/capabilities.json"
        )
        self.assertEqual(
            json.loads(fixture.read_text())["phases"], smoke.CAPABILITY_PHASES
        )

    def test_the_fixture_only_claims_the_capabilities_the_run_proved(self):
        evidence = {
            "status": "delivered-awaiting-acceptance",
            "version": "2.0.22",
            "host": "linux-aarch64",
            "zero_spend": True,
            "repo_commit": "0" * 40,
            "repo_dirty": False,
            "events": [
                'CODEWALK_LIVE_QA {"phase": "pairing", "status": "passed"}',
                'CODEWALK_LIVE_QA {"phase": "native-cost", "status": "passed", "cost": 0}',
            ],
            "cleanup": {
                "server_exited": True,
                "temp_root_removed": True,
                "user_opencode_service_alive": True,
                "user_opencode_processes_before": [7],
                "user_opencode_processes_after": [7],
                "owned_ports": [1],
                "owned_ports_still_listening": [],
                "owned_ports_released": True,
                "owned_process_group_survivors": [],
                "user_listening_ports_removed": [],
                "foreign_ports_left": [],
            },
            "egress": {
                "violation": None,
                "nonLoopbackPeers": 0,
                "socketsObserved": 3,
                "auditRuns": 4,
                "firstAuditAt": "2026-10-19T00:00:00+00:00",
                "lastAuditAt": "2026-10-19T00:00:20+00:00",
                "auditedAt": "2026-10-19T00:00:20+00:00",
            },
            "acquisition": {
                "tarball_url": "https://example.invalid/x.tgz",
                "tarball_sha256": "a" * 64,
                "binary_sha256": "b" * 64,
            },
            "stub_ledger": [],
            "stub_hold_ends": ["disconnect"],
            "stub_requests": 0,
            "wall_seconds": 1.0,
        }
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp)
            smoke._write_fixture(evidence, out)
            results = json.loads((out / "results.json").read_text())
            self.assertEqual(results["capabilities"]["pairing"], "passed")
            self.assertEqual(results["capabilities"]["send"], "missing")
            self.assertEqual(
                results["capabilities"]["stopIdle"], "missing"
            )
            digests = (out / "SHA256SUMS").read_text()
            self.assertIn("results.json", digests)
            self.assertIn("capabilities.json", digests)

        with tempfile.TemporaryDirectory() as tmp060c:
            out060c = Path(tmp060c)
            smoke._write_fixture(evidence, out060c, unit="V2-060C")
            provenance = json.loads((out060c / "provenance.json").read_text())
            self.assertEqual(provenance["unit"], "V2-060C")
            self.assertEqual(provenance["issue"], smoke.ISSUE_URL_060C)
            results060c = json.loads((out060c / "results.json").read_text())
            self.assertEqual(results060c["capabilities"]["pairing"], "passed")
            self.assertEqual(results060c["capabilities"]["workspace"], "missing")
            self.assertEqual(results060c["capabilities"]["form"], "missing")
            self.assertEqual(results060c["capabilities"]["modelSwitch"], "missing")
            self.assertEqual(results060c["capabilities"]["error"], "missing")


if __name__ == "__main__":
    unittest.main()
