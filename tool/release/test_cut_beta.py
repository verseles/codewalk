from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest import mock

import cut_beta

HEAD = "1" * 40
NOW = 1792775859


class FakeGit:
    def __init__(self, branch="main", status="", remote=HEAD, tags="", remote_tags="", fail=None):
        self.fail = fail
        self.answers = {"rev-parse --abbrev-ref HEAD": branch, "status --porcelain -z": status,
                        "rev-parse HEAD": HEAD, "ls-remote origin refs/heads/main": f"{remote}\trefs/heads/main" if remote else ""}
        self.tags, self.remote_tags = tags, remote_tags
        self.calls = []

    def __call__(self, command, **_):
        self.calls.append(command)
        if self.fail and command[1] == self.fail:
            raise subprocess.CalledProcessError(1, command)
        key = " ".join(command[1:])
        if key.startswith("tag --list"):
            out = self.tags
        elif key.startswith("ls-remote --tags"):
            out = self.remote_tags
        else:
            out = self.answers.get(key, "")
        return mock.Mock(stdout=out)


class CutBetaTests(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.root = Path(directory.name)
        patcher = mock.patch.object(cut_beta, "ROOT", self.root)
        patcher.start()
        self.addCleanup(patcher.stop)
        self.pubspec("1.265.0+1790827338")

    def pubspec(self, version):
        (self.root / "pubspec.yaml").write_text(f"name: codewalk\nversion: {version}\n")

    def test_the_first_beta_follows_the_legacy_version(self):
        step = cut_beta.plan(FakeGit(), now=NOW)
        self.assertEqual((step["version"], step["tag"]), ("2.0.0-beta.1", "v2.0.0-beta.1"))
        self.assertEqual(step["build"], NOW + 2001)
        self.assertEqual(step["apk_version_code"], NOW + 4001)
        self.assertEqual(step["push"], ["git", "push", "--atomic", "origin", "HEAD:refs/heads/main",
                                        "refs/tags/v2.0.0-beta.1"])

    def test_betas_count_numerically(self):
        self.pubspec("2.0.0-beta.9+1792800000")
        self.assertEqual(cut_beta.plan(FakeGit(), now=NOW)["version"], "2.0.0-beta.10")

    def test_the_build_never_drops_below_the_pubspec_or_the_published_baseline(self):
        self.pubspec("2.0.0-beta.1+1900000000")
        self.assertEqual(cut_beta.plan(FakeGit(), now=NOW)["build"], 1900000001)
        self.pubspec("1.265.0+1")
        # The published baseline APK is 1792744369, so the build floor is 1792742370.
        self.assertEqual(cut_beta.plan(FakeGit(), now=0)["build"], 1792742370)

    def test_ga_and_unknown_versions_are_refused(self):
        for version in ("2.0.0+1792800000", "2.1.0-beta.1+1792800000", "3.0.0+1"):
            with self.subTest(version=version), self.assertRaisesRegex(ValueError, "cannot cut"):
                self.pubspec(version)
                cut_beta.plan(FakeGit(), now=NOW)

    def test_the_checkout_must_be_a_clean_synced_main(self):
        for fake, message in ((FakeGit(branch="v1"), "on main"),
                              (FakeGit(status=" M lib/main_v2.dart\0"), "pending changes"),
                              (FakeGit(status="R  notes.md\0.task-memory/a.md\0"), "pending changes"),
                              (FakeGit(status="R  .task-memory/b.md\0lib/x.dart\0"), "pending changes"),
                              (FakeGit(remote="2" * 40), "origin/main"),
                              (FakeGit(remote=""), "origin/main")):
            with self.subTest(message=message), self.assertRaisesRegex(ValueError, message):
                cut_beta.plan(fake, now=NOW)

    def test_the_task_memory_snapshot_may_be_dirty(self):
        fake = FakeGit(status=" M .task-memory/state.json\0?? .task-memory/artifacts/x/A0001.md\0"
                           "R  .task-memory/b.md\0.task-memory/a.md\0")
        self.assertEqual(cut_beta.plan(fake, now=NOW)["tag"], "v2.0.0-beta.1")

    def test_an_existing_tag_is_refused(self):
        for fake in (FakeGit(tags="v2.0.0-beta.1"), FakeGit(remote_tags=f"{HEAD}\trefs/tags/v2.0.0-beta.1")):
            with self.subTest(), self.assertRaisesRegex(ValueError, "already exists"):
                cut_beta.plan(fake, now=NOW)

    def test_planning_writes_nothing(self):
        fake = FakeGit()
        cut_beta.plan(fake, now=NOW)
        self.assertEqual((self.root / "pubspec.yaml").read_text(), "name: codewalk\nversion: 1.265.0+1790827338\n")
        self.assertFalse([call for call in fake.calls if call[1] in ("add", "commit", "tag", "push")
                          and not call[1:3] == ["tag", "--list"]])

    def test_the_cut_commits_tags_and_pushes_exact_refs(self):
        fake = FakeGit()
        step = cut_beta.plan(fake, now=NOW)
        cut_beta.cut(step, fake)
        self.assertIn(f"version: 2.0.0-beta.1+{NOW + 2001}\n", (self.root / "pubspec.yaml").read_text())
        writes = [call for call in fake.calls if call[1] in ("add", "commit", "tag", "push")][1:]
        self.assertEqual(writes, [
            ["git", "add", "pubspec.yaml", "--", ".task-memory"],
            ["git", "commit", "-m", "release: cut v2.0.0-beta.1"],
            ["git", "tag", "-a", "v2.0.0-beta.1", "-m", "v2.0.0-beta.1"],
            ["git", "push", "--atomic", "origin", "HEAD:refs/heads/main", "refs/tags/v2.0.0-beta.1"],
        ])
        self.assertNotIn("--follow-tags", sum(fake.calls, []))

    def test_a_failed_commit_restores_the_pubspec(self):
        fake = FakeGit(fail="commit")
        step = cut_beta.plan(fake, now=NOW)
        with self.assertRaises(subprocess.CalledProcessError):
            cut_beta.cut(step, fake)
        self.assertIn("version: 1.265.0+1790827338\n", (self.root / "pubspec.yaml").read_text())
        self.assertIn(["git", "reset", "--quiet", "--", "pubspec.yaml"], fake.calls)

    def test_a_failed_push_names_the_recovery(self):
        fake = FakeGit(fail="push")
        step = cut_beta.plan(fake, now=NOW)
        with self.assertRaisesRegex(ValueError, "git push --atomic origin HEAD:refs/heads/main refs/tags/v2.0.0-beta.1"):
            cut_beta.cut(step, fake)


if __name__ == "__main__":
    unittest.main()
