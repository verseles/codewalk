import json
from pathlib import Path
import tempfile
import unittest
from unittest import mock

import smoke_v2_linux_release as subject
from test_verify_v2_artifacts import LEGACY_AOT, ArtifactFixture


class FakeProcess:
    def __init__(self, exits_after=None):
        self.pid = 4242
        self.returncode = None
        self.polls = 0
        self.exits_after = exits_after

    def poll(self):
        self.polls += 1
        if self.exits_after is not None and self.polls > self.exits_after:
            self.returncode = 3
        return self.returncode

    def wait(self, timeout=None):
        self.returncode = -15
        return self.returncode


class SmokeTest(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.fixture = ArtifactFixture(self.root)
        self.evidence = self.root / "evidence"
        self.launched = []
        self.killed = []
        patches = [
            mock.patch.object(subject.platform, "machine", return_value="aarch64"),
            mock.patch.object(subject.shutil, "which", side_effect=lambda name: f"/usr/bin/{name}"),
            mock.patch.dict(subject.os.environ, {"DISPLAY": ":99", "HOME": "/home/owner",
                                                 "XAUTHORITY": "/tmp/xvfb-run.abc/Xauthority"}),
            mock.patch.object(subject.os, "killpg", side_effect=lambda pid, sig: self.killed.append(sig)),
        ]
        for patch in patches:
            patch.start()
            self.addCleanup(patch.stop)

    def popen(self, process):
        def start(command, **kwargs):
            self.launched.append((command, kwargs["env"]))
            return process
        return start

    def windows(self, found):
        def run(command, **_):
            return mock.Mock(stdout="\n".join(found) if command[0] == "xdotool" else "")
        return run

    def smoke(self, archive, process, found=("12345",), target="linux-arm64"):
        return subject.smoke(archive, target, self.evidence, runner=self.windows(found),
                             popen=self.popen(process), clock=iter(range(1000)).__next__, sleep=lambda _: None)

    def test_a_visible_live_window_passes_and_the_app_is_stopped(self):
        report = self.smoke(self.fixture.linux("linux-arm64"), FakeProcess())
        self.assertEqual(report["launch"], "passed", report.get("error"))
        self.assertEqual(report["checks"], {"hostArchitecture": "passed", "bundleVerified": "passed",
                                            "windowVisible": "passed", "aliveAfterSettle": "passed"})
        self.assertEqual(report["architecture"], "arm64")
        self.assertEqual(self.killed, [subject.signal.SIGTERM])
        written = json.loads((self.evidence / "linux-arm64-launch.json").read_text())
        self.assertEqual(written["sha256"], report["sha256"])

    def test_the_app_never_sees_the_host_home_or_xdg_dirs(self):
        self.smoke(self.fixture.linux("linux-arm64"), FakeProcess())
        command, env = self.launched[0]
        self.assertTrue(command[0].endswith("/bundle/codewalk"))
        for key in ("HOME", "XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME", "XDG_STATE_HOME",
                    "XDG_RUNTIME_DIR"):
            self.assertIn("cw2-release-smoke-", env[key])
        self.assertNotIn("/home/owner", env.values())
        # The display cookie from xvfb-run must reach the app, or it cannot open the display.
        self.assertEqual(env["XAUTHORITY"], "/tmp/xvfb-run.abc/Xauthority")
        self.assertEqual((env["GDK_BACKEND"], env["FLUTTER_LINUX_RENDERER"]), ("x11", "software"))

    def test_no_window_or_an_early_exit_fails(self):
        report = self.smoke(self.fixture.linux("linux-arm64"), FakeProcess(), found=())
        self.assertEqual(report["launch"], "fail")
        self.assertIn("no visible window", report["error"])
        report = self.smoke(self.fixture.linux("linux-arm64"), FakeProcess(exits_after=1))
        self.assertEqual(report["launch"], "fail")
        self.assertIn("exited during the settle period", report["error"])

    def test_a_bundle_the_verifier_refuses_is_never_launched(self):
        report = self.smoke(self.fixture.linux("linux-arm64", libapp=LEGACY_AOT), FakeProcess())
        self.assertEqual(report["launch"], "fail")
        self.assertIn("v2 bootstrap", report["error"])
        self.assertEqual(self.launched, [])

    def test_a_bundle_runs_only_on_its_own_architecture(self):
        report = self.smoke(self.fixture.linux("linux-x64"), FakeProcess(), target="linux-x64")
        self.assertEqual(report["launch"], "fail")
        self.assertIn("own architecture", report["error"])
        self.assertEqual(self.launched, [])

    def test_a_corrupt_archive_is_recorded_as_a_failed_launch(self):
        archive = self.root / "codewalk-linux-arm64.tar.gz"
        archive.write_bytes(b"not a tarball")
        report = self.smoke(archive, FakeProcess())
        self.assertEqual(report["launch"], "fail")
        self.assertTrue((self.evidence / "linux-arm64-launch.json").is_file())
        self.assertEqual(self.launched, [])

    def test_an_app_that_exits_as_it_is_stopped_still_passes(self):

        def gone(pid, sig):
            raise ProcessLookupError

        with mock.patch.object(subject.os, "killpg", side_effect=gone):
            report = self.smoke(self.fixture.linux("linux-arm64"), FakeProcess())
        self.assertEqual(report["launch"], "passed", report.get("error"))
        self.assertIn("log_tail", report)

    def test_a_missing_archive_is_recorded_as_a_failed_launch(self):
        report = self.smoke(self.root / "absent.tar.gz", FakeProcess())
        self.assertEqual(report["launch"], "fail")
        self.assertTrue((self.evidence / "linux-arm64-launch.json").is_file())

    def test_unsafe_archive_entries_are_refused(self):
        archive = self.fixture.linux("linux-arm64", extra={"../escape": b"x"})
        report = self.smoke(archive, FakeProcess())
        self.assertEqual(report["launch"], "fail")
        self.assertEqual(self.launched, [])


if __name__ == "__main__":
    unittest.main()
