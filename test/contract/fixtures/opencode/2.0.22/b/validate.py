#!/usr/bin/env python3
"""Validate relationships in observed B fixtures without contacting a server."""
from collections import Counter
import datetime
import hashlib
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parent
read = lambda name: json.loads((ROOT / name).read_text())
checks = {}


def check(name, condition):
    if not condition:
        raise AssertionError(name)
    checks[name] = 'passed'


def call(fixture, name):
    matches = [entry for entry in fixture['calls'] if entry['name'] == name]
    if len(matches) != 1:
        raise AssertionError('exactly one call: ' + name)
    return matches[0]


def data(fixture, name):
    return call(fixture, name)['response']['data']


def history_users(fixture, name):
    return [message for message in data(fixture, name) if message['type'] == 'user']


create = read('create-matrix.json')
prompt = read('prompt-matrix.json')
cancel = read('cancel-matrix.json')
queue = read('queue-steer-space-bunny.json')
interrupt = read('interrupt-resume.json')
reconnect = read('disconnect-reconnect.json')
restart = read('service-restart.json')
denial = read('queue-steer-fledge-policy-denial.json')
probe = read('shell-probe-space-bunny.json')
runtime = read('runtime.json')
space = read('model-space-bunny-free.json')

check('connectedVersion', runtime['connectedInfo']['version'] == '2.0.22')
check('enabledZeroCostModel', space['enabled'] and space['providerID'] == 'opencode'
      and all(cost['input'] == cost['output'] == 0 for cost in space['cost']))
original = data(create, 'createReplayCreate')
check('createSameIdSamePayloadReturnsOriginal', data(create, 'identicalCreateReplay') == original)
check('createChangedPayloadReturnsOriginal', data(create, 'changedPayloadCreateReplay') == original
      and call(create, 'changedPayloadCreateReplay')['request']['title'] != original['title'])
check('createBeforeAdmissionAbsent', call(create, 'beforeCreateAuthoritativeAbsent')['status'] == 404)
check('createBeforeAdmissionRetrySucceeds', call(create, 'beforeCreateSameIdRetry')['status'] == 200)
check('createLostResponseReconciles', data(create, 'afterCreateNativeForward')
      == data(create, 'afterCreateAuthoritativePresent') == data(create, 'afterCreateSameIdReplay'))
for fixture, kind in [(create, 'create'), (prompt, 'prompt')]:
    before, after = fixture['networkControls']
    check(kind + 'TimeoutBeforeForwarding', before['clientOutcome'] == 'TimeoutError'
          and not before['forwardedToNative'])
    check(kind + 'TimeoutAfterNativeAdmission', after['clientOutcome'] == 'TimeoutError'
          and after['forwardedToNative'] and after['nativeStatus'] == 200)
admission = data(prompt, 'promptOriginal')
check('samePromptIdReplayReturnsOriginal', data(prompt, 'promptIdenticalReplay') == admission)
check('changedTextSameIdKeepsOriginal', data(prompt, 'promptChangedTextReplay') == admission
      and call(prompt, 'promptChangedTextReplay')['request']['text'] != admission['payload']['text'])
check('changedDeliverySameIdKeepsOriginal', data(prompt, 'promptChangedDeliveryReplay') == admission
      and call(prompt, 'promptChangedDeliveryReplay')['request']['delivery'] != admission['delivery'])
check('promptCrossSessionIdentityConflict', call(prompt, 'promptCrossSessionConflict')['status'] == 409
      and call(prompt, 'promptCrossSessionConflict')['response']['_tag'] == 'ConflictError')
check('identicalTextNewIdIsDistinctAdmission', data(prompt, 'sameTextNewId')['id'] != admission['id']
      and data(prompt, 'sameTextNewId')['payload']['text'] == admission['payload']['text'])
before_id = prompt['networkControls'][0]['request']['id']
check('promptBeforeAdmissionAbsent', before_id not in {item['id'] for item in data(prompt, 'beforePromptBeforeRetryinbox')})
check('promptBeforeAdmissionRetrySucceeds', call(prompt, 'beforePromptSameIdRetry')['status'] == 200)
after_id = prompt['networkControls'][1]['request']['id']
check('promptLostResponseReconciles', after_id in {item['id'] for item in data(prompt, 'afterPromptBeforeRetryinbox')}
      and data(prompt, 'afterPromptNativeForward') == data(prompt, 'afterPromptSameIdReplay'))
check('resumeFalseDoesNotProjectUserHistory', not history_users(prompt, 'allAdmissionsParkedhistory'))
check('pendingCancelAndRepeatNoOp', call(cancel, 'cancelPending')['status'] == call(cancel, 'cancelAgainNoOp')['status'] == 204)
recreated = data(cancel, 'replayCancelledId')
check('replayCancelledIdReEnqueues', recreated['id'] == admission['id']
      and recreated['id'] in {item['id'] for item in data(cancel, 'cancelledReplayStateinbox')})
matrix_events = read('matrix-events.json')['events']
check('cancelledReplayHasSecondEnqueueEvent', len([e for e in matrix_events if e['type'] == 'session.inbox.enqueued'
      and e['data']['inboxID'] == admission['id']]) == 2)
cancel_lifecycle = [e for e in matrix_events if e.get('data', {}).get('inboxID') == admission['id']]
check('cancelledReplayObservedLifecycleOrder', [(e['type'], e['durable']['seq']) for e in cancel_lifecycle[:3]]
      == [('session.inbox.enqueued', 1), ('session.inbox.cancelled', 5), ('session.inbox.enqueued', 6)]
      and all(e['durable']['aggregateID'] == admission['sessionID'] for e in cancel_lifecycle[:3]))

ids = queue['promptIds']
sid = data(queue, 'liveQueueSteerCreate')['id']
check('activeOwnedExecutionObserved', sid in data(queue, 'activeWhileToolRunning'))
check('pendingDeliveryChangesAndCancellation', call(queue, 'changePendingQueueToSteer')['status'] == 204
      and call(queue, 'cancelWhileExecuting')['status'] == 204)
users = history_users(queue, 'afterQueueSteerExecutionhistory')
check('steeringBeforeQueuedNextTurnPromotion', [m['id'] for m in users] == [ids['first'], ids['changed'], ids['steered'], ids['queued']])
check('cancelledInputNotDelivered', ids['cancelled'] not in {m['id'] for m in users})
check('inboxEmptyAfterDelivery', data(queue, 'afterQueueSteerExecutioninbox') == [])
check('executionSucceededAfterQueueAndSteer', data(queue, 'afterQueueSteerExecutionsession')['outcome'] == 'succeeded'
      and any(e['type'] == 'session.execution.succeeded' for e in queue['stream']['events']))
check('inactiveAfterCompletion', sid not in data(queue, 'activeAfterQueueSteerExecution'))
check('promotedUserReplayUsesOriginalPayload', data(queue, 'replayPromotedUserChangedPayload')['payload']['text'] == users[0]['text'])
check('deliveredCancelNoOpAndPatchConflict', call(queue, 'cancelDeliveredNoOp')['status'] == 204
      and call(queue, 'changeDeliveredConflict')['status'] == 409)
check('deliveredReplayDoesNotDuplicateHistory', data(queue, 'afterDeliveredReplayhistory') == data(queue, 'afterQueueSteerExecutionhistory'))
promoted_delivery = read('promoted-delivery-replay.json')
check('promotedReplayEchoesRequestedDelivery', call(promoted_delivery, 'promotedQueuedIdChangedDelivery')['status'] == 200
      and data(promoted_delivery, 'promotedQueuedIdChangedDelivery')['delivery'] == 'steer'
      and promoted_delivery['originalAdmission']['data']['delivery'] == 'queue')
check('promotedDeliveryEchoDoesNotRewriteHistory', data(promoted_delivery, 'afterPromotedDeliveryReplayhistory')
      == data(queue, 'afterQueueSteerExecutionhistory'))

isid = data(interrupt, 'interruptResumeCreate')['id']
check('interruptOwnedActiveExecution', isid in data(interrupt, 'activeBeforeInterrupt')
      and call(interrupt, 'interruptAndResumeSteering')['response']['interrupted'])
check('nativeUserInterruptionEvent', any(e['type'] == 'session.execution.interrupted'
      and e['data']['reason'] == 'user' for e in interrupt['stream']['events']))
check('interruptResumeSteeringSucceeds', interrupt['resumedSucceededObserved']
      and data(interrupt, 'afterInterruptResumesession')['outcome'] == 'succeeded')
check('queuedInputRemainsParkedAfterInterruptResume', [item['id'] for item in data(interrupt, 'afterInterruptResumeinbox')]
      == [interrupt['promptIds']['queued']])
check('steeredInputPromotedAfterInterrupt', [m['id'] for m in history_users(interrupt, 'afterInterruptResumehistory')]
      == [interrupt['promptIds']['first'], interrupt['promptIds']['steered']])
check('idleInterruptIsNoOp', not call(interrupt, 'idleInterruptNoOp')['response']['interrupted'])

partial = reconnect['partialStream']['events']
reference = reconnect['referenceStream']['events']
resumed = reconnect['reconnectedStream']['events']
check('disconnectAtActualNativeDelta', reconnect['disconnectedOnFirstNativeDelta'] and partial[-1]['type'].endswith('.delta'))
check('partialIsObservedPrefixOfUninterruptedSubscriber', [e for e in partial if e['type'] != 'server.connected']
      == [e for e in reference if e['type'] != 'server.connected'][:len(partial) - 1])
check('referenceSawAuthoritativeEndedAndSuccess', any(e['type'] == 'session.text.ended' for e in reference)
      and any(e['type'] == 'session.execution.succeeded' for e in reference))
check('reconnectSuppliesLastEventId', reconnect['reconnectedStream']['request']['lastEventId'] == partial[-1]['id'])
check('reconnectStartsFreshWithoutLostEventReplay', [e['type'] for e in resumed] == ['server.connected', 'session.renamed'])
check('reconnectHydrationRestoresHistory', data(reconnect, 'completedWhileDisconnectedhistory') == data(reconnect, 'reconnectedHydrationhistory'))
ended = next(e['data'] for e in reference if e['type'] == 'session.text.ended')
assistant = next(m for m in data(reconnect, 'reconnectedHydrationhistory') if m['id'] == ended['assistantMessageID'])
check('hydrationContainsAuthoritativeEndedText', [c['text'] for c in assistant['content'] if c['type'] == 'text'][ended['ordinal']] == ended['text'])
check('readMarkerRecoveredAfterReconnect', ended['text'] == 'SP01_B_NATIVE_RECONNECT_OK')

check('nativeServiceRestartSucceeded', [cmd['exitCode'] for cmd in restart['nativeCommands']] == [0, 0])
check('sameFixedServiceVersionRestored', restart['beforeInfo']['version'] == restart['afterInfo']['version'] == '2.0.22'
      and restart['beforeInfo']['urls'] == restart['afterInfo']['urls'] == ['http://127.0.0.1:49374'])
check('nativeProcessActuallyChanged', restart['beforeInfo']['pid'] != restart['afterInfo']['pid'])
check('ownedExecutionActiveBeforeServiceRestart', restart['sessions']['active'] in data(restart, 'activeAtRestartBoundary'))
check('ownedExecutionRecoveredInNewNativeProcess', restart['sessions']['active'] in data(restart, 'activeAfterServiceRestart'))
check('priorPairedTokenAcceptedAfterRestart', restart['pairedTokenAcceptedAfterRestart']
      and call(restart, 'pairedTokenAcceptedAfterRestart')['status'] == 200)
check('durablePendingInputSurvivesRestart', data(restart, 'parkedBeforeRestartinbox') == data(restart, 'parkedAfterRestartinbox'))
check('completedTranscriptSurvivesRestart', data(restart, 'completedSessionBeforeRestarthistory') == data(restart, 'completedSessionAfterRestarthistory'))
check('inFlightSessionResumedToSuccess', restart['toolCalledBeforeRestart']
      and restart['completionAfterRestartObserved'] and data(restart, 'activeSessionAfterRestartsession')['outcome'] == 'succeeded')
restart_history = data(restart, 'activeSessionAfterRestarthistory')
check('interruptedAssistantAndSyntheticContinuationObserved', any(m['type'] == 'assistant'
      and m.get('error', {}).get('type') == 'aborted' for m in restart_history)
      and any(m['type'] == 'synthetic' for m in restart_history))
check('restartProducesExpectedNativeFinalText', any(m['type'] == 'assistant' and any(c['type'] == 'text'
      and c['text'] == 'B_RESTART_RESUMED_OK' for c in m['content']) for m in restart_history))
check('postRestartPendingReplayKeepsOriginal', data(restart, 'restartPendingSameIdReplay') == data(restart, 'pendingBeforeRestart'))
check('fledgeDenialRetainedAsActualFailure', any(e['type'] == 'session.execution.failed'
      and e['data']['error']['type'] == 'provider.auth' and e['data']['error']['status'] == 403 for e in denial['stream']['events']))
final = read('final-native-state.json')
check('ownedNativeSessionsSettled', final['pendingOwnedInboxTotal'] == 0 and final['activeOwnedSessionIds'] == [])
check('emptyGitProjectRecordedAsGlobal', all(session['projectID'] == 'global' for session in final['ownedSessions']))

for fixture in [queue, interrupt, reconnect, restart, denial, probe]:
    for entry in fixture['calls']:
        response = entry.get('response')
        if not isinstance(response, dict):
            continue
        content = response.get('data')
        if isinstance(content, dict) and 'cost' in content:
            check('observedSessionCostZero:' + entry['name'], content['cost'] == 0)
        if isinstance(content, list):
            for message in content:
                if message.get('type') == 'assistant':
                    if 'cost' in message:
                        check('observedAssistantCostZero:' + message['id'], message['cost'] == 0)

secret_keys = {'token', 'code', 'password', 'authorization', 'cookie', 'encrypted_content',
               'apikey', 'api_key', 'access_token', 'refresh_token', 'clientsecret', 'client_secret'}


def scan(value, key=''):
    if key.lower() in secret_keys:
        check('credentialFieldsRedacted', value == '[REDACTED]')
    if isinstance(value, dict):
        for name, nested in value.items():
            scan(nested, name)
    elif isinstance(value, list):
        for nested in value:
            scan(nested)
    elif isinstance(value, str) and value.startswith('data: '):
        scan(json.loads(value[6:]))


def stream_frames(stream, name):
    decoded = [json.loads(line[5:].lstrip()) for frame in stream['frames']
               for line in frame if line.startswith('data:')]
    check('sanitizedFramesMatchEvents:' + name, decoded == stream['events'])


for fixture, name in [(queue, 'queue'), (interrupt, 'interrupt'), (denial, 'denial'), (probe, 'probe')]:
    stream_frames(fixture['stream'], name)
for stream in ['referenceStream', 'partialStream', 'reconnectedStream']:
    stream_frames(reconnect[stream], stream)
for stream in ['oldStream', 'newStream']:
    stream_frames(restart[stream], stream)
stream_frames(read('matrix-events.json'), 'matrix')


for path in ROOT.glob('*.json'):
    if path.name in {'validation.json', 'provenance.json'}:
        continue
    scan(json.loads(path.read_text()))
provenance = read('provenance.json')
for filename, digest in provenance['fixtureSha256'].items():
    check('fixtureDigest:' + filename, hashlib.sha256((ROOT / filename).read_bytes()).hexdigest() == digest)
all_events = {}
all_events.update({e['id']: e for e in matrix_events if e['type'] != 'server.connected'})
for fixture in [queue, interrupt, denial, probe]:
    all_events.update({e['id']: e for e in fixture['stream']['events'] if e['type'] != 'server.connected'})
for stream in ['referenceStream', 'partialStream', 'reconnectedStream']:
    all_events.update({e['id']: e for e in reconnect[stream]['events'] if e['type'] != 'server.connected'})
for stream in ['oldStream', 'newStream']:
    all_events.update({e['id']: e for e in restart[stream]['events'] if e['type'] != 'server.connected'})
counts = Counter(e['type'] for e in all_events.values())
check('observedExecutionBudget', counts['session.execution.started'] + 1
      == provenance['actualNativeExecutionCountIncludingRestartRecovery'] <= 12)
result = {'validatedAt': datetime.datetime.now(datetime.timezone.utc).isoformat(), 'outcome': 'passed',
          'checks': checks, 'distinctObservedLiveEvents': len(all_events), 'eventCounts': dict(counts),
          'costUSD': 0, 'limitations': provenance['limitations']}
if '--write' in sys.argv:
    (ROOT / 'validation.json').write_text(json.dumps(result, indent=2) + '\n')
print(f"B observed fixture validation passed: {len(checks)} checks, {len(all_events)} distinct live events, USD 0.")
