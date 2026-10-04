#!/usr/bin/env python3
"""Opt-in V2-008 capture. Live native mutations are limited to owned sessions/PTYs."""
import base64, datetime, functools, hashlib, http.server, json, os, re, secrets
import subprocess, threading, time, urllib.error, urllib.parse, urllib.request
from pathlib import Path
from playwright.sync_api import sync_playwright

ROOT=Path('/workspace/.cloud-runtime/opencode-v2/capture-web')
PROJECT=ROOT/'project'
OUT=Path('/workspace/codewalk/test/contract/fixtures/opencode/2.0.22/web')
BASE='http://127.0.0.1:49374'
CLI='/workspace/.cloud-tools/bin/opencode2'
START=time.monotonic()
PRIVATE=set()
def now(): return datetime.datetime.now(datetime.timezone.utc).isoformat()
def clean(v):
    if isinstance(v,dict):
        return {k:'[REDACTED]' if k.lower() in {'authorization','password','token','ticket','apikey','api_key','access_token','refresh_token','client_secret'} else clean(x) for k,x in v.items()}
    if isinstance(v,list): return [clean(x) for x in v]
    if isinstance(v,str):
        for secret in PRIVATE:
            if secret: v=v.replace(secret,'[REDACTED]')
        return re.sub(r'([?&]ticket=)[^&#\s"\'<>]+',r'\1[REDACTED]',v)
    return v
def save(n,v):
    OUT.mkdir(parents=True,exist_ok=True)
    (OUT/n).write_text(json.dumps(clean(v),ensure_ascii=False,indent=2)+'\n')
def uid(): return 'ses_'+format(int(time.time()*1000)*4096,'012x')+secrets.token_hex(7)
def config_stat():
    result={}
    for group in ['config','state']:
        p=ROOT.parent/group/'opencode/service.json'
        s=p.stat()
        result[group]={'inode':s.st_ino,'mtimeNs':s.st_mtime_ns,'size':s.st_size,'mode':oct(s.st_mode&0o777)}
    return result
class Client:
    def __init__(self):
        r=subprocess.run([CLI,'service','get','password'],cwd=PROJECT,capture_output=True,text=True,timeout=25)
        assert r.returncode==0 and r.stdout.strip(),'supported password retrieval failed'
        password=r.stdout.strip()
        self.auth='Basic '+base64.b64encode(('opencode:'+password).encode()).decode()
        PRIVATE.update([password,self.auth])
        self.calls=[];self.sessions=[];self.ptys=[]
    def req(self,name,method,path,data=None,origin=None,extra=None):
        h={'Authorization':self.auth,'Accept':'application/json'}
        if origin:h['Origin']=origin
        h.update(extra or {})
        body=None if data is None else json.dumps(data).encode()
        if body is not None:h['Content-Type']='application/json'
        q=urllib.request.Request(BASE+path,data=body,method=method,headers=h)
        try:r=urllib.request.urlopen(q,timeout=20)
        except urllib.error.HTTPError as e:r=e
        raw=r.read()
        try:value=json.loads(raw) if raw else None
        except ValueError:value={'bytes':len(raw)}
        self.calls.append({'name':name,'method':method,'path':path,'status':r.status,'response':value,
            'origin':origin,'headers':{k.lower():v for k,v in r.headers.items() if k.lower() in {
            'access-control-allow-origin','access-control-allow-headers','access-control-allow-methods','content-type'}}})
        return r.status,value
    def create_session(self):
        payload={'id':uid(),'title':'V2-008 disposable stream','location':{'directory':str(PROJECT)}}
        status,value=self.req('CreateOwnSession','POST','/api/session',payload)
        assert status==200,'session creation failed'
        sid=value['data']['id'];self.sessions.append(sid);self.ledger();return sid
    def path(self,pid,suffix=''):
        return '/api/pty/'+pid+suffix+'?'+urllib.parse.urlencode({'location[directory]':str(PROJECT)})
    def create_pty(self,label):
        script="printf 'CW_WEB_READY\\n'; while IFS= read -r line; do case \"$line\" in DELAY) printf 'CW_WEB_SCHEDULED\\n'; sleep 2; printf 'CW_WEB_OFFLINE\\n';; FINISH) printf 'CW_WEB_FINISHED\\n'; break;; *) printf 'CW_WEB_REPLY:%s\\n' \"$line\";; esac; done"
        payload={'command':'/bin/sh','args':['-c',script],'cwd':str(PROJECT),'title':'V2-008 '+label,
            'env':{'TERM':'xterm-256color','HISTFILE':'/dev/null'}}
        status,value=self.req('CreateOwnPty'+label,'POST','/api/pty?'+urllib.parse.urlencode({'location[directory]':str(PROJECT)}),payload)
        assert status==200,'PTY creation failed'
        pid=value['data']['id'];self.ptys.append(pid);self.ledger();return pid
    def ledger(self):
        (ROOT/'artifacts'/'owned-ledger.json').write_text(json.dumps({'sessions':self.sessions,'ptys':self.ptys})+'\n')

def run():
    before_stat=config_stat();c=Client(); initial=c.req('InitialInfo','GET','/api/info')[1]
    assert initial['version']=='2.0.22'
    results={'startedAt':now(),'operations':[],'cdp':[],'console':[]}
    server=browser=context=None; phase='owned resources'; failure=None
    def op(page,label,**o):
        r=page.evaluate('(input) => window.cwTransport(JSON.stringify(input)).then(JSON.parse)',o)
        results['operations'].append({'label':label,'op':o['op'],'result':r})
        return r
    def expected(r): assert r.get('ok') is True,'Dart operation failed'
    try:
        sid=c.create_session();pty=c.create_pty('A');other=c.create_pty('B')
        class Handler(http.server.SimpleHTTPRequestHandler):
            def log_message(self,*args):pass
        server=http.server.ThreadingHTTPServer(('127.0.0.1',0),
            functools.partial(Handler,directory=str(ROOT/'flutter_spike/build/web')))
        threading.Thread(target=server.serve_forever,daemon=True).start()
        port=server.server_port
        allowed='http://localhost:'+str(port);denied='http://cw-web-denied.test:'+str(port)
        results.update(sessionID=sid,ptyIDs=[pty,other],allowedOrigin=allowed,deniedOrigin=denied)
        for label,origin in [('Allowed',allowed),('Denied',denied)]:
            for suffix,method,hdrs in [('/api/info','GET','authorization'),(c.path(pty,'/connect-token'),'POST','authorization,x-opencode-ticket')]:
                c.req(label+'Preflight','OPTIONS',suffix,origin=origin,extra={
                    'Access-Control-Request-Method':method,'Access-Control-Request-Headers':hdrs})
        with sync_playwright() as p:
            browser=p.chromium.launch(executable_path='/usr/bin/chromium',headless=True,args=[
                '--no-sandbox','--disable-dev-shm-usage','--no-proxy-server',
                '--host-resolver-rules=MAP cw-web-denied.test 127.0.0.1'])
            results['browserVersion']=browser.version;context=browser.new_context()
            def instrument(page,label):
                page.on('console',lambda event:results['console'].append({
                    'page':label,'type':event.type,'text':clean(event.text)}) if event.type=='error' else None)
                cd=context.new_cdp_session(page);cd.send('Network.enable')
                def selected(url):
                    u=urllib.parse.urlparse(url)
                    if u.port!=49374:return None
                    return {'path':u.path,'ticketQueryPresent':'ticket=' in u.query,'scheme':u.scheme}
                def request(e):
                    data=selected(e['request']['url'])
                    if data is not None:
                        h={k.lower():v for k,v in e['request'].get('headers',{}).items()}
                        results['cdp'].append({'page':label,'kind':'request','id':e['requestId'],**data,
                            'method':e['request']['method'],'authorizationPresent':'authorization' in h,
                            'ticketHeaderPresent':'x-opencode-ticket' in h})
                def response(e):
                    data=selected(e['response']['url'])
                    if data is not None:results['cdp'].append({'page':label,'kind':'response','id':e['requestId'],**data,
                        'status':e['response']['status']})
                def wscreate(e):
                    data=selected(e['url'])
                    if data is not None:results['cdp'].append({'page':label,'kind':'wsCreated','id':e['requestId'],**data})
                cd.on('Network.requestWillBeSent',request);cd.on('Network.responseReceived',response)
                cd.on('Network.webSocketCreated',wscreate)
                cd.on('Network.webSocketHandshakeResponseReceived',lambda e:results['cdp'].append({
                    'page':label,'kind':'wsHandshake','id':e['requestId'],'status':e['response']['status']}))
            page=context.new_page();instrument(page,'allowed');phase='Flutter boot'
            page.goto(allowed,wait_until='networkidle',timeout=30000)
            page.wait_for_function('typeof window.cwTransport === "function"',timeout=30000)
            expected(op(page,'Configure',op='configure',base=BASE,authorization=c.auth,directory=str(PROJECT),session=sid))
            phase='fetch SSE';print(json.dumps({'phase':phase}),flush=True)
            info=op(page,'DartInfo',op='info');expected(info);assert info['status']==200
            expected(op(page,'StreamInitial',op='sseStart'))
            c.req('UnicodeRename','PATCH','/api/session/'+sid,{'title':'V2-008 Olá 🚀'})
            expected(op(page,'StreamUnicodeObserved',op='sseWait',marker='V2-008 Olá 🚀'))
            expected(op(page,'StreamAbort',op='sseStop'))
            c.req('RenameDuringSseGap','PATCH','/api/session/'+sid,{'title':'V2-008 snapshot during gap 🌍'})
            expected(op(page,'StreamReconnected',op='sseStart'))
            snap=op(page,'SnapshotGapRecovery',op='snapshot');expected(snap)
            assert snap['body']['data']['title']=='V2-008 snapshot during gap 🌍','snapshot recovery failed'
            c.req('RenameAfterReconnect','PATCH','/api/session/'+sid,{'title':'V2-008 live after reconnect ✅'})
            expected(op(page,'StreamAfterReconnect',op='sseWait',marker='V2-008 live after reconnect ✅'))
            expected(op(page,'StreamFinalAbort',op='sseStop'))
            phase='PTY browser';print(json.dumps({'phase':phase}),flush=True)
            mint=op(page,'TicketA',op='ticket',pty=pty,handle='first');assert mint['status']==200
            expected(op(page,'PtyInitial',op='wsOpen',pty=pty,handle='first',socket='first'))
            expected(op(page,'PtyReady',op='wsWait',socket='first',marker='CW_WEB_READY'))
            expected(op(page,'PtyUnicodeInput',op='wsSend',socket='first',text='Olá 🚀\n'))
            expected(op(page,'PtyUnicodeReply',op='wsWait',socket='first',marker='CW_WEB_REPLY:Olá 🚀'))
            expected(op(page,'PtyScheduleOffline',op='wsSend',socket='first',text='DELAY\n'))
            before=op(page,'PtyScheduled',op='wsWait',socket='first',marker='CW_WEB_SCHEDULED');expected(before)
            expected(op(page,'PtyDisconnect',op='wsClose',socket='first'))
            page.wait_for_timeout(2500)
            assert op(page,'TicketReconnect',op='ticket',pty=pty,handle='reconnect')['status']==200
            reconnect=op(page,'PtyReconnect',op='wsOpen',pty=pty,handle='reconnect',socket='reconnected',cursor=before['trackedCursor'])
            expected(reconnect)
            assert reconnect['text'].count('CW_WEB_OFFLINE')==1 and 'CW_WEB_READY' not in reconnect['text'],'PTY cursor replay failed'
            expected(op(page,'PtyLiveAfterReplayInput',op='wsSend',socket='reconnected',text='LIVE_AGAIN\n'))
            expected(op(page,'PtyLiveAfterReplayOutput',op='wsWait',socket='reconnected',marker='CW_WEB_REPLY:LIVE_AGAIN'))
            assert op(page,'TicketMissingHeader',op='ticket',pty=pty,handle='noheader',header=False)['status']==403
            consumed=op(page,'ConsumedTicketRejected',op='wsOpen',pty=pty,handle='first',socket='consumed')
            assert consumed['failed'] and not consumed['opened'],'consumed ticket unexpectedly connected'
            assert op(page,'TicketScopeA',op='ticket',pty=pty,handle='scope')['status']==200
            scope=op(page,'WrongPtyTicketRejected',op='wsOpen',pty=other,handle='scope',socket='wrongscope')
            assert scope['failed'] and not scope['opened'],'wrong PTY ticket unexpectedly connected'
            expiry=op(page,'TicketExpiry',op='ticket',pty=pty,handle='expiry')
            assert expiry['status']==200;issued=time.monotonic()
            rejected=context.new_page();instrument(rejected,'denied')
            rejected.goto(denied,wait_until='networkidle',timeout=30000)
            rejected.wait_for_function('typeof window.cwTransport === "function"',timeout=30000)
            expected(op(rejected,'DeniedConfigure',op='configure',base=BASE,authorization=c.auth,directory=str(PROJECT),session=sid))
            assert not op(rejected,'DeniedDartInfo',op='info')['ok']
            assert not op(rejected,'DeniedDartSse',op='sseStart')['ok']
            assert not op(rejected,'DeniedDartMint',op='ticket',pty=pty,handle='denied')['ok']
            expected(op(rejected,'DeniedShutdown',op='shutdown'));rejected.close()
            phase='ticket expiry';last=-1
            while time.monotonic()-issued < expiry['expiresIn']+2:
                elapsed=int(time.monotonic()-issued)
                if elapsed//20!=last:
                    last=elapsed//20;print(json.dumps({'phase':phase,'elapsedSeconds':elapsed}),flush=True)
                page.wait_for_timeout(500)
            results['actualTicketExpiryWaitSeconds']=time.monotonic()-issued
            assert c.req('PtyStillAliveBeforeExpiry','GET',c.path(pty))[1]['data']['status']=='running'
            expired=op(page,'ExpiredTicketRejected',op='wsOpen',pty=pty,handle='expiry',socket='expired')
            assert expired['failed'] and not expired['opened'],'expired ticket unexpectedly connected'
            expected(op(page,'PtyFinish',op='wsSend',socket='reconnected',text='FINISH\n'))
            expected(op(page,'PtyFinishedOutput',op='wsWait',socket='reconnected',marker='CW_WEB_FINISHED'))
            for _ in range(30):
                state=c.req('OwnPtyExitObservation','GET',c.path(pty))[1]['data']
                if state['status']=='exited':break
                page.wait_for_timeout(100)
            assert state['status']=='exited' and state.get('exitCode')==0,'own PTY did not exit cleanly'
            expected(op(page,'BrowserShutdown',op='shutdown'))
            context.close();browser.close()
    except Exception as error:
        failure={'phase':phase,'errorType':type(error).__name__}
        # Never print an exception containing serialized browser parameters or URLs.
        print(json.dumps({'captureFailure':failure}),flush=True)
    finally:
        for obj in [context,browser]:
            if obj is not None:
                try:obj.close()
                except Exception:pass
        cleanup=[]
        for pid in c.ptys:
            try:
                before=c.req('CleanupPtyBefore','GET',c.path(pid))
                delete=c.req('CleanupPtyDelete','DELETE',c.path(pid))
                after=c.req('CleanupPtyAbsent','GET',c.path(pid))
                cleanup.append({'kind':'pty','id':pid,'before':before[1],'deleteStatus':delete[0],'afterStatus':after[0]})
            except Exception as e:cleanup.append({'kind':'pty','id':pid,'cleanupErrorType':type(e).__name__})
        for sid in c.sessions:
            try:
                delete=c.req('CleanupSessionDelete','DELETE','/api/session/'+sid)
                after=c.req('CleanupSessionAbsent','GET','/api/session/'+sid)
                cleanup.append({'kind':'session','id':sid,'deleteStatus':delete[0],'afterStatus':after[0]})
            except Exception as e:cleanup.append({'kind':'session','id':sid,'cleanupErrorType':type(e).__name__})
        if server:server.shutdown();server.server_close()
        final=c.req('FinalInfo','GET','/api/info')[1]
        save('capture.json',{**results,'completedAt':now(),'failure':failure,'calls':c.calls,
            'providerExecutions':0,'costUsd':0})
        save('cleanup.json',{'capturedAt':now(),'resources':cleanup,'initialInfo':initial,'finalInfo':final,
            'nativeServicePidPreserved':initial['pid']==final['pid'],
            'configAndRegistrationStatBefore':before_stat,'configAndRegistrationStatAfter':config_stat(),
            'configAndRegistrationMetadataUnchanged':before_stat==config_stat(),
            'sharedServiceReconfiguredOrRestarted':False,
            'disposableProjectGitCommit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=PROJECT,text=True).strip(),
            'disposableProjectGitStatus':subprocess.check_output(['git','status','--porcelain'],cwd=PROJECT,text=True),
            'credentialReturnedOnlyInMemory':True,'durationSeconds':time.monotonic()-START})
        assert all(x.get('afterStatus')==404 for x in cleanup),'owned resources remain'
        assert initial['pid']==final['pid'] and before_stat==config_stat(),'shared service changed'
    if failure:raise SystemExit(1)
    print(json.dumps({'capture':'passed','operations':len(results['operations']),
        'providerExecutions':0,'cleanupResources':len(cleanup)}),flush=True)
if __name__=='__main__':run()

