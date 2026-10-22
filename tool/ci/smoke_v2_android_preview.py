#!/usr/bin/env python3
"""Install and launch the preview's x86_64 split on a booted Android emulator.

The delivered arm64-v8a split cannot run on an x86_64 emulator; its x86_64
sibling from the same build is launched instead, and the report says so.
"""

import argparse
import json
from pathlib import Path
import re
import subprocess
import sys
import time

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from tool.ci import build_v2_native as native

SPLIT = "build/app/outputs/flutter-apk/" + native.PREVIEW_APKS["x86_64"]
# A blank or single-colour frame has almost no spread; a drawn screen has text,
# icons and surfaces. Only the middle of the screen is measured, so the system
# bars cannot pass for the app's own drawing.
MIN_SPREAD = 0.02
APP_REGION = "100%x80%+0+0"


def run(command, *, timeout=60):
    return subprocess.run(command, check=True, text=True, capture_output=True, timeout=timeout).stdout


def same_build(apk, evidence):
    """The launched split is the one the preview build recorded."""
    metadata = json.loads(evidence.read_text())
    if metadata.get("target") != "android-preview" or metadata.get("compiler") != "pass":
        raise RuntimeError("A verified preview build record is required.")
    if metadata.get("artifacts_sha256", {}).get(SPLIT) != native.sha256(apk):
        raise RuntimeError("The launched APK is not the split the preview build recorded.")
    return metadata


def crash_lines(logcat, package):
    """Lines that show the app crashed or Flutter reported an unhandled error.

    A crash of another process on the emulator is not the preview's: a Java
    crash names the process on its `AndroidRuntime: Process:` line, a native
    one in its `>>> package <<<` tombstone header.
    """
    lines = []
    for line in logcat.splitlines():
        if ("AndroidRuntime" in line and package in line) or f">>> {package} <<<" in line:
            lines.append(line)
        elif "flutter" in line and "Unhandled Exception" in line:
            lines.append(line)
    return lines


def in_front(activities, package):
    """The preview is the resumed activity (`mResumedActivity` before Android
    10, `topResumedActivity` since)."""
    return re.search(rf"ResumedActivity.*\b{re.escape(package)}/", activities) is not None


def rendered(spread):
    if spread < MIN_SPREAD:
        raise RuntimeError(f"The launched preview drew no screen (spread {spread:.4f}).")


def smoke(apk, evidence_json, evidence, wait_seconds=20):
    evidence.mkdir(parents=True, exist_ok=True)
    metadata = same_build(apk, evidence_json)
    package, activity = native.PREVIEW_APPLICATION_ID, native.PREVIEW_ACTIVITY
    report = {"source_commit": metadata.get("source_commit"), "apk_sha256": native.sha256(apk),
              "abi": "x86_64", "delivered_abi_launched": False, "package": package,
              "checks": [], "launch": "fail"}
    try:
        report["device_sdk"] = run(["adb", "shell", "getprop", "ro.build.version.sdk"]).strip()
        run(["adb", "install", "-r", str(apk)], timeout=240)
        if f"package:{package}" not in run(["adb", "shell", "pm", "list", "packages", package]).split():
            raise RuntimeError("The preview package is not installed.")
        report["checks"].append("installed-as-preview-package")
        run(["adb", "logcat", "-c"])
        started = run(["adb", "shell", "am", "start", "-W", "-n", f"{package}/{activity}"], timeout=120)
        if "Status: ok" not in started:
            raise RuntimeError(f"The preview activity did not start: {started.strip()}")
        report["checks"].append("activity-started")
        time.sleep(wait_seconds)
        pid = run(["adb", "shell", "pidof", package]).strip()
        if not pid:
            raise RuntimeError("The preview process is not running after launch.")
        report["pid"] = pid
        report["checks"].append("process-alive")
        if not in_front(run(["adb", "shell", "dumpsys", "activity", "activities"]), package):
            raise RuntimeError("The preview is not the activity in front.")
        report["checks"].append("activity-in-front")
        screen = evidence / "screen.png"
        screen.write_bytes(subprocess.run(["adb", "exec-out", "screencap", "-p"], check=True,
                                          capture_output=True, timeout=60).stdout)
        spread = float(run(["convert", str(screen), "-gravity", "center", "-crop", APP_REGION,
                            "+repage", "-colorspace", "Gray", "-format",
                            "%[fx:standard_deviation]", "info:"]))
        report["screen_spread"] = spread
        rendered(spread)
        report["checks"].append("screen-rendered")
        logcat = run(["adb", "logcat", "-d", "-v", "threadtime"], timeout=60)
        (evidence / "logcat.txt").write_text(logcat)
        crashes = crash_lines(logcat, package)
        if crashes:
            raise RuntimeError("The preview crashed or reported an error: " + crashes[0])
        report["checks"].append("no-crash-in-logcat")
        report["launch"] = "pass"
    finally:
        (evidence / "report.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report), flush=True)
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apk", required=True, type=Path)
    parser.add_argument("--build-evidence", required=True, type=Path)
    parser.add_argument("--evidence", required=True, type=Path)
    args = parser.parse_args()
    smoke(args.apk.resolve(), args.build_evidence.resolve(), args.evidence.resolve())


if __name__ == "__main__":
    main()
