"""Opt-in preparation for one private-peer capture; never modifies remote services."""
import hashlib
import math
import json
import os
from pathlib import Path
import re
import shutil
import signal
import subprocess
import tarfile
import tempfile
import time
import urllib.request

FIXTURE = Path(__file__).resolve().parent
ARCHIVE_SHA = '49e5466de60f65001cddd7583419f842140697daead2b4d8826be54d9056e70b'
BINARY_SHA = 'f27539d9c05c970d3eb9ad6a7724b75d3e638932c5423554f5ecbfe0ee2e8815'


def remaining(end, cap):
    seconds = end - time.monotonic()
    if seconds <= 0:
        raise TimeoutError('setup deadline')
    return min(cap, seconds)


def arm_deadline(end):
    def expired(*_):
        raise TimeoutError('setup deadline')
    left = remaining(end, 1200)
    previous = signal.signal(signal.SIGALRM, expired)
    signal.setitimer(signal.ITIMER_REAL, left)
    return previous


def sha(path):
    with path.open('rb') as f:
        return hashlib.file_digest(f, 'sha256').hexdigest()


def dart_source():
    dart = (FIXTURE.parent / 'web/flutter_main.dart.txt').read_text()
    assert dart.count("      sockets[o['socket']] = term;\n") == 1
    assert dart.count('      await term.open(url);\n') == 1
    dart = dart.replace("      sockets[o['socket']] = term;\n", '')
    dart = dart.replace('      await term.open(url);\n', "      await term.open(url);\n      sockets[o['socket']] = term;\n")
    assert dart.count("credentials: 'omit',") == 2
    dart = dart.replace("credentials: 'omit',", "credentials: 'omit',\n            redirect: 'error',")
    assert dart.count('    httpStatus = response.status;\n') == 1
    dart = dart.replace('    httpStatus = response.status;\n',
                        '    httpStatus = response.status;\n    if (httpStatus != 200) {\n      controller.abort();\n      return;\n    }\n')
    assert dart.count("'body': text.isEmpty ? null : jsonDecode(text),") == 1
    dart = dart.replace("'body': text.isEmpty ? null : jsonDecode(text),",
                        "'body': response.status == 200 && text.isNotEmpty ? jsonDecode(text) : null,")
    return dart


def prepare(inspect_version=False):
    preparation_started = time.monotonic()
    parent = Path('/tmp/opencode')
    assert parent.is_dir() and not parent.is_symlink()
    root = Path(tempfile.mkdtemp(prefix='codewalk-sp04-tailpeer-', dir=parent))
    os.chmod(root, 0o700)
    setup_end = preparation_started + 1200
    previous = arm_deadline(setup_end)
    try:
        for name in ['capture.mjs', 'cdp.mjs', 'budget.mjs', 'peer.py', 'serve_supervisor.py', 'validate.py']:
            shutil.copyfile(FIXTURE / name, root / name)
        app = root / 'app'
        (app / 'lib').mkdir(parents=True)
        (app / 'web').mkdir()
        (app / 'lib/main.dart').write_text(dart_source())
        for name in ['pubspec.yaml', 'pubspec.lock', 'web/index.html']:
            shutil.copyfile(FIXTURE.parent / 'web-managed-restart/app' / name, app / name)
        archive = root / 'opencode.tgz'
        # The accepted native producer is reused, not a moving latest package.
        with urllib.request.urlopen(
                'https://registry.npmjs.org/@opencode/cli-linux-arm64/-/cli-linux-arm64-2.0.22.tgz',
                timeout=remaining(setup_end, 60)) as response, archive.open('wb') as out:
            shutil.copyfileobj(response, out)
        assert sha(archive) == ARCHIVE_SHA
        with tarfile.open(archive) as source:
            members = source.getmembers()
            assert all(m.isfile() or m.isdir() for m in members)
            assert all(not Path(m.name).is_absolute() and '..' not in Path(m.name).parts for m in members)
            source.extractall(root, filter='data')
        binary = root / 'package/bin/opencode'
        assert sha(binary) == BINARY_SHA
        runtime = root / 'runtime'
        env = {'PATH': '/usr/bin:/bin', 'LANG': 'C.UTF-8'}
        for key, folder in [('HOME', 'home'), ('TMPDIR', 'tmp'),
                            *[(f'XDG_{k}_HOME', k.lower()) for k in ['CONFIG', 'DATA', 'CACHE', 'STATE']],
                            ('XDG_RUNTIME_DIR', 'run')]:
            path = runtime / folder
            path.mkdir(parents=True, mode=0o700)
            env[key] = str(path)
        (runtime / 'project').mkdir(mode=0o700)
        env.update(OPENCODE_DISABLE_MODELS_FETCH='1', OPENCODE_CONFIG_PROJECT_DISABLE='1',
                   OPENCODE_FILEWATCHER_DISABLE='1', OPENCODE_DISABLE_FFF='1')
        version = subprocess.run([str(binary), '--version'], env=env, cwd=runtime / 'project',
                                 check=True, capture_output=True, text=True, timeout=remaining(setup_end, 30)).stdout.strip()
        if inspect_version:
            print(json.dumps({'versionStdout': version, 'binarySHA256': sha(binary)}))
            shutil.rmtree(root)
            return
        assert version == 'opencode v2.0.22'
        help_text = subprocess.run([str(binary), 'serve', '--help'], env=env,
                                  cwd=runtime / 'project', check=True, capture_output=True,
                                   text=True, timeout=remaining(setup_end, 30)).stdout
        assert all(flag in help_text for flag in ['--hostname', '--port', '--cors'])
        inputs = [app / 'lib/main.dart', app / 'pubspec.yaml', app / 'pubspec.lock', app / 'web/index.html']
        before = {str(p.relative_to(app)): sha(p) for p in inputs}
        started = time.time()
        commands = [['rtk', 'proxy', 'flutter', 'pub', 'get', '--offline'],
                    ['rtk', 'proxy', 'flutter', 'analyze', '--no-pub'],
                    ['rtk', 'proxy', 'flutter', 'build', 'web', '--release', '--no-pub', '--no-web-resources-cdn']]
        for command in commands:
            subprocess.run(command, cwd=app, check=True, timeout=remaining(setup_end, 360))
        assert {str(p.relative_to(app)): sha(p) for p in inputs} == before
        proof = {'inputsSHA256': before, 'buildSHA256': sha(app / 'build/web/main.dart.js'),
                 'argv': commands, 'startedAt': started, 'finishedAt': time.time()}
        (root / 'build-provenance.json').write_text(json.dumps(proof, indent=2) + '\n')
        remaining(setup_end, 1200)
        (root / 'admission.json').write_text(json.dumps({
            'binarySHA256': BINARY_SHA, 'archiveSHA256': ARCHIVE_SHA,
            'sourceSHA256': before['lib/main.dart'], 'captureSeconds': 180,
            'budgetSeconds': 1200, 'cleanupSeconds': 120,
            'preparationElapsedSeconds': math.ceil(time.monotonic() - preparation_started),
        }, indent=2) + '\n')
        print(json.dumps({'preparedRoot': str(root), 'version': '2.0.22', 'cliVersionStdout': version,
                          'sourceSHA256': before['lib/main.dart'], 'buildSHA256': proof['buildSHA256']}))
    except BaseException:
        signal.setitimer(signal.ITIMER_REAL, 0)
        shutil.rmtree(root)
        raise
    finally:
        signal.setitimer(signal.ITIMER_REAL, 0)
        signal.signal(signal.SIGALRM, previous)


def refresh(root):
    assert re.fullmatch(r'/tmp/opencode/codewalk-sp04-tailpeer-[a-z0-9_-]+', str(root))
    assert root.resolve() == root and not root.is_symlink()
    assert root.stat().st_uid == os.getuid() and root.stat().st_mode & 0o777 == 0o700
    assert not (root / 'evidence/capture.json').exists(), 'captured source is immutable'
    admission = json.loads((root / 'admission.json').read_text())
    assert sha(root / 'package/bin/opencode') == BINARY_SHA == admission['binarySHA256']
    assert sha(root / 'app/lib/main.dart') == admission['sourceSHA256']
    proof = json.loads((root / 'build-provenance.json').read_text())
    assert sha(root / 'app/build/web/main.dart.js') == proof['buildSHA256']
    for path, expected in proof['inputsSHA256'].items():
        assert sha(root / 'app' / path) == expected
    for name in ['capture.mjs', 'cdp.mjs', 'budget.mjs', 'peer.py', 'serve_supervisor.py', 'validate.py']:
        shutil.copyfile(FIXTURE / name, root / name)
    # This legacy admission was completed in <180s (recorded tester operation).
    # Debit a conservative upper bound, not invented preparation duration.
    if 'preparationElapsedSeconds' not in admission:
        admission['preparationElapsedSeconds'] = 180
        admission['preparationDebitIsConservativeBound'] = True
    (root / 'admission.json').write_text(json.dumps(admission, indent=2) + '\n')
    print(json.dumps({'refreshedRoot': str(root), 'compiledInputsUnchanged': True}))


def rebuild(root):
    # Admission and old hashes must still match before replacing owned inputs.
    started = time.monotonic()
    assert re.fullmatch(r'/tmp/opencode/codewalk-sp04-tailpeer-[a-z0-9_-]+', str(root))
    assert root.resolve() == root and not root.is_symlink()
    assert root.stat().st_uid == os.getuid() and root.stat().st_mode & 0o777 == 0o700
    assert not (root / 'evidence/capture.json').exists(), 'captured source is immutable'
    admission = json.loads((root / 'admission.json').read_text())
    debit = admission.get('preparationElapsedSeconds', 180)
    assert type(debit) is int and 0 < debit < 1200
    setup_end = started + 1200 - debit
    previous = arm_deadline(setup_end)
    try:
        refresh(root)
        admission = json.loads((root / 'admission.json').read_text())
        assert admission['preparationElapsedSeconds'] == debit
        (root / 'app/lib/main.dart').write_text(dart_source())
        wall_started = time.time()
        unchanged = {name: sha(root / 'app' / name) for name in ['pubspec.yaml', 'pubspec.lock', 'web/index.html']}
        pub = ['rtk', 'proxy', 'flutter', 'pub', 'get', '--offline']
        subprocess.run(pub, cwd=root / 'app', check=True, timeout=remaining(setup_end, 120))
        assert {name: sha(root / 'app' / name) for name in unchanged} == unchanged
        shutil.copyfile(FIXTURE.parent / 'web-managed-restart/build.py', root / 'build.py')
        subprocess.run(['rtk', 'proxy', 'python3', '-B', str(root / 'build.py')],
                       check=True, timeout=remaining(setup_end, 600))
        admission['sourceSHA256'] = sha(root / 'app/lib/main.dart')
        admission['preparationElapsedSeconds'] += math.ceil(time.monotonic() - started)
        remaining(setup_end, 1200)
        (root / 'admission.json').write_text(json.dumps(admission, indent=2) + '\n')
        proof = json.loads((root / 'build-provenance.json').read_text())
        proof['argv'] = [pub, proof['analyzeArgv'], proof['argv']]
        proof['startedAt'] = wall_started
        (root / 'build-provenance.json').write_text(json.dumps(proof, indent=2) + '\n')
        print(json.dumps({'rebuiltRoot': str(root), 'sourceSHA256': admission['sourceSHA256'],
                          'buildSHA256': proof['buildSHA256']}))
    finally:
        signal.setitimer(signal.ITIMER_REAL, 0)
        signal.signal(signal.SIGALRM, previous)


if __name__ == '__main__':
    import sys
    if len(sys.argv) == 3 and sys.argv[1] == '--refresh-root':
        refresh(Path(sys.argv[2]))
    elif len(sys.argv) == 3 and sys.argv[1] == '--rebuild-root':
        rebuild(Path(sys.argv[2]))
    else:
        assert sys.argv[1:] in [['--prepare'], ['--inspect-version']], 'preparation needs explicit admission'
        prepare(inspect_version=sys.argv[1:] == ['--inspect-version'])
