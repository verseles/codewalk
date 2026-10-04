#!/usr/bin/env python3
"""Read-only consistency checks for observed C fixtures; no service/model calls."""
import hashlib
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
CHECKS = []


def read(name):
    return json.loads((ROOT / name).read_text())


def check(name, value):
    if not value:
        raise AssertionError(name)
    CHECKS.append(name)


def requests(fixture, method, suffix):
    return [call for call in fixture['calls']
            if call['method'] == method and call['path'].endswith(suffix)]


def model_checks(name):
    fixture = read(name)
    summary = fixture['summary']
    sid = summary['sessionID']
    events = fixture['events']
    model = fixture['model']
    check(name + ':nativeVersion', fixture['info']['version'] == '2.0.22')
    check(name + ':freeEnabledToolModel', model['enabled'] and model['providerID'] == 'opencode'
          and model['capabilities']['tools'] and all(c['input'] == c['output'] == c['cache']['read']
                                                  == c['cache']['write'] == 0 for c in model['cost']))
    check(name + ':zeroObservedCost', summary['session']['cost'] == 0 and
          all(m.get('cost', 0) == 0 for m in summary['messages'] if m['type'] == 'assistant'))
    check(name + ':correlatedPrompt', summary['admission']['data']['id'] ==
          next(m['id'] for m in summary['messages'] if m['type'] == 'user'))
    check(name + ':uniqueEvents', len({e['id'] for e in events}) == len(events))
    check(name + ':targetTerminal', len([e for e in events if e['type'] in
          {'session.execution.succeeded', 'session.execution.failed', 'session.execution.interrupted'}
          and e['data']['sessionID'] == sid]) == 1)
    return fixture, summary, sid, events


def final_text(summary):
    return ''.join(c['text'] for m in summary['messages'] if m['type'] == 'assistant'
                   for c in m.get('content', []) if c['type'] == 'text')


def validate():
    native = read('native-interactions.json')
    summary = native['summary']
    check('native:noProviderExecutionClaim', not any(e['type'].startswith('session.execution.')
                                                   for e in native['events']))
    once_ids = summary['onceRequestIDs']
    check('native:onceReasks', len(once_ids) == 2 and len(set(once_ids)) == 2)
    for rid in once_ids:
        check('native:onceReply:' + rid, any(c['method'] == 'POST' and
              c['path'].endswith('/' + rid + '/reply') and c['request']['decision'] == 'once'
              and c['status'] == 204 for c in native['calls']))
    saved_calls = [c for c in native['calls'] if c['method'] == 'GET'
                   and c['path'].startswith('/api/permission/saved')]
    check('native:onceNoPersistence', all(c['response']['data'] == [] for c in saved_calls[:2]))
    saved = summary['savedPermission']
    check('native:alwaysPersistsProjectScope', saved['projectID'] == summary['projectID']
          and saved['action'] == 'capture_permission' and saved['resource'] == 'always-marker')
    check('native:initialCommitIsolatesProject', summary['projectID'] ==
          'fdb157e6e688e8ab6521d2643bf6d838517fb509' and summary['projectID'] != 'global')
    inherited = [c for c in native['calls'] if c['method'] == 'POST' and
                 c['path'] == '/api/session/' + summary['inheritingSessionID'] + '/permission']
    check('native:alwaysAllowsAnotherSession', inherited[0]['response']['data']['effect'] == 'allow')
    for batch in summary['rejectBatches']:
        sid, control = batch['sessionID'], batch['controlSessionID']
        ids = set(batch['requestIDs'])
        suffix = ':note' if batch['note'] else ':noNote'
        pending = requests(native, 'GET', '/api/session/' + sid + '/permission')
        check('native:parallelPending' + suffix, set(p['id'] for p in pending[0]['response']['data']) == ids)
        check('native:batchCleared' + suffix, pending[-1]['response']['data'] == [])
        preserved = requests(native, 'GET', '/api/session/' + control + '/permission')
        check('native:independentPreserved' + suffix, all(
            [p['id'] for p in c['response']['data']] == [batch['controlRequestID']] for c in preserved))
        rejected = {e['data']['requestID'] for e in native['events']
                    if e['type'] == 'permission.replied' and e['data']['sessionID'] == sid
                    and e['data']['reply'] == 'reject'}
        check('native:twoRejectedEvents' + suffix, rejected == ids)
        check('native:staleReply404' + suffix, any(c['status'] == 404 and c['path'].endswith(
            '/' + batch['requestIDs'][1] + '/reply') for c in native['calls']))
    check('native:typedFormAnswer', summary['forms'][0]['state'] ==
          {'status': 'answered', 'answer': {'choice': 'alpha', 'count': 2, 'confirmed': True}})
    check('native:typedFormDismiss', summary['forms'][1]['state'] == {'status': 'cancelled'})
    check('native:savedApprovalCleaned', saved_calls[-1]['response']['data'] == [])

    for kind in ('once', 'always'):
        fixture, summary, sid, events = model_checks('provider-' + kind + '.json')
        check(kind + ':permissionIsNativeToolRequest', any(e['type'] == 'permission.asked'
              and e['data']['sessionID'] == sid and e['data']['source']['type'] == 'tool'
              for e in events))
        check(kind + ':replyObserved', any(e['type'] == 'permission.replied'
              and e['data']['reply'] == kind for e in events))
        check(kind + ':readSucceeded', any(e['type'] == 'session.tool.success' for e in events))
        check(kind + ':turnSucceeded', summary['terminalEvents'] == ['session.execution.succeeded']
              and summary['session']['outcome'] == 'succeeded')
        check(kind + ':markerReturned', final_text(summary) == 'C_PERMISSION_ALPHA')
        if kind == 'always':
            saved = summary['savedPermissionEvidence']
            check('always:realReadApprovalSaved', saved['saved'][0]['action'] == 'read'
                  and saved['saved'][0]['resource'] == '*')
            check('always:anotherSessionNativeAllow', saved['nativeEvaluation']['effect'] == 'allow')
            check('always:cleanupVerified', saved['cleanupVerified'])

    for kind in ('reject-note', 'reject-none'):
        fixture, summary, sid, events = model_checks('provider-' + kind + '-space-bunny-free.json')
        ids = set(summary['resolution']['requestIDs'])
        asked = [e for e in events if e['type'] == 'permission.asked' and e['data']['sessionID'] == sid]
        check(kind + ':twoRealParallelToolRequests', len(asked) == 2 and
              {e['data']['id'] for e in asked} == ids and
              all(e['data']['source']['type'] == 'tool' for e in asked))
        check(kind + ':sameAssistantSeparateToolCalls', len({e['data']['source']['messageID'] for e in asked}) == 1
              and len({e['data']['source']['id'] for e in asked}) == 2)
        replies = [e for e in events if e['type'] == 'permission.replied' and e['data']['sessionID'] == sid]
        check(kind + ':bothRequestsRejected', {e['data']['requestID'] for e in replies} == ids
              and all(e['data']['reply'] == 'reject' for e in replies))
        check(kind + ':bothAsksBeforeRejection', max(e['created'] for e in asked) <=
              min(e['created'] for e in replies))
        check(kind + ':independentSessionPreserved', len(summary['controlPendingAfterTargetSettles']) == 1
              and summary['controlPendingAfterTargetSettles'][0]['sessionID'] == summary['controlSessionID'])
        if kind == 'reject-note':
            check(kind + ':twoToolFeedbackFailures', len([e for e in events if e['type'] == 'session.tool.failed']) == 2)
            check(kind + ':modelContinuedSuccessfully', summary['terminalEvents'] == ['session.execution.succeeded']
                  and summary['session']['outcome'] == 'succeeded' and final_text(summary) == 'C_REJECT_FEEDBACK_OK')
        else:
            check(kind + ':stepInterrupted', summary['terminalEvents'] == ['session.execution.interrupted'])
            check(kind + ':assistantAborted', any(m.get('error', {}).get('type') == 'aborted'
                  for m in summary['messages'] if m['type'] == 'assistant'))
            check(kind + ':noFinalModelAnswer', final_text(summary) == '')

    post = read('post-capture-checks.json')
    for kind in ('form-reply', 'form-dismiss'):
        fixture, summary, sid, events = model_checks('provider-' + kind + '.json')
        fid = summary['resolution']['formID']
        created = next(e['data']['form'] for e in events if e['type'] == 'form.created')
        check(kind + ':actualQuestionToolForm', created['id'] == fid and created['sessionID'] == sid
              and created['metadata']['kind'] == 'question' and created['fields'][0]['key'] == 'q0')
        state = next(c['response']['data']['state'] for c in post['calls']
                     if c['path'] == '/api/session/' + sid + '/form/' + fid)
        if kind == 'form-reply':
            check(kind + ':settledAnswered', state == {'status': 'answered', 'answer': {'q0': 'Blue'}})
            check(kind + ':nativeRepliedEvent', any(e['type'] == 'form.replied'
                  and e['data']['id'] == fid and e['data']['answer'] == {'q0': 'Blue'} for e in events))
            check(kind + ':modelContinued', summary['terminalEvents'] == ['session.execution.succeeded']
                  and final_text(summary) == 'Blue')
        else:
            check(kind + ':settledCancelledWithoutMessage', state == {'status': 'cancelled'})
            check(kind + ':nativeCancelledEvent', any(e['type'] == 'form.cancelled'
                  and e['data']['id'] == fid for e in events))
            check(kind + ':stepInterrupted', summary['terminalEvents'] == ['session.execution.interrupted']
                  and final_text(summary) == '' and any(m.get('error', {}).get('type') == 'aborted'
                  for m in summary['messages'] if m['type'] == 'assistant'))

    check('cleanup:allOwnedSessionsSettled', all(c['response']['data'] == [] for c in post['calls']
          if c['path'].endswith('/permission') or c['path'].endswith('/form')))
    check('cleanup:bothProjectGrantListsEmpty', all(c['response']['data'] == [] for c in post['calls']
          if c['path'].startswith('/api/permission/saved')))
    check('cleanup:disposedCaptureSessionsRemoved', len(post['removedDisposableSessionIDs']) == 3)
    check('diagnostics:failedCollectorNotClaimedAsReplay', len(post['failedCollectorHistoryRecovery']) == 1)
    recovery = read('post-restart-question-recovery.json')
    rs = recovery['summary']
    original = read('provider-form-dismiss.json')['summary']
    check('restart:resumedSameDismissedSession', rs['sessionID'] == original['sessionID']
          and rs['pendingForm']['sessionID'] == original['sessionID']
          and rs['pendingForm']['id'] != original['resolution']['formID'])
    check('restart:explicitFeedbackRecorded', bool(rs['feedback']) and any(c['method'] == 'DELETE'
          and '?message=' in c['path'] and c['status'] == 204 for c in recovery['calls']))
    check('restart:resumedWorkSettled', rs['terminalEvents'] == ['session.execution.succeeded']
          and rs['session']['outcome'] == 'succeeded' and rs['session']['cost'] == 0
          and rs['pendingFormsAfter'] == [])
    check('restart:recoveryMarkerReturned', any(c.get('text') == 'C_DISMISS_RESTART_RECOVERY_OK'
          for m in rs['messages']['data'] if m['type'] == 'assistant'
          for c in m.get('content', []) if c['type'] == 'text'))
    for sid in post['removedDisposableSessionIDs'][:2]:
        histories = [c['response']['data'] for c in post['calls']
                     if c['path'] == '/api/session/' + sid + '/message?order=asc&limit=200']
        history = histories[-1]
        check('restart:nativeContinuationNotice:' + sid, any(m['type'] == 'synthetic'
              and m.get('metadata', {}).get('notice') == 'restart' for m in history))
        check('restart:continuedWithoutNewToolReads:' + sid, history[-1]['type'] == 'idle'
              and history[-1]['outcome'] == 'succeeded' and all(c['type'] != 'tool'
              for m in history if m['type'] == 'assistant' and not m.get('error')
              for c in m.get('content', [])))
    for name in ('provider-reject-note.json', 'provider-reject-none.json'):
        fixture = read(name)
        check(name + ':singleFledgeAskPreserved', len([e for e in fixture['events']
              if e['type'] == 'permission.asked']) == 1 and fixture['summary']['resolution'] is None)
    secret_fields = {'token', 'code', 'password', 'authorization', 'cookie', 'encrypted_content',
                     'apikey', 'api_key', 'access_token', 'refresh_token', 'clientsecret', 'client_secret'}

    def walk(value, key=''):
        if key.lower() in secret_fields:
            assert value == '[REDACTED]', 'Unredacted credential field: ' + key
        if isinstance(value, dict):
            for k, v in value.items():
                walk(v, k)
        elif isinstance(value, list):
            for v in value:
                walk(v)

    for path in ROOT.glob('*.json'):
        walk(json.loads(path.read_text()))
    check('credentialFieldsRedacted', True)
    semantic_count = len(CHECKS)
    if (ROOT / 'SHA256SUMS').exists():
        for line in (ROOT / 'SHA256SUMS').read_text().splitlines():
            digest, filename = line.split('  ', 1)
            check('sha256:' + filename, hashlib.sha256((ROOT / filename).read_bytes()).hexdigest() == digest)
    return {'outcome': 'passed', 'checks': CHECKS, 'count': len(CHECKS),
            'semanticCheckCount': semantic_count, 'observedProviderCostUSD': 0,
            'authoredProviderPromptsIncludingDiagnosticAttempts': 10,
            'additionalRestartResumedProviderExecutionsObserved': 3,
            'totalObservedProviderExecutions': 13}


if __name__ == '__main__':
    result = validate()
    if '--json' in sys.argv:
        print(json.dumps(result, indent=2))
    else:
        print(f"C observed fixture validation passed: {result['count']} checks; ten authored free prompts plus three native restart continuations, USD 0.")
