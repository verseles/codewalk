"""Controlled offline build: bind reviewed inputs to the bytes actually compiled."""
import hashlib
import json
from pathlib import Path
import subprocess
import time

root = Path(__file__).resolve().parent
app = root / 'app'
manifest = root / 'build-provenance.json'
manifest.unlink(missing_ok=True)
inputs = [app / 'lib/main.dart', app / 'pubspec.yaml', app / 'pubspec.lock',
          *sorted((app / 'web').rglob('*'))]
inputs = [p for p in inputs if p.is_file()]


def hashes():
    return {str(p.relative_to(app)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in inputs}


before = hashes()
started = time.time()
analyze = ['rtk', 'proxy', 'flutter', 'analyze', '--no-pub']
command = ['rtk', 'proxy', 'flutter', 'build', 'web', '--release', '--no-pub',
           '--no-web-resources-cdn']
subprocess.run(analyze, cwd=app, check=True, timeout=180)
subprocess.run(command, cwd=app, check=True, timeout=360)
assert hashes() == before, 'compile inputs changed during build'
js = hashlib.sha256((app / 'build/web/main.dart.js').read_bytes()).hexdigest()
proof = {'inputsSHA256': before, 'buildSHA256': js, 'argv': command,
         'analyzeArgv': analyze, 'startedAt': started, 'finishedAt': time.time()}
manifest.write_text(json.dumps(proof, indent=2) + '\n')
print(json.dumps({'controlledBuild': 'pass', 'sourceSHA256': before['lib/main.dart'],
                  'buildSHA256': js, 'elapsedSeconds': round(time.time() - started)}))
