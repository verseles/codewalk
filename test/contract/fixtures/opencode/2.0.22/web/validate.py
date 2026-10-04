#!/usr/bin/env python3
"""Portable offline fixture validation. Default read-only; report write opt-in."""
import argparse,datetime,hashlib,json,re,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parent
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--write-report',action='store_true')
args=parser.parse_args()
checks={}
def check(name,value):checks[name]='passed' if value else 'failed'
def read(name):return json.loads((ROOT/name).read_text())
def utf16(text):return len(text.encode('utf-16-le'))//2
try:
    manifest={}
    for line in (ROOT/'SHA256SUMS').read_text().splitlines():
        digest,name=line.split('  ',1)
        check('manifestSafe:'+name,Path(name).name==name and bool(re.fullmatch(r'[0-9a-f]{64}',digest)))
        check('manifestDigest:'+name,hashlib.sha256((ROOT/name).read_bytes()).hexdigest()==digest)
        manifest[name]=digest
    actual={p.name for p in ROOT.iterdir() if p.is_file()}-{'SHA256SUMS','validation.json'}
    check('exactArtifactSet',actual==set(manifest))
    capture=read('capture.json');cleanup=read('cleanup.json');source=read('source-evidence.json')
    build=read('build.json');aux=read('auxiliary-assets.json');provenance=read('provenance.json')
    operations={x['label']:x['result'] for x in capture['operations']}
    calls=capture['calls']
    check('nativeCaptureSucceeded',capture['failure'] is None)
    check('zeroProviderExecutions',capture['providerExecutions']==provenance['providerExecutions']==0)
    check('zeroCost',capture['costUsd']==provenance['costUsd']==0)
    check('noNativeModelAdmission',not any(re.search(r'/(prompt|shell|generate|agent|model)(/|$)',x['path']) for x in calls))
    check('sourcePin',source['sourcePin']=='05018b8862a8fc198ec9810aafd397c96bb7d86e')
    for path,item in source['sources'].items():
        check('sourceImmutable:'+path,source['sourcePin'] in item['url'] and item['url'].endswith(path))
        check('sourceDigestShape:'+path,bool(re.fullmatch(r'[0-9a-f]{64}',item['sha256'])))
        check('sourceExcerpts:'+path,len(item['excerpts'])>0 and all(e['line']>0 for e in item['excerpts']))
    static='\n'.join(e['text'] for item in source['sources'].values() for e in item['excerpts'])
    for label,needle in [('TTL','Duration.seconds(60)'),('SingleUse','Cache.invalidateWhen'),
        ('Utf16Cursor','session.cursor += chunk.length'),('CorsStopsService','yield* Service.stop')]:
        check('static'+label,needle in static)
    check('buildAllCommandsPassed',all(x['exitCode']==0 for x in build['commands']))
    check('analyzerNoIssues',any(x.get('result')=='No issues found' for x in build['commands']))
    check('standaloneBuild',build['standaloneProjectOutsideCheckout'])
    check('buildDartSourceDigest',build['dartSourceSha256']==hashlib.sha256((ROOT/'flutter_main.dart.txt').read_bytes()).hexdigest())
    check('servedCompiledDigest',build['compiledMainJsSha256']==aux['servedMainJsSha256'])
    check('servedCompiledBytes',build['compiledMainJsBytes']==aux['servedMainJsBytes']>0)
    check('compiledBridgeLoaded',aux['compiledDartBridgeLoaded'])
    check('auxiliaryNoNative',aux['browserOnly'] and aux['nativeServiceRequests']==0)
    check('auxiliaryFontBoundary',all('fonts.gstatic.com' in x['url'] for x in aux['failedResources']))
    dart=(ROOT/'flutter_main.dart.txt').read_text()
    check('dartUsesFetch',bool(re.search(r'web\.window\s*\.fetch',dart)))
    for label,needle in [('Reader','web.ReadableStreamDefaultReader'),
        ('Abort','web.AbortController'),('Ws','web.WebSocket'),('Utf8','utf8.decoder.startChunkedConversion')]:
        check('dartUses'+label,needle in dart)
    check('noAuthQuerySource','auth_token' not in dart and "'ticket': tickets" in dart)
    for label,path in [('Info','/api/info'),('Sse','/api/event')]:
        check('browserAuthorization'+label,any(x['kind']=='request' and x.get('path')==path and
            x['page']=='allowed' and x.get('authorizationPresent') for x in capture['cdp']))
    check('browserMintCustomHeader',any(x['kind']=='request' and x.get('path','').endswith('/connect-token')
        and x['page']=='allowed' and x.get('authorizationPresent') and x.get('ticketHeaderPresent') for x in capture['cdp']))
    check('infoReadable',operations['DartInfo']['status']==200 and operations['DartInfo']['body']['version']=='2.0.22')
    for label,title in [('StreamUnicodeObserved','V2-008 Olá 🚀'),('StreamAfterReconnect','V2-008 live after reconnect ✅')]:
        stream=operations[label]
        check(label+'Connected',stream['events'][0]['type']=='server.connected')
        check(label+'OwnRename',any(e['type']=='session.renamed' and e['data']['sessionID']==capture['sessionID']
            and e['data']['title']==title for e in stream['events']))
        check(label+'Incremental',len(stream['chunks'])>=2 and all(x['bytes']>0 for x in stream['chunks']))
        check(label+'ControlledRechunk',stream['controlledByteByByteDecodePassed'] and stream['controlledByteCount']>0)
        check(label+'ActualFragmentationTruth',stream['actualReadBoundarySplitUtf8'] is False)
    check('streamAborted',operations['StreamAbort']['aborted'] and operations['StreamFinalAbort']['aborted'])
    check('gapSnapshotRecovered',operations['SnapshotGapRecovery']['status']==200
        and operations['SnapshotGapRecovery']['body']['data']['title']=='V2-008 snapshot during gap 🌍')
    check('gapNotInventedReplay',not any(e.get('data',{}).get('title')=='V2-008 snapshot during gap 🌍'
        for e in operations['StreamAfterReconnect']['events']))
    for label in ['DeniedDartInfo','DeniedDartSse','DeniedDartMint']:
        check(label+'Blocked',operations[label]['ok'] is False)
    for x in [x for x in calls if x['name'].endswith('Preflight')]:
        allowed=x['origin']==capture['allowedOrigin'];label=x['name']+x['path']
        check('preflightStatus:'+label,x['status']==204)
        check('preflightOrigin:'+label,x['headers'].get('access-control-allow-origin')==x['origin']
            if allowed else 'access-control-allow-origin' not in x['headers'])
    check('deniedConsolePreflight',sum('blocked by CORS policy' in x['text'] and 'preflight' in x['text']
        for x in capture['console'] if x['page']=='denied')==3)
    for label in ['TicketA','TicketReconnect','TicketScopeA','TicketExpiry']:
        check(label+'Minted',operations[label]['status']==200 and operations[label]['expiresIn']==60)
    check('ticketHeaderRequired',operations['TicketMissingHeader']['status']==403)
    before=operations['PtyScheduled'];reconnect=operations['PtyReconnect'];live=operations['PtyLiveAfterReplayOutput']
    for label,term in [('initial',before),('reconnect',reconnect),('live',live)]:
        check('ptyOpened:'+label,term['opened'] and not term['failed'])
        frames=term['frames'];metas=[i for i,f in enumerate(frames) if f['kind']=='meta']
        check('ptyOneMetadata:'+label,len(metas)==1)
        if metas:
            index=metas[0];meta=frames[index]
            check('ptyBinaryMetadata:'+label,meta['leadingByte']==0 and meta['cursor']==term['metaCursor'])
            check('ptyTrackedCursor:'+label,meta['cursor']+sum(utf16(f['text']) for f in frames[index+1:]
                if f['kind']=='text')==term['trackedCursor'])
        check('ptyUtf16Lengths:'+label,all(f['utf16Units']==utf16(f['text']) for f in frames if f['kind']=='text'))
    check('ptyUnicodeReply','CW_WEB_REPLY:Olá 🚀' in before['text'])
    check('ptyUnicodeNotByteCursor',any(len(f['text'].encode())!=f['utf16Units']
        for f in before['frames'] if f['kind']=='text'))
    check('ptyOfflineReplayExactlyOnce',reconnect['text'].count('CW_WEB_OFFLINE')==1)
    check('ptyNoReadyDuplicate','CW_WEB_READY' not in reconnect['text'])
    check('ptyReplayCursorRelation',reconnect['metaCursor']==before['trackedCursor']+utf16(reconnect['text']))
    check('ptyLiveAfterReplay','CW_WEB_REPLY:LIVE_AGAIN' in live['text'])
    for label in ['ConsumedTicketRejected','WrongPtyTicketRejected','ExpiredTicketRejected']:
        check(label+'Rejected',operations[label]['failed'] and not operations[label]['opened'])
    check('browserSuccessfulHandshakes',sum(e['status']==101 for e in capture['cdp'] if e['kind']=='wsHandshake')==2)
    check('browserRejection403Console',sum('Unexpected response code: 403' in e['text'] for e in capture['console'])==3)
    check('ticketQueriesEphemeral',all(e['ticketQueryPresent'] for e in capture['cdp'] if e['kind']=='wsCreated'))
    check('expiryActuallyWaited',capture['actualTicketExpiryWaitSeconds']>operations['TicketExpiry']['expiresIn'])
    check('expiryTargetAlive',any(x['name']=='PtyStillAliveBeforeExpiry' and
        x['response']['data']['status']=='running' for x in calls))
    check('twoLiveScopeTargets',len(capture['ptyIDs'])==2 and len(set(capture['ptyIDs']))==2)
    check('ownPtyFinished','CW_WEB_FINISHED' in operations['PtyFinishedOutput']['text'])
    check('browserClearedCredentials',operations['BrowserShutdown']['credentialsCleared']
        and operations['DeniedShutdown']['credentialsCleared'])
    check('cleanupExactOwnedSet',{x['id'] for x in cleanup['resources']}=={capture['sessionID'],*capture['ptyIDs']})
    check('cleanupAllAbsent',all(x['afterStatus']==404 and x['deleteStatus']==204 for x in cleanup['resources']))
    check('ownedProcessGone',len(cleanup['postDeleteOwnedProcessProcfs'])==2
        and all(not x['procfsExists'] for x in cleanup['postDeleteOwnedProcessProcfs']))
    check('ownPtyExitZero',any(x['kind']=='pty' and x['before']['data'].get('exitCode')==0 for x in cleanup['resources']))
    check('sharedPidPreserved',cleanup['nativeServicePidPreserved'] and cleanup['initialInfo']['pid']==cleanup['finalInfo']['pid'])
    check('sharedConfigMetadataPreserved',cleanup['configAndRegistrationMetadataUnchanged']
        and cleanup['configAndRegistrationStatBefore']==cleanup['configAndRegistrationStatAfter'])
    check('noSharedRestart',cleanup['sharedServiceReconfiguredOrRestarted'] is False)
    check('disposableGitClean',cleanup['disposableProjectGitStatus']=='')
    check('initialDisposableGit',cleanup['disposableProjectGitCommit']=='88a7e250a946a09f579ae3015c4c8c015b159a4f')
    check('credentialMemoryOnly',cleanup['credentialReturnedOnlyInMemory'])
    check('captureWithinBudget',cleanup['durationSeconds']<provenance['budgetSeconds']==3600)
    check('wholeIssueStillPending',provenance['wholeIssueAccepted'] is False and len(provenance['pending'])>=4)
    check('noWebSecurityBypass',provenance['browserWebSecurityMixedContentOrTlsChecksDisabled'] is False)
    check('cloudProcessSandboxRecorded',provenance['chromiumProcessSandboxDisabled'] is True)
    def audit(v):
        if isinstance(v,dict):
            for k,x in v.items():
                if k.lower() in {'authorization','password','token','ticket','apikey','api_key','access_token','refresh_token','client_secret'}:
                    check('credentialKeyRedacted:'+k,x=='[REDACTED]')
                audit(x)
        elif isinstance(v,list):
            for x in v:audit(x)
    for name in manifest:
        p=ROOT/name
        if p.suffix=='.json':audit(read(name))
        text=p.read_text()
        check('noBasicValue:'+name,not re.search(r'\bBasic [A-Za-z0-9+/=]{12,}',text))
        check('noTicketValue:'+name,not re.search(r'ticket=(?!\[REDACTED\])[a-zA-Z0-9._%-]{12,}',text))
except Exception as error:
    checks['validationException:'+type(error).__name__]='failed'
report={'validatedAt':datetime.datetime.now(datetime.timezone.utc).isoformat(),
    'status':'passed' if all(v=='passed' for v in checks.values()) else 'failed',
    'checkCount':len(checks),'checks':checks,'writeReportRequested':args.write_report}
if args.write_report:(ROOT/'validation.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({'status':report['status'],'checkCount':len(checks),
    'failed':[k for k,v in checks.items() if v!='passed'],'writeReportRequested':args.write_report}))
sys.exit(0 if report['status']=='passed' else 1)
