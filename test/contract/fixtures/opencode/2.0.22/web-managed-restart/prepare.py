"""Pinned public artifact admission. No native service is started here."""
import base64
import hashlib
import io
import json
import os
from pathlib import Path, PurePosixPath
import re
import subprocess
import sys
import tarfile
import time
import urllib.request

root = Path(__file__).resolve().parent
assert re.fullmatch(r"/tmp/opencode/codewalk-sp04-managed-[A-Za-z0-9-]+", str(root))
os.umask(0o077)
started = time.time()
url = "https://registry.npmjs.org/@opencode%2fcli-linux-arm64/2.0.22"
with urllib.request.urlopen(url, timeout=30) as response:
    metadata = json.load(response)
dist = metadata["dist"]
expected_url = "https://registry.npmjs.org/@opencode/cli-linux-arm64/-/cli-linux-arm64-2.0.22.tgz"
assert metadata["name"] == "@opencode/cli-linux-arm64" and metadata["version"] == "2.0.22"
assert dist["tarball"] == expected_url
if "--verify-existing" in sys.argv:
    archive = (root / "official-2.0.22.tgz").read_bytes()
else:
    with urllib.request.urlopen(expected_url, timeout=60) as response:
        archive = response.read(300 * 1024 * 1024)
assert dist["integrity"] == "sha512-" + base64.b64encode(hashlib.sha512(archive).digest()).decode()
assert hashlib.sha256(archive).hexdigest() == "49e5466de60f65001cddd7583419f842140697daead2b4d8826be54d9056e70b"
with tarfile.open(fileobj=io.BytesIO(archive), mode="r:gz") as tar:
    members = tar.getmembers()
    assert len({m.name for m in members}) == len(members)
    for member in members:
        path = PurePosixPath(member.name)
        assert not path.is_absolute() and ".." not in path.parts
        assert path.parts[0] == "package" and member.isfile()
    executable = tar.extractfile("package/bin/opencode")
    assert executable is not None, "missing regular executable member"
    binary = executable.read()
    assert hashlib.sha256(binary).hexdigest() == "f27539d9c05c970d3eb9ad6a7724b75d3e638932c5423554f5ecbfe0ee2e8815"
(root / "package/bin").mkdir(parents=True, mode=0o700, exist_ok=True)
(root / "package/bin/opencode").write_bytes(binary)
(root / "package/bin/opencode").chmod(0o700)
(root / "official-2.0.22.tgz").write_bytes(archive)
runtime = root / "runtime"
for name in ["home", "config", "data", "cache", "state", "tmp", "run", "project"]:
    (runtime / name).mkdir(parents=True, mode=0o700, exist_ok=True)
env = {"PATH": "/usr/bin:/bin", "HOME": str(runtime / "home"), "LANG": "C.UTF-8",
       **{f"XDG_{k}_HOME": str(runtime / k.lower()) for k in ["CONFIG", "DATA", "CACHE", "STATE"]},
       "XDG_RUNTIME_DIR": str(runtime / "run"), "TMPDIR": str(runtime / "tmp"),
       "OPENCODE_DISABLE_MODELS_FETCH": "1", "OPENCODE_CONFIG_PROJECT_DISABLE": "1",
       "OPENCODE_FILEWATCHER_DISABLE": "1", "OPENCODE_DISABLE_FFF": "1"}
result = subprocess.run([str(root / "package/bin/opencode"), "--version"], env=env,
                        cwd=runtime / "project", capture_output=True, text=True, timeout=30, check=True)
assert result.stdout.strip() == "opencode v2.0.22", "unexpected runtime version"
admission = {"preparedAt": started, "npmMetadataURL": url, "archiveURL": expected_url,
             "npmIntegrity": dist["integrity"], "archiveSHA256": hashlib.sha256(archive).hexdigest(),
             "binarySHA256": hashlib.sha256(binary).hexdigest(), "nativeVersion": "2.0.22",
             "safeRegularMembers": len(members), "env": env, "budgetSeconds": 1200}
(root / "admission.json").write_text(json.dumps(admission, indent=2) + "\n")
print(json.dumps({"admission": "pass", "version": "2.0.22", "safeMembers": len(members),
                  "elapsedSeconds": round(time.time() - started)}))
