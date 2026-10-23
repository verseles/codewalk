"""Every main push, tag and dispatch path, checked for publication side effects.

Each check reads the real workflow or Makefile; each guard also has a planted
mutation (the guard removed or widened) that the same check must reject, so
a check that stops seeing its guard fails instead of passing silently.
"""
from pathlib import Path
import re
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[2]
WORKFLOWS = ROOT / ".github/workflows"
PUBLISHING = ("softprops/", "gh release create", "gh release edit", "gh release upload", "--clobber",
              "pages deploy", "wrangler", "make release", "make web", "--follow-tags",
              "repos/$GITHUB_REPOSITORY/releases", "contents: write", "deployments: write")


def read(name: str) -> str:
    return (WORKFLOWS / name).read_text(encoding="utf-8")


def jobs(text: str) -> dict[str, str]:
    """Job blocks of the repository's block-style workflow YAML."""
    body = text.split("\njobs:\n", 1)[1]
    found = re.findall(r"^  ([A-Za-z0-9_-]+):\n(.*?)(?=^  [A-Za-z0-9_-]+:\n|\Z)", body, re.M | re.S)
    return dict(found)


def triggers(text: str) -> str:
    return re.search(r"^on:\n(.*?)(?=^\S)", text, re.M | re.S).group(1).rstrip() + "\n"


def check_release(text: str) -> None:
    on = triggers(text)
    assert re.fullmatch(r"  push:\n    tags:\n      - \"v\*\"\n  workflow_dispatch:\n(    .*\n)*", on), "release triggers"
    assert re.search(r"^permissions:\n  contents: read\n", text, re.M), "release default permissions"
    found = jobs(text)
    assert set(found) == {"plan", "build-linux", "build-android", "verify", "publish"}, f"release jobs {sorted(found)}"
    plan = found["plan"]
    assert "tool/release/release_plan.py" in plan, "plan runs release_plan.py"
    assert "tool/release/build_codes.py check" in plan, "plan checks the build code"
    assert "require_tag_at_commit.sh" in plan and "require_new_release.sh" in plan, "plan checks tag and release"
    for job in ("build-linux", "build-android"):
        assert re.search(r"^    needs: plan$", found[job], re.M), f"{job} needs plan"
    assert re.search(r"^    needs: \[plan, build-linux, build-android\]$", found["verify"], re.M), "verify needs builds"
    assert "tool/release/verify_v2_artifacts.py" in found["verify"], "verify runs the verifier"
    publish = found["publish"]
    assert re.search(r"^    needs: \[plan, verify\]$", publish, re.M), "publish needs plan and verify"
    assert re.search(r"^    if: needs\.plan\.outputs\.publish == 'true'$", publish, re.M), "publish is gated"
    steps = [publish.find(script) for script in
             ("require_tag_at_commit.sh", "require_new_release.sh", "create_v2_beta_release.sh")]
    assert min(steps) >= 0 and steps == sorted(steps), "publish rechecks before creating"
    for name, job in found.items():
        write = "contents: write" in job
        assert write == (name == "publish"), f"only publish may write ({name})"
    builds = re.findall(r"flutter build [^\n]*(?:\n\s+--[^\n]*)*", text)
    assert len(builds) == 2, f"two builds expected, found {len(builds)}"
    for build in builds:
        assert "--target lib/main_v2.dart" in build, f"build without the v2 entry point: {build!r}"
        assert re.match(r"flutter build (linux|apk) --release", build), f"unexpected build: {build!r}"
    for forbidden in ("softprops/", "prerelease: false", "make_latest: true", "--clobber", "windows", "macos",
                      "pages deploy", "wrangler", "make web", "make release", "make android", "make desktop"):
        assert forbidden not in text, f"release contains {forbidden!r}"


def check_web(text: str) -> None:
    deploy = jobs(text)["deploy-web"]
    assert re.search(r"^    if: github\.ref == 'refs/heads/main' && github\.event_name == 'workflow_dispatch'$",
                     deploy, re.M), "web deploys only on a main dispatch"
    guard = deploy.find("tool/release/guard_legacy_build.py pubspec.yaml --web-ref \"$GITHUB_REF\"")
    assert guard >= 0, "web runs the legacy build guard"
    for later in ("make web", "pages deploy"):
        assert deploy.find(later) > guard, f"web guard must precede {later}"


def check_read_only(name: str, text: str) -> None:
    assert re.search(r"^permissions:\n  contents: read\n", text, re.M), f"{name} default permissions"
    for forbidden in PUBLISHING:
        assert forbidden not in text, f"{name} contains {forbidden!r}"


def check_makefile(text: str) -> None:
    for target in ("web", "desktop", "android"):
        recipe = re.search(rf"^{target}:\n((?:\t.*\n)+)", text, re.M)
        assert recipe, f"missing {target} target"
        first = recipe.group(1).splitlines()[0]
        assert first == "\t@python3 tool/release/guard_legacy_build.py pubspec.yaml", f"{target} must start with the guard"
    release = re.search(r"^release:\n((?:\t.*\n)+)", text, re.M).group(1)
    assert 'if [ "$(V)" != "beta" ]' in release and "exit 1" in release, "release refuses non-beta"
    assert "tool/release/cut_beta.py" in release, "release uses cut_beta.py"
    assert "git push" not in release and "git tag" not in release, "release pushes only through cut_beta.py"
    assert "--follow-tags" not in text, "no --follow-tags"


class PublicationPathTests(unittest.TestCase):
    def assert_rejected(self, check, *args):
        with self.assertRaises(AssertionError):
            check(*args)

    def test_tag_and_dispatch_publish_only_through_the_v2_beta_plan(self):
        text = read("release.yml")
        check_release(text)
        for mutated in (
            text.replace("    needs: plan\n", "", 1),
            text.replace("    if: needs.plan.outputs.publish == 'true'\n", ""),
            text.replace(" --target lib/main_v2.dart", "", 1),
            text.replace("python3 tool/release/release_plan.py", "echo publish=true #", 1),
            text.replace("python3 tool/release/build_codes.py check", "true", 1),
            text.replace("-f make_latest=false", "") + "\n# make_latest: true\n",
            text.replace("    permissions:\n      contents: write\n", "").replace(
                "permissions:\n  contents: read\n", "permissions:\n  contents: write\n", 1),
            text.replace("  workflow_dispatch:\n", "  workflow_dispatch:\n  pull_request:\n", 1),
            text.replace("bash tool/release/create_v2_beta_release.sh", "uses: softprops/action-gh-release@v2 #"),
            text + "\n      - run: flutter build windows --release --target lib/main_v2.dart\n",
        ):
            with self.subTest():
                self.assert_rejected(check_release, mutated)

    def test_the_web_preview_deploys_only_guarded_from_main(self):
        text = read("web-pages.yml")
        check_web(text)
        for mutated in (
            text.replace("github.ref == 'refs/heads/main' && ", "github.ref != 'refs/heads/main' || "),
            text.replace("python3 tool/release/guard_legacy_build.py pubspec.yaml --web-ref \"$GITHUB_REF\"", "true"),
            text.replace("      - name: Refuse a v2-labelled legacy build\n        run: python3 tool/release/"
                         "guard_legacy_build.py pubspec.yaml --web-ref \"$GITHUB_REF\"\n", "")
                + "\n      - run: python3 tool/release/guard_legacy_build.py pubspec.yaml --web-ref \"$GITHUB_REF\"\n",
        ):
            with self.subTest():
                self.assert_rejected(check_web, mutated)

    def test_every_other_workflow_is_read_only(self):
        names = sorted(path.name for path in WORKFLOWS.glob("*.yml") if path.name not in ("release.yml", "web-pages.yml"))
        self.assertEqual(names, ["ci.yml", "opencode-smoke.yml", "session-overlay-prototype.yml",
                                 "v2-deferred-web.yml", "v2-device-reliability.yml", "v2-owner-preview.yml"])
        for name in names:
            with self.subTest(name=name):
                text = read(name)
                check_read_only(name, text)
                self.assert_rejected(check_read_only, name, text.replace("permissions:\n  contents: read\n", "", 1))
                self.assert_rejected(check_read_only, name, text + "\n      - run: gh release upload x y\n")

    def test_the_smoke_tag_filter_skips_betas(self):
        # GitHub matches tag filters against the whole ref name.
        pattern = re.search(r'tags:\n\s+- "([^"]+)"', read("opencode-smoke.yml")).group(1)
        regex = "^" + pattern.replace(".", r"\.").replace("[0-9]+", "[0-9]+") + "$"
        self.assertIsNone(re.match(regex, "v2.0.0-beta.1"))
        self.assertIsNotNone(re.match(regex, "v2.0.0"))

    def test_make_targets_guard_legacy_builds_and_cut_only_betas(self):
        text = (ROOT / "Makefile").read_text(encoding="utf-8")
        check_makefile(text)
        for mutated in (
            text.replace("web:\n\t@python3 tool/release/guard_legacy_build.py pubspec.yaml\n", "web:\n", 1),
            text.replace('if [ "$(V)" != "beta" ]', 'if [ -z "$(V)" ]'),
            text.replace("\tpython3 tool/release/cut_beta.py", "\tgit push --follow-tags; python3 tool/release/cut_beta.py"),
        ):
            with self.subTest():
                self.assert_rejected(check_makefile, mutated)

    def test_the_changelog_keeps_only_stable_headings_for_installed_v1_apps(self):
        # Installed CodeWalk 1 apps parse main's CHANGELOG.md and reject any
        # other release heading (release_history_service.dart on v1).
        headings = re.findall(r"^##(?:\s.*)?$", (ROOT / "CHANGELOG.md").read_text(encoding="utf-8"), re.M)
        self.assertTrue(headings)
        for heading in headings:
            with self.subTest(heading=heading):
                self.assertRegex(heading, r"^## v\d+\.\d+\.\d+ - \d{4}-\d{2}-\d{2}$")

    def test_make_release_refuses_every_non_beta_cut_before_any_change(self):
        for value in ("patch", "minor", "major", ""):
            with self.subTest(value=value):
                result = subprocess.run(["make", "-s", "-C", str(ROOT), "release", f"V={value}"],
                                        capture_output=True, text=True)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("main releases only v2 betas", result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
