"""Offline acceptance and tamper tests for the observed V2-071G contract."""

import copy
import hashlib
import json
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from tool.ci import capture_v2_turn_actions as capture

FIXTURES = Path(__file__).resolve().parents[2] / (
    "test/contract/fixtures/opencode/2.0.22/turn-actions-071g"
)


class CapturedTurnActionsTests(unittest.TestCase):
    def setUp(self):
        self.data = json.loads((FIXTURES / "capture-r2.json").read_text())

    def call(self, label):
        return next(c for c in self.data["calls"] if c["label"] == label)

    def test_observed_native_effects_and_cleanup_pass(self):
        self.assertEqual(capture.problems(self.data), [])
        self.assertEqual(self.call("busy-compact")["status"], 200)
        self.assertEqual(self.call("busy-compact")["response"]["data"]["type"], "compaction")

    def test_fixture_digests_and_actual_producers_match(self):
        for line in (FIXTURES / "SHA256SUMS").read_text().splitlines():
            digest, filename = line.split("  ")
            self.assertEqual(hashlib.sha256((FIXTURES / filename).read_bytes()).hexdigest(), digest)
        for name, digest in self.data["producer_sha256"].items():
            self.assertEqual(hashlib.sha256(Path(capture.__file__).with_name(name).read_bytes()).hexdigest(),
                             digest, name)

    def test_routes_and_payloads_are_native_not_v1_revert(self):
        for label in ("undo-both", "redo-one", "branch-stage", "busy-stage"):
            call = self.call(label)
            self.assertEqual(call["method"], "POST")
            self.assertTrue(call["path"].endswith("/revert/stage"))
            self.assertEqual(set(call["request"]), {"messageID", "files"})
            self.assertIs(call["request"]["files"], True)
        self.assertEqual(self.call("redo-all")["method"], "DELETE")
        self.assertEqual(self.call("branch-commit")["method"], "POST")
        self.assertTrue(self.call("branch-commit")["path"].endswith("/revert/commit"))
        self.assertEqual(self.call("idle-compact")["request"], {"delivery": "steer"})

    def test_tampered_boundary_and_unremoved_tail_are_rejected(self):
        self.call("after-redo-one")["response"]["data"]["revert"]["messageID"] = "msg_wrong"
        self.call("after-commit/message?order=asc&limit=200")["response"]["data"] = [{"id": "msg_old"}]
        errors = capture.problems(self.data)
        self.assertIn("authoritative redo state", errors)
        self.assertIn("commit did not remove tail", errors)

    def test_commit_after_prompt_cannot_pass(self):
        calls = self.data["calls"]
        a, b = calls.index(self.call("branch-commit")), calls.index(self.call("branch-prompt"))
        calls[a], calls[b] = calls[b], calls[a]
        self.assertIn("commit-before-prompt", capture.problems(self.data))

    def test_admission_alone_never_passes_compaction_completion(self):
        self.data["events"] = [e for e in self.data["events"] if e["type"] != "session.compaction.ended"]
        self.assertIn("compact successful completion", capture.problems(self.data))

    def test_busy_compact_requires_its_own_matching_lifecycle(self):
        sid = self.call("busy-compact")["response"]["data"]["sessionID"]
        self.data["events"] = [e for e in self.data["events"] if not (
            e["type"].startswith("session.compaction.") and e.get("data", {}).get("sessionID") == sid
        )]
        self.assertIn("busy compact lifecycle", capture.problems(self.data))

    def test_busy_compact_start_must_match_the_admitted_control(self):
        sid = self.call("busy-compact")["response"]["data"]["sessionID"]
        for event in self.data["events"]:
            if event["type"] == "session.compaction.started" and event["data"]["sessionID"] == sid:
                event["data"]["inputID"] = "msg_other"
        self.assertIn("busy compact lifecycle", capture.problems(self.data))

    def test_busy_compact_admission_and_start_do_not_prove_completion(self):
        sid = self.call("busy-compact")["response"]["data"]["sessionID"]
        self.data["events"] = [e for e in self.data["events"] if not (
            e["type"] == "session.compaction.ended" and e.get("data", {}).get("sessionID") == sid
        )]
        self.assertIn("busy compact lifecycle", capture.problems(self.data))

    def test_wrong_busy_tag_and_missing_busy_call_are_rejected(self):
        self.call("busy-stage")["response"] = {"_tag": "ConflictError"}
        self.assertIn("busy-stage error tag", capture.problems(self.data))
        self.data["calls"] = [c for c in self.data["calls"] if c["label"] != "busy-commit"]
        self.assertIn("incomplete contract evidence", capture.problems(self.data))

    def test_execution_terminal_must_follow_start_of_that_session(self):
        # Native events contain no executionID. An unrelated terminal must not
        # satisfy a missing last terminal via an accidental None == None match.
        last = next(i for i in range(len(self.data["events"]) - 1, -1, -1)
                    if self.data["events"][i]["type"] in capture.TERMINALS)
        self.data["events"].pop(last)
        self.assertIn("native executions without terminal", capture.problems(self.data))
        foreign = {"type": "session.execution.succeeded", "data": {"sessionID": "ses_foreign"}}
        self.data["events"].insert(0, foreign)
        self.assertIn("terminal without observed start", capture.problems(self.data))

    def test_unknown_binary_unverified_egress_and_spend_configuration_fail(self):
        self.data["binary_sha256"] = "0" * 64
        self.data["egress"] = {}
        self.data["zero_spend_configuration"] = False
        errors = capture.problems(self.data)
        self.assertIn("binary pin", errors)
        self.assertIn("egress audit", errors)
        self.assertIn("zero-spend configuration", errors)

    def test_execution_and_provider_caps_are_not_waived(self):
        start = next(e for e in self.data["events"] if e["type"] == "session.execution.started")
        self.data["events"].extend(copy.deepcopy(start) for _ in range(capture.MAX_STARTS))
        self.data["provider_requests"] = capture.MAX_STARTS + 1
        errors = capture.problems(self.data)
        self.assertIn("native execution cap", errors)
        self.assertIn("provider request cap", errors)

    def test_negative_diagnostic_preserves_real_failed_compaction(self):
        negative = json.loads((FIXTURES / "compaction-failed-diagnostic.json").read_text())
        failures = [e for e in negative["events"] if e["type"] == "session.compaction.failed"]
        self.assertEqual(len(failures), 2)
        self.assertTrue(all(e["data"]["error"]["type"] == "compaction.failed" for e in failures))
        self.assertTrue(all(e["data"]["cost"] == 0 for e in failures))
        self.assertEqual(negative["cleanup"]["active"], {"data": {}})
        self.assertEqual(negative["cleanup"]["sessions_absent"], 3)

    def test_sanitization_excludes_opaque_state_and_generated_credentials(self):
        root = Path("/tmp/opencode/owned-capture")
        self.assertEqual(capture.sanitized({
            "providerState": "opaque", "providerContext": {"private": "content"},
            "password": "private", "directory": str(root / "project"),
            "nested": [{"token": "private", "status": 200}],
        }, root), {"directory": "<owned-root>/project", "nested": [{"status": 200}]})


if __name__ == "__main__":
    unittest.main()
