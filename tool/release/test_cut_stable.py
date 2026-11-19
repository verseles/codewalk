from pathlib import Path
import subprocess
import tempfile
import unittest

import cut_stable

HEAD = "a" * 40
NOW = 1795200000
TODAY = "2026-11-19"
BETA_PUBSPEC = "name: codewalk\nversion: 2.0.0-beta.31+1795103421\n"
STABLE_PUBSPEC = "name: codewalk\nversion: 2.0.0+1795202001\n"
CHANGELOG = (
    "# Changelog\n\n"
    "Release notes.\n\n"
    "## v1.265.1 - 2026-10-20\n\n"
    "- Prior release.\n"
)
NOTES = "> 📣 CodeWalk 2.0.0 is here.\n\n### Highlights\n\n- First stable release of CodeWalk 2.\n"


class FakeGit:
    def __init__(self, branch="main", status="", head=HEAD, remote=HEAD, tags="", remote_tags="", fail_on=None):
        self.branch = branch
        self.status = status
        self.head = head
        self.remote = remote
        self.tags = tags
        self.remote_tags = remote_tags
        self.fail_on = fail_on or set()
        self.calls = []

    def __call__(self, cmd, cwd=None, check=False, text=False, capture_output=False):
        self.calls.append(cmd)
        key = tuple(cmd[:2])
        if key in self.fail_on:
            raise subprocess.CalledProcessError(1, cmd, stderr="boom")
        if cmd[:3] == ["git", "rev-parse", "--abbrev-ref"]:
            out = self.branch + "\n"
        elif cmd[:3] == ["git", "status", "--porcelain"]:
            out = self.status
        elif cmd[:3] == ["git", "rev-parse", "HEAD"]:
            out = self.head + "\n"
        elif cmd[:4] == ["git", "ls-remote", "origin", "refs/heads/main"]:
            out = f"{self.remote}\trefs/heads/main\n" if self.remote else ""
        elif cmd[:3] == ["git", "tag", "--list"]:
            out = self.tags
        elif cmd[:4] == ["git", "ls-remote", "--tags", "origin"]:
            out = self.remote_tags
        else:
            out = ""
        return subprocess.CompletedProcess(cmd, 0, stdout=out, stderr="")


class CutStableTests(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.root = Path(tmp.name)
        (self.root / "pubspec.yaml").write_text(BETA_PUBSPEC, encoding="utf-8")
        (self.root / "CHANGELOG.md").write_text(CHANGELOG, encoding="utf-8")
        notes = self.root / "release-notes/v2.0.0.md"
        notes.parent.mkdir(parents=True)
        notes.write_text(NOTES, encoding="utf-8")

    def test_plan_graduates_beta_to_v2_0_0(self):
        fake = FakeGit()
        step = cut_stable.plan(fake, now=NOW, today=TODAY, root=self.root)
        self.assertEqual((step["version"], step["tag"], step["date"]), ("2.0.0", "v2.0.0", TODAY))
        self.assertEqual(step["build"], NOW + 2001)
        self.assertEqual(step["apk_version_code"], NOW + 4001)
        self.assertEqual(step["push"], ["git", "push", "--atomic", "origin", "HEAD:refs/heads/main", "refs/tags/v2.0.0"])

    def test_plan_refuses_non_beta_pubspec_or_second_cut(self):
        for content in (STABLE_PUBSPEC, "name: codewalk\nversion: 1.265.1+1790000000\n"):
            with self.subTest(content=content):
                (self.root / "pubspec.yaml").write_text(content, encoding="utf-8")
                with self.assertRaisesRegex(ValueError, "cannot graduate"):
                    cut_stable.plan(FakeGit(), now=NOW, today=TODAY, root=self.root)

    def test_plan_refuses_branch_dirty_unsynced_or_existing_tag(self):
        cases = [
            FakeGit(branch="v1"),
            FakeGit(status=" M lib/a.dart\0"),
            FakeGit(remote="b" * 40),
            FakeGit(tags="v2.0.0\n"),
            FakeGit(remote_tags=f"{HEAD}\trefs/tags/v2.0.0\n"),
        ]
        for fake in cases:
            with self.subTest(calls=fake.branch), self.assertRaises(ValueError):
                cut_stable.plan(fake, now=NOW, today=TODAY, root=self.root)

    def test_plan_allows_task_memory_only_changes(self):
        fake = FakeGit(status=" M .task-memory/state.json\0")
        step = cut_stable.plan(fake, now=NOW, today=TODAY, root=self.root)
        self.assertEqual(step["tag"], "v2.0.0")

    def test_plan_validates_notes_and_changelog(self):
        (self.root / "release-notes/v2.0.0.md").unlink()
        with self.assertRaisesRegex(ValueError, "missing curated release notes"):
            cut_stable.plan(FakeGit(), now=NOW, today=TODAY, root=self.root)

        for bad_notes in ("", "   \n", "> 📣 " + "x" * 301, "> 📣   \n\n- body", "## v2.0.0 - 2026-11-19\n\n- dup"):
            with self.subTest(bad_notes=bad_notes[:20]):
                (self.root / "release-notes/v2.0.0.md").write_text(bad_notes, encoding="utf-8")
                with self.assertRaises(ValueError):
                    cut_stable.plan(FakeGit(), now=NOW, today=TODAY, root=self.root)

        (self.root / "release-notes/v2.0.0.md").write_text(NOTES, encoding="utf-8")
        (self.root / "CHANGELOG.md").write_text("## v2.0.0 - 2026-11-19\n\n- exists\n", encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "already contains"):
            cut_stable.plan(FakeGit(), now=NOW, today=TODAY, root=self.root)

    def test_cut_updates_pubspec_and_changelog_then_tags_and_pushes(self):
        fake = FakeGit()
        step = cut_stable.plan(fake, now=NOW, today=TODAY, root=self.root)
        cut_stable.cut(step, fake, root=self.root)
        self.assertIn(f"version: 2.0.0+{step['build']}\n", (self.root / "pubspec.yaml").read_text(encoding="utf-8"))
        updated_changelog = (self.root / "CHANGELOG.md").read_text(encoding="utf-8")
        self.assertIn(f"## v2.0.0 - {TODAY}\n\n{NOTES.strip()}\n\n## v1.265.1 - 2026-10-20", updated_changelog)
        self.assertIn(["git", "add", "-f", "--", "pubspec.yaml", "CHANGELOG.md", ".task-memory"], fake.calls)
        self.assertIn(["git", "commit", "-m", "release: cut v2.0.0"], fake.calls)
        self.assertIn(["git", "tag", "-a", "v2.0.0", "-m", "v2.0.0"], fake.calls)
        self.assertIn(step["push"], fake.calls)

    def test_cut_restores_both_files_if_commit_fails(self):
        fake = FakeGit(fail_on={("git", "commit")})
        step = cut_stable.plan(fake, now=NOW, today=TODAY, root=self.root)
        with self.assertRaises(subprocess.CalledProcessError):
            cut_stable.cut(step, fake, root=self.root)
        self.assertEqual((self.root / "pubspec.yaml").read_text(encoding="utf-8"), BETA_PUBSPEC)
        self.assertEqual((self.root / "CHANGELOG.md").read_text(encoding="utf-8"), CHANGELOG)

    def test_cut_reports_recovery_command_if_push_fails(self):
        fake = FakeGit(fail_on={("git", "push")})
        step = cut_stable.plan(fake, now=NOW, today=TODAY, root=self.root)
        with self.assertRaisesRegex(ValueError, "git push --atomic origin HEAD:refs/heads/main refs/tags/v2.0.0"):
            cut_stable.cut(step, fake, root=self.root)


if __name__ == "__main__":
    unittest.main()
