#!/usr/bin/env python3
"""Offline observed-fixture checks. Read-only unless --write-report is supplied."""
import argparse
import base64
import datetime
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent
checks = {}


def read(name):
    return json.loads((ROOT / name).read_text())


def check(name, condition):
    if not condition:
        raise AssertionError(name)
    checks[name] = 'passed'


def call(fixture, name):
    values = [entry for entry in fixture['calls'] if entry['name'] == name]
    check('uniqueCall:' + name, len(values) == 1)
    return values[0]


def events(fixture, kind):
    return [e for e in fixture['stream']['events'] if e['type'] == kind]


def users(fixture):
    return [m for m in fixture['state']['history']['data'] if m['type'] == 'user']


def zero_cost(model):
    return model['providerID'] == 'opencode' and model['enabled'] and bool(model['cost']) and all(
        p['input'] == p['output'] == p['cache']['read'] == p['cache']['write'] == 0 for p in model['cost'])


def audit(value):
    if isinstance(value, dict):
        for key, item in value.items():
            if key.lower() in {'password', 'token', 'authorization', 'apikey', 'api_key', 'access_token', 'refresh_token', 'client_secret', 'providerstate', 'providerresultstate', 'providercontext'}:
                check('noCredentialOrOpaqueState:' + key, item == '[REDACTED]')
            if key == 'state' and value.get('type') in {'text', 'reasoning'}:
                check('noOpaqueContentState', item == '[REDACTED]')
            audit(item)
    elif isinstance(value, list):
        for item in value:
            audit(item)


def validate():
    provenance = read('provenance.json')
    required = set(provenance['fixtureSha256'])
    manifest = {}
    for line in (ROOT / 'SHA256SUMS').read_text().splitlines():
        digest, name = line.split('  ', 1)
        check('manifestSafePath:' + name, Path(name).name == name)
        check('manifestDigest:' + name, hashlib.sha256((ROOT / name).read_bytes()).hexdigest() == digest)
        manifest[name] = digest
    check('fixtureHashMapComplete', all(manifest.get(name) == digest for name, digest in provenance['fixtureSha256'].items()))
    check('manifestIncludesProvenance', 'provenance.json' in manifest)
    check('unlistedArtifactsAbsent', {p.name for p in ROOT.iterdir() if p.is_file()} - set(manifest) <= {'SHA256SUMS', 'validation.json'})
    check('versionAndTopology', provenance['serverVersion'] == '2.0.22' and provenance['platform'] == 'Linux x86_64')
    for path in ROOT.glob('*.json'):
        if path.name != 'validation.json':
            audit(read(path.name))
    service = read('service-credentials.json')
    check('supportedCredentialCommand', service['retrievalCommand'][-3:] == ['service', 'get', 'password'])
    check('credentialMemoryOnly', service['credentialReturnedOnlyInMemory'])
    info = call(service, 'ServicePasswordAuthenticatedInfo')
    check('passwordAuthenticatesNativeVersion', info['status'] == 200 and info['response']['version'] == '2.0.22')
    check('noCredentialRejected', call(service, 'NoCredentialInfo')['status'] == 401)
    check('nativeCredentialFileModesPrivate', service['registrationMode'] == service['configMode'] == '0o600')
    check('freeModelsEnabled', zero_cost(read('model.json')) and zero_cost(read('model-pdf.json')))
    check('declaredInputModalities', 'image' in read('model.json')['capabilities']['input'] and 'pdf' in read('model-pdf.json')['capabilities']['input'])

    durable = read('durable-log.json')
    renamed = [e for e in durable['globalStream']['events'] if e['type'] == 'session.renamed']
    check('twoAuthoritativeNativeRenames', len(renamed) == 2 and [e['durable']['seq'] for e in renamed] == [1, 2]
          and all(e['durable']['aggregateID'] == durable['sessionID'] for e in renamed))
    check('renamedProjectionMatchesLive', call(durable, 'ReadRenamedSession')['response']['data']['title'] == renamed[0]['data']['title']
          and call(durable, 'ReadTwiceRenamedSession')['response']['data']['title'] == renamed[1]['data']['title'])
    check('defaultZeroKnownCursorsObserved', len(durable['logReads']) == 3 and durable['observedWatermark'] == 1
          and any('after=0' in r['path'] for r in durable['logReads'])
          and any('after=1' in r['path'] for r in durable['logReads']))
    check('durableLogWatermarkOnly', all(r['status'] == 200 and r['events'] == [{'type': 'log.synced', 'aggregateID': durable['sessionID'], 'seq': 1}]
          for r in durable['logReads']))
    check('followMissingConfirmedLiveRename', durable['followStream']['events'] == [{'type': 'log.synced', 'aggregateID': durable['sessionID'], 'seq': 1}]
          and durable['followStream']['status'] == 200 and len(renamed) == 2)
    check('durableReplayUnavailableFallback', durable['capability'] == 'unavailable' and provenance['capabilities']['durableLog'] == 'unavailable')
    source = read('source-evidence.json')
    check('staticPersistenceDefaultEvidence', any('persist = options?.persist ?? false' in line['text']
          for line in source['sources']['packages/core/src/bus.ts']['excerpts']))
    check('pdfForwardingPresentBothPins', source['olderPdfForwarding']['containsPdfForwarding']
          and any('file.mime === "application/pdf"' in line['text'] for line in source['sources']['packages/core/src/session/runner/to-llm-message.ts']['excerpts']))

    fs = read('filesystem.json')
    boundary = Path(fs['projectDirectory']).parent
    writes = fs['writes']
    check('normalWriteWithinProject', writes[0]['name'] == 'NormalWrite' and writes[0]['insideProjectAfter'])
    check('traversalAbsoluteSymlinkActuallyEscape', [r['name'] for r in writes[1:]] == ['TraversalWrite', 'AbsoluteWrite', 'SymlinkWrite']
          and all(not r['insideProjectAfter'] and r['actualBytes'] == r['expectedBytes'] and r['status'] == 200 for r in writes[1:]))
    check('allWriteTargetsInsideOwnedDisposableSpace', all(Path(r['realPathAfter']).is_relative_to(boundary) for r in writes))
    check('rawBodyMatchesActualWrite', all(call(fs, r['name'])['requestRawSha256'] == hashlib.sha256(r['actualBytes'].encode()).hexdigest() for r in writes))
    race = fs['toctou']
    check('boundedRealAtomicReplacements', 0 < len(race['writes']) <= 100 and race['atomicLinkReplacements'] > 0)
    check('toctouPrecheckedInternalPaths', all(Path(r['resolvedBeforeWithinProject']).is_relative_to(Path(fs['projectDirectory'])) for r in race['writes']))
    escapes = [r for r in race['writes'] if r['outsideExists']]
    check('toctouEscapeActuallyWritten', len(escapes) == race['outsideWriteCount'] > 0 and all(r['outsideBytes'] == r['marker'] and r['status'] == 200 for r in escapes))
    check('writeContainmentUnavailable', fs['writeCapability'] == provenance['capabilities']['filesWrite'] == 'unavailable')
    check('normalReadMatchesFile', call(fs, 'ReadInternal')['response']['rawUtf8'] == writes[0]['actualBytes'])
    check('symlinkAndTraversalReadsRejected', call(fs, 'ReadSymlinkOutside')['status'] == call(fs, 'ReadTraversalOutside')['status'] == 500)
    check('outsideListingIsExplicitNativeSurface', call(fs, 'ListOutsideSibling')['status'] == 200
          and all(e['path'].startswith('../outside/') for e in call(fs, 'ListOutsideSibling')['response']['data']))

    png = read('attachment-png.json')
    pdf = read('attachment-pdf.json')
    for item in (png, pdf):
        kind = item['kind']
        content = (ROOT / ('attachment.' + kind)).read_bytes()
        check(kind + 'AttachmentDigest', hashlib.sha256(content).hexdigest() == item['attachmentSha256'] and len(content) == item['decodedBytes'])
        admission = call(item, 'AttachmentPromptAdmission')
        uri = admission['request']['files'][0]['uri']
        check(kind + 'InlineRequestMatchesFile', base64.b64decode(uri.split(',', 1)[1]) == content)
        check(kind + 'NativeAdmissionAndMime', admission['status'] == 200 and users(item)[0]['files'][0]['mime'] == item['mime'])
        check(kind + 'MarkerOnlyInAttachment', item['markerWasAbsentFromPromptText'] and item['expectedAttachmentOnlyMarker'] not in admission['request']['text'])
        check(kind + 'NoToolCouldReadMarker', item['assistantToolCount'] == 0 and not any(e['type'] == 'session.tool.called' for e in item['stream']['events'])
              and item['state']['session']['data']['permissions'] == [{'action': '*', 'resource': '*', 'effect': 'deny'}])
        check(kind + 'OneProviderStep', len(events(item, 'session.step.started')) == item['observedProviderStepCount'] == 1)
        check(kind + 'ZeroSessionCost', item['state']['session']['data']['cost'] == 0)
    check('pngActuallyRecognizedByModel', png['modelReturnedExactMarker'] and png['assistantText'].strip() == png['expectedAttachmentOnlyMarker']
          and png['state']['session']['data']['outcome'] == 'succeeded')
    check('pdfProviderFailureNotDiscardClaim', not pdf['modelReturnedExactMarker'] and pdf['state']['session']['data']['outcome'] == 'failed'
          and any(e['data']['error']['type'] == 'provider.auth' and e['data']['error']['status'] == 403 for e in events(pdf, 'session.execution.failed')))
    check('productPdfDisabledPreserved', provenance['capabilities']['productPdf'] == 'disabled-approved-policy'
          and provenance['capabilities']['pdfModelRecognition'] == 'blocked-free-provider-auth403')

    cors = read('cors.json')
    allowed = call(cors, 'AllowedNativeInfoWithOrigin')
    denied = call(cors, 'DeniedNativeInfoWithOrigin')
    check('allowedNativeOriginHeader', allowed['status'] == 200 and allowed['responseHeaders']['access-control-allow-origin'] == allowed['requestOrigin'])
    check('deniedNativeOriginHasNoAllowHeader', denied['status'] == 200 and 'access-control-allow-origin' not in denied['responseHeaders'])
    check('preflightHeaderBoundary', call(cors, 'AllowedPreflight')['status'] == call(cors, 'DeniedPreflight')['status'] == 204
          and 'access-control-allow-origin' in call(cors, 'AllowedPreflight')['responseHeaders']
          and 'access-control-allow-origin' not in call(cors, 'DeniedPreflight')['responseHeaders'])
    browser = {r['name']: r for r in cors['browserResults']}
    check('chromiumAllowedInfoAndSse', browser['allowed']['info']['readable'] and browser['allowed']['info']['version'] == '2.0.22'
          and browser['allowed']['firstSseFrame']['readable'] and browser['allowed']['firstSseFrame']['firstType'] == 'server.connected')
    check('chromiumDeniedInfoAndSse', not browser['denied']['info']['readable'] and not browser['denied']['firstSseFrame']['readable'])
    check('serviceCorsNotReconfigured', not cors['nativeServiceConfigChanged'])

    bandwidth = read('loopback-bandwidth.json')
    check('threeActuallyConcurrentExecutions', len(bandwidth['sessionIDs']) == 3 and bandwidth['threeExecutionOverlapMs'] > 0)
    check('threeCompleteZeroCostTurns', bandwidth['allNativeTerminalObserved'] and all(state['session']['data']['outcome'] == 'succeeded'
          and state['session']['data']['cost'] == 0 and state['inbox']['data'] == [] for state in bandwidth['states'].values()))
    check('exactlyThreeProviderSteps', bandwidth['observedProviderStepCount'] == len(events(bandwidth, 'session.step.started')) == 3)
    check('oneStreamByteBoundary', bandwidth['stream']['path'] == '/api/event' and bandwidth['stream']['totalHttpBodyBytes'] >= bandwidth['stream']['ownedEventFrameBytes'] > 0)
    idle = read('loopback-idle.json')
    check('idleCommentsObserved', idle['durationSeconds'] >= 30 and len(idle['stream']['commentFrames']) >= 3
          and sum(f['bytes'] for f in idle['stream']['commentFrames']) == idle['stream']['heartbeatBytes'])
    check('cellularExplicitlyPending', provenance['capabilities']['cellularBandwidth'] == 'pending-resource' and 'not cellular' in bandwidth['transport'])
    cleanup = read('cleanup.json')
    check('finalOwnedSessionsAbsent', len(cleanup['ownedSessionIDs']) == 6 and all(c['status'] == 404 for c in cleanup['calls'] if c['name'] == 'DeletedOwnedSessionAbsent')
          and len([c for c in cleanup['calls'] if c['name'] == 'DeletedOwnedSessionAbsent']) == 6)
    check('noOwnedPendingInboxAtCleanup', all(state['inbox']['data'] == [] for state in cleanup['ownedStateBeforeDeletion'].values()))
    check('disposableFilesystemRestoredClean', cleanup['disposableProjectGitStatusAfterCleanup'] == '' and cleanup['outsideOwnedDirectoryEntriesAfterCleanup'] == [])
    check('sharedServiceNotRestarted', cleanup['nativeServiceProcessPreserved'] and not cleanup['sharedServiceReconfiguredOrRestarted'])
    check('findSettledTrackedAndNewFiles', any(e['path'] == 'baseline.txt' for e in call(cleanup, 'FindCommittedBaseline')['response']['data'])
          and any(e['path'] == 'inside/normal.txt' for e in call(cleanup, 'FindCreatedNormalAfterSettlement')['response']['data']))
    budget = read('provider-final-state.json')['budget']
    check('providerBudgetWithinSix', budget['submitted'] == budget['observedProviderSteps'] == 5 <= budget['limit'] == 6)
    check('nativeStepsMatchBudget', sum(item['observedProviderStepCount'] for item in (png, pdf, bandwidth)) == budget['observedProviderSteps'])
    check('executionWithinTimeBudget', provenance['actualElapsedSeconds'] <= provenance['timeBudgetSeconds'] == 5400)
    return {'validatedAt': datetime.datetime.now(datetime.timezone.utc).isoformat(), 'status': 'passed',
            'checkCount': len(checks), 'checks': checks, 'capabilities': provenance['capabilities'],
            'acceptanceBoundary': 'Observed Linux/Chromium subset with explicit unavailable/pending capabilities; not full V2-005E, cellular, cross-platform or product release acceptance.'}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--write-report', action='store_true', help='Opt in to writing derived validation.json')
    args = parser.parse_args()
    report = validate()
    if args.write_report:
        (ROOT / 'validation.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps({'status': report['status'], 'checkCount': report['checkCount'], 'writesPerformed': args.write_report}))
