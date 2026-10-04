#!/usr/bin/env python3
"""Cross-check observed fixture relationships without issuing a model request."""
from collections import Counter
import argparse
import datetime
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parent
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--write-report',action='store_true',help='explicitly regenerate validation.json')
args=parser.parse_args()
read=lambda name: json.loads((ROOT/name).read_text())
info=read('info.json'); created=read('session-created.json'); session=read('session-completed.json')
events=read('events.json'); messages=read('messages.json')['data']; admission=read('prompt-admission.json')
auth=read('auth-pairing.json'); renewal=read('token-renewal.json'); model=read('model.json')
sid=created['data']['id']; checks={}
def check(name, condition):
    assert condition, name
    checks[name]='passed'
check('connectedVersion',info['version']=='2.0.22')
check('serviceAddress',info['urls']==['http://127.0.0.1:49374'])
check('createdAndCompletedSessionIdentity',session['data']['id']==sid)
check('locationIdentity',created['data']['location']==session['data']['location'])
check('anonymousAndInvalidAuthenticationRejected',len([q for q in auth['requests'] if q.get('status')==401])==3)
check('pairingCodeSingleUse',any(q['path'].startswith('/auth/connect/') and q.get('status')==401 for q in auth['requests']))
check('freshPairingAccepted',auth['rePairing']['newTokenDiffers'] and auth['rePairing']['bothTokensAccepted'])
check('pairedTokenMintsSuccessor',renewal['request']['credentialKind']=='previously paired token' and renewal['response']['status']==200)
check('successorTokenAuthenticates',renewal['successorInfo']['status']==200 and renewal['successorInfo']['body']['version']=='2.0.22')
check('successorExpiryAdvances',renewal['successorExpiryEpochSeconds']>renewal['firstExpiryEpochSeconds'])
check('previousTokenNotRevokedByRenewal',renewal['previousTokenStillAccepted'])
check('freeEnabledToolModel',model['providerID']=='opencode' and model['modelID']=='fledge-alpha-free' and model['enabled'] and model['capabilities']['tools'])
check('catalogCostZero',all(c['input']==0 and c['output']==0 for c in model['cost']))
check('observedCostZero',session['data']['cost']==0 and all(m['cost']==0 for m in messages if m['type']=='assistant'))
check('promptAdmissionPromotedToHistory',admission['status']==200 and any(m['id']==admission['response']['data']['id'] and m['type']=='user' for m in messages))
check('sessionEventIdentity',all(e['id'].startswith('evt_') and e['data']['sessionID']==sid for e in events))
check('eventIdsUnique',len({e['id'] for e in events})==len(events))
types=Counter(e['type'] for e in events)
check('executionSucceeded',types['session.execution.started']==1 and types['session.execution.succeeded']==1 and session['data']['outcome']=='succeeded')
check('noExecutionOrToolFailure',not any(e['type'] in ['session.execution.failed','session.execution.interrupted','session.tool.failed'] for e in events))
assistant={m['id']:m for m in messages if m['type']=='assistant'}
for kind in ['text','reasoning']:
    started=[e for e in events if e['type']=='session.'+kind+'.started']
    ended=[e for e in events if e['type']=='session.'+kind+'.ended']
    check(kind+'StartedDeltaEndedObserved',len(started)==len(ended)>0 and types['session.'+kind+'.delta']>0)
    for end in ended:
        data=end['data']; aid=data['assistantMessageID']; ordinal=data['ordinal']
        delta=''.join(e['data']['delta'] for e in events if e['type']=='session.'+kind+'.delta' and e['data']['assistantMessageID']==aid and e['data']['ordinal']==ordinal)
        check(kind+'DeltaMatchesEnded:'+aid+':'+str(ordinal),delta==data['text'])
        content=[c for c in assistant[aid]['content'] if c['type']==kind][ordinal]
        check(kind+'EndedMatchesProjectedHistory:'+aid+':'+str(ordinal),content['type']==kind and content['text']==data['text'])
called=next(e['data'] for e in events if e['type']=='session.tool.called')
tool_id=called['id']; aid=called['assistantMessageID']
tool_end=next(e['data'] for e in events if e['type']=='session.tool.input.ended' and e['data']['id']==tool_id)
tool_delta=''.join(e['data']['delta'] for e in events if e['type']=='session.tool.input.delta' and e['data']['id']==tool_id)
check('toolInputEndedMatchesCall',json.loads(tool_end['text'])==called['input'])
# This short native turn coalesced input into an ended value; no input delta was emitted.
check('toolInputDeltaIfPresentMatchesEnded',not tool_delta or tool_delta==tool_end['text'])
tool=next(c for c in assistant[aid]['content'] if c['type']=='tool' and c['id']==tool_id)
success=next(e['data'] for e in events if e['type']=='session.tool.success' and e['data']['id']==tool_id)
check('readToolCompleted',tool['name']=='read' and tool['state']['status']=='completed')
check('toolResultMatchesHistory',tool['state']['content']==success['content'])
marker=(ROOT/'input.txt').read_text().strip()
check('readReturnedSourceFileContent',marker in json.dumps(success['content']))
final=next(m for m in messages if m['type']=='assistant' and m.get('finish')=='stop')
check('finalAssistantTextMatchesInput',next(c['text'] for c in final['content'] if c['type']=='text')==marker)
check('completionTimeRecorded',session['data']['time']['idle']>=final['time']['completed'])
sse=[]
for frame in (ROOT/'events.sse').read_text().split('\n\n'):
    if frame.strip():
        sse.append(json.loads(frame.removeprefix('data: ')))
check('sanitizedSseMatchesJsonEvents',sse==events)
screen=(ROOT/'tui-screen.txt').read_text()
check('nativeTuiShowsSameResult',marker in screen and 'Explored: 1 read' in screen and 'Thought' in screen and 'OpenCode Zen' in screen)
check('nativeTuiSessionCorrelated',sid in read('provenance.json')['terminal']['command'])
for path in ROOT.glob('*.json'):
    def walk(value,key=''):
        if key.lower() in {'token','code','password','authorization','cookie','encrypted_content','apikey','api_key','access_token','refresh_token','clientsecret','client_secret'}:
            assert value=='[REDACTED]', 'Unredacted credential field in '+path.name
        if isinstance(value,dict):
            for k,v in value.items(): walk(v,k)
        elif isinstance(value,list):
            for v in value: walk(v)
    walk(json.loads(path.read_text()))
check('credentialFieldsRedacted',True)
result={'validatedAt':datetime.datetime.now(datetime.timezone.utc).isoformat(),'outcome':'passed',
        'checks':checks,'counts':dict(types),
        'observedTurnDurationMilliseconds':next(e['created'] for e in events if e['type']=='session.execution.succeeded')-next(e['created'] for e in events if e['type']=='session.execution.started'),
        'toolInputDeltaObserved':types['session.tool.input.delta']>0,
        'realTimeTokenExpiryObserved':False,
        'collectorDiagnostic':'Original wait timed out because it selected a nonexistent terminal event; native succeeded event and projected outcome establish completion independently.'}
if args.write_report:
    (ROOT/'validation.json').write_text(json.dumps(result,indent=2)+'\n')
print(f"Observed fixture validation passed: {len(checks)} checks, {len(events)} native events, USD 0.")
