#!/usr/bin/env python3
"""Exercise the exact packaged native preview under an existing Xvfb display."""

import argparse
import csv
import io
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import subprocess
import sys
import tarfile
import tempfile
import time

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from tool.preview import preview_linux as preview


def run(command, *, timeout=10):
    return subprocess.run(command, check=True, text=True, capture_output=True, timeout=timeout).stdout


def extract(archive_path, destination):
    with tarfile.open(archive_path) as archive:
        seen = set()
        for member in archive.getmembers():
            path = PurePosixPath(member.name)
            if (path.is_absolute() or ".." in path.parts or not path.parts
                    or path.parts[0] != preview.ARCHIVE_ROOT or member.name in seen
                    or not (member.isdir() or member.isfile())):
                raise RuntimeError("Unsafe preview archive entry.")
            seen.add(member.name)
        # Links, devices and traversal were rejected above; only this owned
        # destination is populated from the verified archive.
        archive.extractall(destination)
    bundle = destination / preview.ARCHIVE_ROOT
    preview.verify_bundle(bundle)
    return bundle


def parse_ocr(text):
    result = []
    for row in csv.DictReader(io.StringIO(text), delimiter="\t"):
        label = row.get("text", "").strip()
        if label and float(row.get("conf", "-1")) >= 25:
            result.append((label, int(row["left"]) + int(row["width"]) // 2,
                           int(row["top"]) + int(row["height"]) // 2))
    return result


def locate(words, label):
    tokens = label.lower().split()
    for index in range(len(words) - len(tokens) + 1):
        group = words[index:index + len(tokens)]
        if [re.sub(r"[^a-z0-9]", "", word[0].lower()) for word in group] == tokens:
            return group[0][1], group[0][2]
    return None


def sanitized(text):
    return re.sub(r"https?://(?:127\.0\.0\.1|localhost):\d+/\S*", "[local debug service]", text)


def verify_dark_rendering(light, dark, restarted):
    if dark >= 0.45 or light - dark < 0.25 or abs(restarted - dark) > 0.15:
        raise RuntimeError("Rendered dark appearance was not applied and retained after restart.")


def compact_geometry(text):
    values = dict(line.split("=", 1) for line in text.splitlines() if "=" in line)
    return values.get("WIDTH") == "480" and values.get("HEIGHT") == "800"


def ui_state_matches(words, required, absent=()):
    return (all(locate(words, label) is not None for label in required)
            and all(locate(words, label) is None for label in absent))


def smoke(archive_path, evidence):
    checksum = preview.digest(archive_path)
    evidence.mkdir(parents=True, exist_ok=True)
    for program in ("xdotool", "import", "convert", "tesseract", "secret-tool"):
        if shutil.which(program) is None:
            raise RuntimeError(f"Missing native smoke runtime: {program}")
    report = {
        "archive_sha256": checksum, "target": "Ubuntu 24.04 Linux x64 X11/software",
        "checks": [], "native_visual": "fail", "release_mvp": "not-tested",
        "server_pairing": "not-tested", "gpu_wayland": "not-tested",
    }
    process = None
    with tempfile.TemporaryDirectory(prefix="cw2-smoke-") as temporary:
        root = Path(temporary)
        host = root / "synthetic-host"
        (host / ".local/share/com.verseles.codewalk").mkdir(parents=True)
        sentinel = host / ".local/share/com.verseles.codewalk/shared_preferences.json"
        sentinel.write_text('{"legacy-sentinel":"unchanged"}\n')
        before = preview.digest(sentinel)
        profile = root / "preview-profile"
        bundle = extract(archive_path, root / "extracted")
        report["source_commit"] = preview.verify_bundle(bundle)["source_commit"]
        env = dict(os.environ)
        env.update({"HOME": str(host), "XDG_DATA_HOME": str(host / ".local/share"),
                    "GDK_SCALE": "1", "GDK_DPI_SCALE": "1",
                    "LANG": "C.UTF-8", "LC_ALL": "C.UTF-8", "CODEWALK_PREVIEW_ISOLATION_CHECK": "1"})
        snapshot = evidence / "current.png"

        def start():
            nonlocal process
            process = subprocess.Popen([str(bundle / "Open-preview.sh"), "--profile", str(profile)],
                                       env=env, start_new_session=True)
            deadline = time.monotonic() + 40
            while time.monotonic() < deadline:
                if process.poll() is not None:
                    raise RuntimeError(f"Preview exited during startup: {process.returncode}")
                windows = subprocess.run(["xdotool", "search", "--onlyvisible", "--name", "^codewalk$"],
                                         text=True, capture_output=True, timeout=3)
                if windows.returncode == 0 and windows.stdout.strip():
                    window = windows.stdout.splitlines()[-1]
                    run(["xdotool", "windowfocus", "--sync", window])
                    return window
                time.sleep(0.2)
            raise RuntimeError("Native first-frame window did not appear.")

        def capture(window, filename):
            run(["import", "-silent", "-window", window, str(filename)])
            return parse_ocr(run(["tesseract", str(filename), "stdout", "--psm", "11", "tsv"], timeout=15))

        def expect(window, labels, name, *, absent=()):
            deadline = time.monotonic() + 15
            while time.monotonic() < deadline:
                if process is None or process.poll() is not None:
                    raise RuntimeError(f"Native preview exited while verifying {name}.")
                words = capture(window, snapshot)
                if ui_state_matches(words, labels, absent):
                    shutil.copyfile(snapshot, evidence / f"{name}.png")
                    report["checks"].append(name)
                    return words
                time.sleep(0.2)
            shutil.copyfile(snapshot, evidence / f"{name}-failure.png")
            raise RuntimeError(f"Expected native UI state absent: {name}, {labels}")

        def click(window, label):
            words = capture(window, snapshot)
            position = locate(words, label)
            if position is None:
                raise RuntimeError(f"Cannot locate native UI control: {label}")
            run(["xdotool", "mousemove", "--sync", "--window", window, str(position[0]), str(position[1])])
            run(["xdotool", "click", "--clearmodifiers", "1"])

        def luminance(window):
            capture(window, snapshot)
            return float(run(["convert", str(snapshot), "-gravity", "southeast", "-crop", "32x32+24+24",
                              "-colorspace", "Gray", "-format", "%[fx:mean]", "info:"]))

        try:
            window = start()
            expect(window, ["CodeWalk", "Settings"], "01-initial")
            click(window, "Servers")
            expect(window, ["Add server"], "02-hosts")
            click(window, "Pair")
            expect(window, ["Pairing link", "Open QR image"], "03-pairing")
            run(["xdotool", "key", "--clearmodifiers", "ctrl+comma"])
            expect(window, ["Appearance", "Shortcuts"], "04-settings-wide")
            click(window, "Light")
            deadline = time.monotonic() + 10
            light = luminance(window)
            while light < 0.65 and time.monotonic() < deadline:
                time.sleep(0.2)
                light = luminance(window)
            click(window, "Dark")
            deadline = time.monotonic() + 10
            preference = None
            while time.monotonic() < deadline:
                candidates = list((profile / "data").rglob("shared_preferences.json"))
                if candidates:
                    candidate = candidates[0]
                    values = json.loads(candidate.read_text())
                    if values.get("cw2.settings.themeMode") == "dark":
                        preference = candidate
                        break
                time.sleep(0.2)
            if preference is None:
                raise RuntimeError("Dark appearance did not persist through the real plugin.")
            expect(window, ["Appearance", "Dark"], "05-dark")
            deadline = time.monotonic() + 10
            dark = luminance(window)
            while dark >= 0.45 and time.monotonic() < deadline:
                time.sleep(0.2)
                dark = luminance(window)
            preview.stop_owned(process, timeout=30)
            window = start()
            run(["xdotool", "key", "--clearmodifiers", "ctrl+comma"])
            expect(window, ["Appearance", "Dark"], "06-restarted-dark")
            if json.loads(preference.read_text()).get("cw2.settings.themeMode") != "dark":
                raise RuntimeError("Appearance was not retained across launcher restart.")
            restarted = luminance(window)
            verify_dark_rendering(light, dark, restarted)
            report["rendered_theme_luminance"] = {"light": light, "dark": dark, "restarted_dark": restarted}
            click(window, "Shortcuts")
            expect(window, ["Search shortcuts"], "07-shortcuts")
            click(window, "App Logs")
            expect(window, ["Enable app logging", "Logging is disabled"], "08-logs")
            click(window, "Release history")
            expect(window, ["Refresh"], "09-history")
            report["public_changelog_read"] = "page activated; fixed public read-only source; loaded notes not claimed"
            run(["xdotool", "windowsize", window, "480", "800"])
            deadline = time.monotonic() + 10
            while not compact_geometry(run(["xdotool", "getwindowgeometry", "--shell", window])):
                if time.monotonic() >= deadline:
                    raise RuntimeError("Requested compact native window geometry was not applied.")
                time.sleep(0.2)
            report["checks"].append("compact-window-480x800")
            run(["xdotool", "key", "--clearmodifiers", "Escape"])
            expect(window, ["Appearance", "App Logs"], "10-compact-list", absent=["Visual style"])
            click(window, "Appearance")
            expect(window, ["Visual style", "Dark", "Light"], "11-compact-appearance", absent=["App Logs", "Shortcuts"])
            run(["xdotool", "key", "--clearmodifiers", "Escape"])
            expect(window, ["Appearance", "App Logs"], "12-compact-back", absent=["Visual style"])
            preview.stop_owned(process, timeout=30)
            if preview.digest(sentinel) != before:
                raise RuntimeError("Synthetic v1 preferences changed.")
            allowed = {str(sentinel.relative_to(host))}
            actual = {str(path.relative_to(host)) for path in host.rglob("*") if path.is_file()}
            if actual != allowed:
                raise RuntimeError("Preview wrote into synthetic installed-v1 HOME.")
            secret_check = json.loads((profile / "state/private-credential-check.json").read_text())
            if not secret_check["synthetic_roundtrip"] or secret_check["bus_address"] == os.environ.get("DBUS_SESSION_BUS_ADDRESS"):
                raise RuntimeError("Private credential-session proof is absent.")
            if Path(secret_check["keyring_data"]).exists():
                raise RuntimeError("Ephemeral keyring files remained after closing the launcher.")
            if preview.digest(archive_path) != checksum:
                raise RuntimeError("Delivered archive changed during smoke.")
            report["checks"].extend(["v1-sentinel-preserved", "private-credentials-roundtrip", "ephemeral-keyring-cleaned", "same-archive-bytes"])
            report["native_visual"] = "pass"
        finally:
            preview.stop_owned(process, timeout=30)
            log = profile / "state/last-launch.log"
            if log.is_file():
                (evidence / "native-launch.log").write_text(sanitized(log.read_text(errors="replace")))
            snapshot.unlink(missing_ok=True)
            (evidence / "report.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report), flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--archive", required=True, type=Path)
    parser.add_argument("--evidence", required=True, type=Path)
    args = parser.parse_args()
    smoke(args.archive.resolve(), args.evidence.resolve())


if __name__ == "__main__":
    main()
