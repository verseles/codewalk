#!/usr/bin/env python3
"""Validate observed V2-005D evidence offline; writes only with --report.

Uses the Python standard library and preserved fixtures, with no service/tool/
model calls. A pass covers the observed subset; natural retry/quota is pending.
Official schema/session-event.ts places the name on Tool.Input.Started, input
on Tool.Called, and raw JSON on Tool.Input.Ended. Native completion ownership
follows core/session_subagent-completion.ts. Source pins are not runtime passes.
"""

import argparse
import hashlib
import json
import re
import sys
from collections import Counter
from pathlib import Path
from urllib.parse import urlsplit


ROOT = Path(__file__).resolve().parent
PROJECT = "a8428d2df1249d57369eadf3d6205a4259f3a048"
MODEL = {"id": "space-bunny-free", "providerID": "opencode", "variant": "low"}
PRIMARY = (
    "foreground-nested.json", "background-interrupt.json", "revert-file-effects.json",
)
DIAGNOSTICS = (
    "foreground-nested-collector-diagnostic.json",
    "foreground-nested-collector-diagnostic-2.json",
)
CAPTURES = PRIMARY + DIAGNOSTICS
REQUIRED_JSON = CAPTURES + (
    "setup.json", "execution-ledger.json", "cleanup.json",
    "offline-tool-correlation.json", "provenance.json",
)
TERMINAL = {
    "session.execution.succeeded", "session.execution.failed", "session.execution.interrupted",
}
# Official session-event.ts declares version 2 for these four observed types;
# other observed durable types use its shared version-1 options. Event.Seq is
# nonnegative: a newly created native session starts at seq 0.
VERSION_TWO_EVENTS = {
    "session.instructions.updated", "session.tool.success", "session.tool.failed", "session.deleted",
}
SECRET_FIELDS = {
    "token", "code", "password", "authorization", "cookie", "setcookie",
    "encryptedcontent", "apikey", "accesstoken", "refreshtoken", "clientsecret",
    "servicepassword", "privatekey", "secretkey", "bearertoken",
}
CHECKS = []
DATA = {}


def check(name, condition):
    CHECKS.append({"check": name, "passed": bool(condition)})


def require(name, condition):
    check(name, condition)
    if not condition:
        raise ValueError("Evidence prerequisite failed")


def section(name, action):
    """Report damaged/missing evidence without emitting fixture values."""
    try:
        action()
    except (KeyError, TypeError, ValueError, IndexError, StopIteration, OSError):
        check(name + ":completeReadableEvidence", False)


def events(fixture, kind, sid=None):
    return [e for e in fixture["events"] if e["type"] == kind
            and (sid is None or e["data"]["sessionID"] == sid)]


def calls(fixture, method, path):
    return [c for c in fixture["calls"] if c["method"] == method
            and urlsplit(c["path"]).path == path]


def response(call):
    return call["response"]["data"]


def one(items):
    if len(items) != 1:
        raise ValueError("Expected one observed record")
    return items[0]


def tool_key(data):
    return data["sessionID"], data["assistantMessageID"], data["id"]


def tool_events(fixture, kind, key):
    return [e for e in events(fixture, kind) if tool_key(e["data"]) == key]


def history(fixture, sid, last=True):
    records = calls(fixture, "GET", "/api/session/" + sid + "/message")
    return response(records[-1 if last else 0])


def projected_tool(fixture, key):
    sid, mid, tid = key
    # A committed revert clears history, so inspect the last saved history that
    # still contains this tool. Never invent it from the event summary.
    for record in reversed(calls(fixture, "GET", "/api/session/" + sid + "/message")):
        parts = [c for m in response(record) if m["id"] == mid
                 for c in m.get("content", []) if c["type"] == "tool" and c["id"] == tid]
        if parts:
            return one(parts)
    raise ValueError("No projected native tool")


def assistant_text(messages):
    return "".join(c["text"] for m in messages if m["type"] == "assistant"
                   for c in m.get("content", []) if c["type"] == "text")


def dictionaries(value):
    if isinstance(value, dict):
        yield value
        for child in value.values():
            yield from dictionaries(child)
    elif isinstance(value, list):
        for child in value:
            yield from dictionaries(child)


def native_costs(value):
    # Catalog price arrays are checked separately. Numeric native cost appears
    # in sessions, projected assistant messages and usage events.
    return [d["cost"] for d in dictionaries(value)
            if "cost" in d and isinstance(d["cost"], (int, float))
            and not isinstance(d["cost"], bool)]


def load_fixtures():
    for name in REQUIRED_JSON:
        try:
            DATA[name] = json.loads((ROOT / name).read_text(encoding="utf-8"))
            check("files:readable:" + name, True)
        except (OSError, ValueError):
            check("files:readable:" + name, False)
    check("files:readmePresent", (ROOT / "README.md").is_file())


def common(name):
    f = DATA[name]
    label = name.removesuffix(".json")
    s = f["summary"]
    sid = s["rootSessionID"]
    check(label + ":nativeVersion", f["info"]["version"] == "2.0.22"
          and one(calls(f, "GET", "/api/info"))["response"] == f["info"])
    model = f["model"]
    check(label + ":selectedFreeActiveToolModel",
          model["modelID"] == MODEL["id"] and model["providerID"] == MODEL["providerID"]
          and model["enabled"] is True and model["status"] == "active"
          and model["capabilities"]["tools"] is True and bool(model["cost"])
          and all(c["input"] == c["output"] == c["cache"]["read"]
                  == c["cache"]["write"] == 0 for c in model["cost"]))
    prompt = one(calls(f, "POST", "/api/session/" + sid + "/prompt"))
    catalog_calls = [c for c in calls(f, "GET", "/api/model") if c["at"] < prompt["at"]]
    catalog_call = catalog_calls[-1]
    catalog = response(catalog_call)
    check(label + ":selectedModelMatchesCatalog",
          catalog_call["status"] == 200
          and one([m for m in catalog if m["id"] == model["id"]
                   and m["providerID"] == model["providerID"]]) == model)
    check(label + ":customAgentMatchesScopedCatalog",
          f["agent"]["id"] == f["agent"]["name"] == "capture-d"
          and f["agent"]["mode"] == "all" and f["agent"]["model"] == MODEL
          and one([a for a in response(one(calls(f, "GET", "/api/agent")))
                   if a["id"] == "capture-d"]) == f["agent"])
    costs = native_costs(f)
    check(label + ":allPresentNativeCostsZero", bool(costs) and all(c == 0 for c in costs))
    check(label + ":uniqueEventIDs", len({e["id"] for e in f["events"]}) == len(f["events"]))
    durable = [e for e in f["events"] if "durable" in e]
    check(label + ":durableIdentityAndSequence",
          len({(e["durable"]["aggregateID"], e["durable"]["seq"]) for e in durable})
          == len(durable) and all(e["durable"]["aggregateID"] == e["data"]["sessionID"]
                                    and type(e["durable"]["seq"]) is int
                                    and e["durable"]["seq"] >= 0
                                    and type(e["durable"]["version"]) is int
                                    and e["durable"]["version"] >= 1
                                    and e["durable"]["version"]
                                    == (2 if e["type"] in VERSION_TWO_EVENTS else 1)
                                    for e in durable))
    check(label + ":noStreamFailures", f["streamFailures"] == [])
    created = events(f, "session.created")
    check(label + ":committedProjectAndSelectedModel",
          bool(created) and all(e["data"]["projectID"] == PROJECT
                                and e["data"]["version"] == "2.0.22"
                                and e["data"]["agent"] == "capture-d"
                                and e["data"]["model"] == MODEL for e in created))
    manual_creates = calls(f, "POST", "/api/session")
    check(label + ":onlyRootCreatedByCollector",
          len(manual_creates) == 1 and response(manual_creates[0])["id"] == sid
          and not manual_creates[0]["request"].get("parentID"))
    admission = s["admission"]["data"]
    check(label + ":durableRootAdmission", prompt["status"] == 200
          and response(prompt) == admission and admission["sessionID"] == sid
          and admission["type"] == "user" and admission["delivery"] == "steer"
          and admission["payload"]["text"] == prompt["request"]["text"])
    for enqueued in events(f, "session.inbox.enqueued"):
        data = enqueued["data"]
        iid, owner = data["inboxID"], data["sessionID"]
        prefix = label + ":admission:" + iid
        delivered = events(f, "session.inbox.delivered", owner)
        check(prefix + ":durablyDelivered",
              "durable" in enqueued and len([e for e in delivered
                   if e["data"]["inboxID"] == iid and "durable" in e]) == 1)
        histories = [response(c) for c in calls(f, "GET", "/api/session/" + owner + "/message")]
        matches = [m for h in histories for m in h if m["id"] == iid]
        check(prefix + ":projectedNativeHistory", bool(matches)
              and all(m["type"] == data["item"]["type"]
                      and m.get("text") == data["item"]["payload"]["text"]
                      and m.get("metadata") == data["item"]["payload"].get("metadata")
                      for m in matches))
    for owner, state in s["finalStates"].items():
        prefix = label + ":final:" + owner
        check(prefix + ":authoritativeAPIHistory",
              state["messages"] == history(f, owner)
              and state["session"] == response(calls(f, "GET", "/api/session/" + owner)[-1]))
        check(prefix + ":settledOwnedInteractions",
              state["session"]["id"] == owner and state["session"]["projectID"] == PROJECT
              and state["session"]["model"] == MODEL and state["session"]["cost"] == 0
              and all(state[k] == [] for k in ("permissions", "forms", "inbox")))


def tool_checks(name):
    f = DATA[name]
    label = name.removesuffix(".json")
    starts = events(f, "session.tool.input.started")
    check(label + ":toolBoundarySetsMatch",
          {tool_key(e["data"]) for e in starts}
          == {tool_key(e["data"]) for e in events(f, "session.tool.called")}
          == {tool_key(e["data"]) for e in events(f, "session.tool.input.ended")})
    for started in starts:
        key = tool_key(started["data"])
        prefix = label + ":tool:" + key[2]
        called = one(tool_events(f, "session.tool.called", key))
        ended = one(tool_events(f, "session.tool.input.ended", key))
        check(prefix + ":nameOnlyOnInputStarted",
              bool(started["data"]["name"]) and "name" not in called["data"]
              and "tool" not in called["data"] and "name" not in ended["data"])
        check(prefix + ":rawInputEqualsCalled",
              json.loads(ended["data"]["text"]) == called["data"]["input"]
              and started["created"] <= ended["created"] <= called["created"])
        part = projected_tool(f, key)
        check(prefix + ":projectedToolIdentityAndInput",
              part["name"] == started["data"]["name"]
              and part["executed"] == called["data"]["executed"]
              and part["state"]["input"] == called["data"]["input"])
        success = tool_events(f, "session.tool.success", key)
        failures = tool_events(f, "session.tool.failed", key)
        check(prefix + ":exactlyOneToolTerminal", len(success) + len(failures) == 1)
        if success:
            result = one(success)["data"]
            check(prefix + ":projectedSuccessMatchesEvent",
                  part["state"]["status"] == "completed"
                  and part["state"]["content"] == result["content"]
                  and part["state"]["metadata"] == result["metadata"])
        if failures:
            check(prefix + ":projectedFailureMatchesEvent",
                  part["state"]["status"] == "error"
                  and part["state"]["error"] == one(failures)["data"]["error"])
    for asked in events(f, "permission.asked"):
        data = asked["data"]
        source = data["source"]
        key = (data["sessionID"], source["messageID"], source["id"])
        prefix = label + ":permission:" + data["id"]
        started = one(tool_events(f, "session.tool.input.started", key))
        called = one(tool_events(f, "session.tool.called", key))
        check(prefix + ":nativeToolOwnership",
              source["type"] == "tool" and started["data"]["name"] == data["action"]
              and called["created"] <= asked["created"])
        replies = [e for e in events(f, "permission.replied", data["sessionID"])
                   if e["data"]["requestID"] == data["id"]]
        reply_calls = calls(f, "POST", "/api/session/" + data["sessionID"]
                            + "/permission/" + data["id"] + "/reply")
        if data["id"] in f["summary"].get("approvedChildRequestIDs", []):
            check(prefix + ":onceReplyRecorded", len(replies) == len(reply_calls) == 1
                  and replies[0]["data"]["reply"] == "once"
                  and reply_calls[0]["request"] == {"decision": "once"}
                  and reply_calls[0]["status"] == 204)
        else:
            check(prefix + ":heldRequestNotApproved", replies == [] and reply_calls == [])
    if "approvedChildRequestIDs" in f["summary"]:
        check(label + ":approvedRequestsEqualOnceEvents",
              set(f["summary"]["approvedChildRequestIDs"])
              == {e["data"]["requestID"] for e in events(f, "permission.replied")
                  if e["data"]["reply"] == "once"})


def child_link(f, started, expected_status):
    key = tool_key(started["data"])
    prefix = "lineage:" + key[2]
    called = one(tool_events(f, "session.tool.called", key))["data"]
    progress = one(tool_events(f, "session.tool.progress", key))["data"]["metadata"]
    child = progress["sessionID"]
    created = one(events(f, "session.created", child))
    state = f["summary"]["finalStates"][child]
    part = projected_tool(f, key)
    check(prefix + ":nativeParentChildCreation",
          created["data"]["parentID"] == key[0] == state["session"]["parentID"]
          and created["data"]["title"] == called["input"]["description"]
          and progress["status"] == "running"
          and part["state"]["metadata"]["sessionID"] == child
          and part["state"]["metadata"]["status"] == expected_status)
    enqueued = one(events(f, "session.inbox.enqueued", child))["data"]["item"]
    check(prefix + ":nativeChildAdmission",
          enqueued["type"] == "user" and enqueued["payload"]["text"]
          == "You are a subagent spawned by another session.\n" + called["input"]["prompt"]
          and not calls(f, "POST", "/api/session/" + child + "/prompt"))
    check(prefix + ":foregroundToolRequested",
          called["input"]["agent"] == "capture-d" and called["input"]["background"] is False)
    return child


def foreground():
    f = DATA[PRIMARY[0]]
    root = f["summary"]["rootSessionID"]
    subagents = [e for e in events(f, "session.tool.input.started")
                 if e["data"]["name"] == "subagent"]
    require("foreground:twoActualSubagentTools", len(subagents) == 2)
    first = one([e for e in subagents if e["data"]["sessionID"] == root])
    child = child_link(f, first, "completed")
    second = one([e for e in subagents if e["data"]["sessionID"] == child])
    grandchild = child_link(f, second, "completed")
    check("foreground:threeNativeSessionsAndExecutions",
          {root, child, grandchild} == set(f["summary"]["finalStates"])
          and len(events(f, "session.created")) == len(events(f, "session.execution.started")) == 3)
    for sid in (root, child, grandchild):
        state = f["summary"]["finalStates"][sid]
        terminal = [e for e in f["events"] if e["type"] in TERMINAL
                    and e["data"]["sessionID"] == sid]
        check("foreground:markerAndTerminal:" + sid,
              state["session"]["outcome"] == "succeeded"
              and assistant_text(state["messages"]) == "D_NESTED_MARKER_OK"
              and len(terminal) == 1 and terminal[0]["type"] == "session.execution.succeeded"
              and state["messages"][-1]["type"] == "idle"
              and state["messages"][-1]["outcome"] == "succeeded")
    read = one([e for e in events(f, "session.tool.input.started", grandchild)
                if e["data"]["name"] == "read"])
    key = tool_key(read["data"])
    check("foreground:grandchildActuallyReadMarker",
          one(tool_events(f, "session.tool.called", key))["data"]["input"]
          == {"path": "nested-marker.txt"}
          and "D_NESTED_MARKER_OK" in one(tool_events(f, "session.tool.success", key))["data"]["content"][0]["text"])
    for started in subagents:
        key = tool_key(started["data"])
        metadata = projected_tool(f, key)["state"]["metadata"]
        native = one(tool_events(f, "session.tool.success", key))
        nested_terminal = one(events(f, "session.execution.succeeded", metadata["sessionID"]))
        check("foreground:childCompletedBeforeTool:" + key[2],
              nested_terminal["created"] <= native["created"]
              and native["data"]["content"][0]["text"]
              == '<subagent sessionID="' + metadata["sessionID"]
              + '" state="completed">\nD_NESTED_MARKER_OK\n</subagent>')
    check("foreground:noCollectorDiagnostics", f["summary"]["diagnostics"] == [])


def background():
    f = DATA[PRIMARY[1]]
    s = f["summary"]
    parent, child = s["rootSessionID"], s["childSessionID"]
    subagent = one([e for e in events(f, "session.tool.input.started", parent)
                   if e["data"]["name"] == "subagent"])
    check("background:actualNativeChild", child_link(f, subagent, "running") == child)
    check("background:onlyParentAndChildCreated", len(events(f, "session.created")) == 2
          and set(s["finalStates"]) == {parent, child})
    held = s["heldReadRequest"]
    asked = one([e for e in events(f, "permission.asked", child)
                 if e["data"]["id"] == held["id"]])
    key = (child, held["source"]["messageID"], held["source"]["id"])
    check("background:realNativeReadHeld",
          held == asked["data"] and held["action"] == "read"
          and held["resources"] == ["background-gate.txt"]
          and one(tool_events(f, "session.tool.input.started", key))["data"]["name"] == "read"
          and one(tool_events(f, "session.tool.called", key))["data"]["input"]
          == {"path": "background-gate.txt"}
          and any(held in response(c) for c in calls(f, "GET", "/api/session/" + child + "/permission")))
    moved = one(calls(f, "POST", "/api/session/" + parent + "/background"))
    check("background:nativeBackgroundRequest", moved["status"] == 204 and moved["request"] is None)
    parent_messages = s["finalStates"][parent]["messages"]
    notices = [m for m in parent_messages if m["type"] == "synthetic"
               and m.get("metadata", {}).get("source") != "subagent"]
    notice = one(notices)
    notice_event = one([e for e in events(f, "session.inbox.enqueued", parent)
                        if e["data"]["inboxID"] == notice["id"]])
    check("background:nativeSyntheticBackgroundNotice",
          notice["text"] == notice_event["data"]["item"]["payload"]["text"]
          and "User requested that active blocking work be moved to the background." in notice["text"]
          and "Interruptible gate child" in notice["text"])
    active = [response(c) for c in calls(f, "GET", "/api/session/active")]
    check("background:activeSnapshotsMatchSummary",
          all(s[k] in active for k in ("activeBeforeBackground", "activeParentIdleChildWaiting",
                                      "activeAfterIdleParentInterrupt", "activeAfterChildTerminal")))
    check("background:parentIdleDoesNotCompleteChild",
          s["activeBeforeBackground"] == {parent: {"type": "running"}, child: {"type": "running"}}
          and s["activeParentIdleChildWaiting"] == {child: {"type": "running"}})
    parent_interrupt = one(calls(f, "POST", "/api/session/" + parent + "/interrupt"))
    child_interrupt = one(calls(f, "POST", "/api/session/" + child + "/interrupt"))
    check("background:idleParentInterruptFalsePreservesChild",
          parent_interrupt["status"] == 200 and parent_interrupt["response"]
          == s["idleParentInterrupt"] == {"interrupted": False}
          and s["activeAfterIdleParentInterrupt"] == {child: {"type": "running"}}
          and parent_interrupt["at"] < child_interrupt["at"])
    check("background:explicitChildInterruptTrue",
          child_interrupt["status"] == 200 and child_interrupt["response"]
          == s["activeChildInterrupt"] == {"interrupted": True}
          and s["activeAfterChildTerminal"] == {})
    terminal = one(events(f, "session.execution.interrupted", child))
    check("background:childInterruptedByUser",
          terminal["data"]["reason"] == "user"
          and s["finalStates"][child]["session"]["outcome"] == "interrupted"
          and one(tool_events(f, "session.tool.failed", key))["data"]["error"]
          == {"type": "aborted", "message": "Tool execution interrupted"}
          and events(f, "session.tool.success", child) == [])
    completions = [(sid, m) for sid, state in s["finalStates"].items()
                   for m in state["messages"] if m["type"] == "synthetic"
                   and m.get("metadata", {}).get("source") == "subagent"]
    owner, completion = one(completions)
    check("background:oneNativeCancelledCompletionOwnedByParent",
          owner == parent and completion["metadata"] == {
              "source": "subagent", "childID": child, "agent": "capture-d", "state": "cancelled"}
          and completion["text"] == '<subagent sessionID="' + child
          + '" state="cancelled" description="Interruptible gate child">\nSubagent cancelled\n</subagent>')
    enqueued = one([e for e in events(f, "session.inbox.enqueued", parent)
                    if e["data"]["inboxID"] == completion["id"]])
    check("background:completionAdmissionMatchesNativeHistory",
          enqueued["data"]["item"]["type"] == "synthetic"
          and enqueued["data"]["item"]["payload"]["metadata"] == completion["metadata"]
          and enqueued["data"]["item"]["payload"]["text"] == completion["text"])
    parent_starts = events(f, "session.execution.started", parent)
    parent_success = events(f, "session.execution.succeeded", parent)
    check("background:parentResumesExactlyOnceForCompletion",
          len(parent_starts) == len(parent_success) == 2
          and parent_success[0]["created"] < enqueued["created"]
          <= parent_starts[1]["created"] <= parent_success[1]["created"]
          and terminal["created"] <= parent_starts[1]["created"]
          and len(events(f, "session.execution.started", child)) == 1)
    before = parent_messages[:parent_messages.index(completion)]
    check("background:parentLaunchedBeforeChildTerminal",
          assistant_text(before) == "D_BACKGROUND_PARENT_LAUNCHED"
          and before[-1]["type"] == "idle" and before[-1]["outcome"] == "succeeded"
          and parent_success[0]["created"] < terminal["created"])
    check("background:noManualSyntheticOrContinuationPrompt",
          not any(c["method"] == "POST" and (urlsplit(c["path"]).path.endswith("/synthetic")
                  or (urlsplit(c["path"]).path.endswith("/prompt")
                      and urlsplit(c["path"]).path != "/api/session/" + parent + "/prompt"))
                  for c in f["calls"]))
    check("background:noCollectorDiagnostics", s["diagnostics"] == [])


def revert():
    f = DATA[PRIMARY[2]]
    s = f["summary"]
    sid, boundary = s["rootSessionID"], s["boundaryMessageID"]
    phases = s["fileStates"]
    expected = ["baseline", "after-native-write", "stage-files-true", "clear-files-true",
                "stage-files-false", "clear-files-false", "stage-files-true-again", "commit"]
    require("revert:allEightOrderedFileSnapshots", [p["phase"] for p in phases] == expected)
    before, after = "D_REVERT_BEFORE\n", "D_REVERT_AFTER\n"
    expected_bytes = [before, after, before, after, after, after, before, before]
    diff = phases[1]["gitDiff"]
    check("revert:capturedNativeWriteDiff", diff.startswith("diff --git a/revert-target.txt b/revert-target.txt\n")
          and "\n-D_REVERT_BEFORE\n+D_REVERT_AFTER\n" in diff)
    for p, content in zip(phases, expected_bytes):
        check("revert:fileBytesHashAndDiff:" + p["phase"],
              p["file"] == "revert-target.txt" and p["utf8"] == content
              and p["byteLength"] == len(content.encode("utf-8"))
              and p["sha256"] == hashlib.sha256(content.encode("utf-8")).hexdigest()
              and p["gitDiff"] == ("" if content == before else diff))
    write = one(events(f, "session.tool.input.started", sid))
    key = tool_key(write["data"])
    check("revert:realNativeWriteTool",
          write["data"]["name"] == "write"
          and one(tool_events(f, "session.tool.called", key))["data"]["input"]
          == {"path": "revert-target.txt", "content": after}
          and one(tool_events(f, "session.tool.success", key))["data"]["content"]
          == [{"type": "text", "text": "Wrote file successfully: revert-target.txt"}])
    baseline_history = history(f, sid, last=False)
    check("revert:admissionIsBoundaryAndNativeWriteCompleted",
          boundary == s["admission"]["data"]["id"] == baseline_history[0]["id"]
          and assistant_text(baseline_history) == "D_REVERT_WRITE_DONE"
          and baseline_history[-1]["type"] == "idle"
          and baseline_history[-1]["outcome"] == "succeeded")
    tool_message = one([m for m in baseline_history if m["id"] == key[1]])
    snapshot = tool_message["snapshot"]
    check("revert:writeSnapshotActuallyChangesTarget",
          snapshot["start"] != snapshot["end"] and snapshot["files"] == ["revert-target.txt"])
    staged = [phases[i] for i in (2, 4, 6)]
    stage_calls = calls(f, "POST", "/api/session/" + sid + "/revert/stage")
    stage_events = events(f, "session.revert.staged", sid)
    require("revert:threeNativeStageResponsesAndEvents", len(stage_calls) == len(stage_events) == 3)
    for p, c, e, with_files in zip(staged, stage_calls, stage_events, (True, False, True)):
        r = p["authoritative"]["session"]["revert"]
        check("revert:stageMatchesAuthoritativeAPIAndEvent:" + p["phase"],
              c["status"] == 200 and c["request"] == {"messageID": boundary, "files": with_files}
              and response(c) == r == e["data"]["revert"]
              and r["messageID"] == boundary and r["snapshot"] == snapshot["end"])
        file_effect = (len(r["files"]) == 1 and r["files"][0]["file"] == "revert-target.txt"
                       and r["files"][0]["status"] == "modified"
                       and r["files"][0]["additions"] == r["files"][0]["deletions"] == 1
                       and "\n-D_REVERT_AFTER\n+D_REVERT_BEFORE\n" in r["files"][0]["patch"])
        check("revert:stageFileEffects:" + p["phase"], file_effect if with_files else r["files"] == [])
    for p in phases[2:7]:
        state = p["authoritative"]
        check("revert:stagingPreservesOriginalHistory:" + p["phase"],
              state["messages"][:len(baseline_history)] == baseline_history
              and all(m["type"] == "idle" and m["outcome"] == "succeeded"
                      for m in state["messages"][len(baseline_history):])
              and state["session"]["cost"] == 0
              and all(state[k] == [] for k in ("inbox", "permissions", "forms")))
        check("revert:phaseHasMatchingAPISnapshot:" + p["phase"],
              any(response(c) == state["messages"] for c in calls(f, "GET", "/api/session/" + sid + "/message"))
              and any(response(c) == state["session"] for c in calls(f, "GET", "/api/session/" + sid)))
    clear_calls = calls(f, "DELETE", "/api/session/" + sid + "/revert")
    clears = events(f, "session.revert.cleared", sid)
    require("revert:twoNativeClearCallsAndEvents", len(clear_calls) == len(clears) == 2)
    for p, c in zip((phases[3], phases[5]), clear_calls):
        check("revert:clearRestoresWriteAndRemovesStage:" + p["phase"],
              c["status"] == 204 and c["request"] is None
              and "revert" not in p["authoritative"]["session"] and p["utf8"] == after)
    starts = events(f, "session.execution.started", sid)
    successes = events(f, "session.execution.succeeded", sid)
    require("revert:writePlusTwoAutomaticNativeDrains", len(starts) == len(successes) == 3)
    for index, clear in enumerate(clears, 1):
        start, end = starts[index], successes[index]
        interval = [e for e in f["events"] if start["created"] <= e["created"] <= end["created"]]
        check("revert:clearGeneratedEmptyDrain:" + str(index),
              clear["created"] < start["created"] < end["created"]
              and [e["type"] for e in interval]
              == ["session.execution.started", "session.execution.succeeded"])
        pre, post = phases[2 if index == 1 else 4], phases[3 if index == 1 else 5]
        previous, current = pre["authoritative"]["messages"], post["authoritative"]["messages"]
        check("revert:drainAddsOnlyNativeIdleMarker:" + str(index),
              current[:-1] == previous and current[-1]["type"] == "idle"
              and current[-1]["outcome"] == "succeeded"
              and current[-1]["id"] == end["id"].replace("evt_", "msg_", 1)
              and pre["authoritative"]["session"]["cost"] == post["authoritative"]["session"]["cost"] == 0)
    commit = one(calls(f, "POST", "/api/session/" + sid + "/revert/commit"))
    committed = one(events(f, "session.revert.committed", sid))
    final = phases[-1]["authoritative"]
    check("revert:commitRemovesHistoryAndInboxPreservesRevertedFile",
          commit["status"] == 204 and commit["request"] is None
          and committed["data"]["to"] == boundary and "revert" not in final["session"]
          and all(final[k] == [] for k in ("messages", "inbox", "permissions", "forms"))
          and final == s["finalStates"][sid] and phases[-1]["utf8"] == before)
    check("revert:stageClearCommitEventOrder",
          [e["type"] for e in f["events"] if e["type"].startswith("session.revert.")]
          == ["session.revert.staged", "session.revert.cleared", "session.revert.staged",
              "session.revert.cleared", "session.revert.staged", "session.revert.committed"])
    check("revert:noCollectorDiagnosticsOrExtraPrompts",
          s["diagnostics"] == [] and len([c for c in f["calls"] if c["method"] == "POST"
              and urlsplit(c["path"]).path.endswith("/prompt")]) == 1)


def diagnostics():
    for name, expected in zip(DIAGNOSTICS, ("KeyError: 'tool'", "KeyError: 'name'")):
        f = DATA[name]
        s = f["summary"]
        sid = s["rootSessionID"]
        check(name + ":collectorFailurePreserved",
              s["diagnostics"] == [expected] and s["approvedChildRequestIDs"] == []
              and s["removedDisposableSessionIDs"] == [sid])
        check(name + ":noChildAcceptanceEvidence",
              len(events(f, "session.created")) == len(events(f, "session.execution.started")) == 1
              and set(s["finalStates"]) == {sid}
              and s["finalStates"][sid]["session"]["outcome"] == "interrupted"
              and one(events(f, "session.execution.interrupted", sid))["data"]["reason"] == "user"
              and events(f, "session.tool.progress") == []
              and events(f, "session.tool.success") == []
              and assistant_text(s["finalStates"][sid]["messages"]) == "")
    initial = DATA[DIAGNOSTICS[0]]
    model_snapshots = calls(initial, "GET", "/api/model")
    check("diagnostics:initialEmptyModelCatalogPreserved",
          len(model_snapshots) == 2 and response(model_snapshots[0]) == []
          and model_snapshots[0]["status"] == model_snapshots[1]["status"] == 200
          and response(model_snapshots[1]) != [])


def ledger():
    recorded = DATA["execution-ledger.json"]
    entries = recorded["executions"]
    all_events = [e for name in CAPTURES for e in DATA[name]["events"]]
    check("ledger:globallyUniqueNativeEventIDs",
          len({e["id"] for e in all_events}) == len(all_events))
    starts = [e for e in all_events if e["type"] == "session.execution.started"]
    check("ledger:allElevenActualExecutionsIncludingDiagnosticsAndAutomaticDrains",
          recorded["ceilingActualExecutions"] == 12 and len(entries) == len(starts) == 11
          and len(entries) <= recorded["ceilingActualExecutions"]
          and len({e["eventID"] for e in entries}) == 11
          and {e["eventID"] for e in entries} == {e["id"] for e in starts})
    check("ledger:observedDistribution",
          Counter(e["type"] for e in all_events if e["type"] in TERMINAL)
          == {"session.execution.succeeded": 8, "session.execution.interrupted": 3}
          and [len(events(DATA[n], "session.execution.started")) for n in CAPTURES] == [3, 3, 3, 1, 1])
    for name in CAPTURES:
        f = DATA[name]
        phase = name.split("-collector-diagnostic")[0].removesuffix(".json")
        for started in events(f, "session.execution.started"):
            entry = one([e for e in entries if e["eventID"] == started["id"]])
            sid = started["data"]["sessionID"]
            subsequent_starts = [e["created"] for e in events(f, "session.execution.started", sid)
                                 if e["created"] > started["created"]]
            upper = min(subsequent_starts) if subsequent_starts else float("inf")
            settled = one([e for e in f["events"] if e["type"] in TERMINAL
                           and e["data"]["sessionID"] == sid
                           and started["created"] <= e["created"] < upper])
            check("ledger:nativeStartAndTerminal:" + started["id"],
                  entry["sessionID"] == sid and entry["started"] == started["created"]
                  and entry["phase"] == phase and entry["terminal"] == settled["type"]
                  and entry["finished"] == settled["created"]
                  and entry["reason"] == settled["data"].get("reason"))
        partial = f["executionLedger"]["executions"]
        check("ledger:preservedCumulativeSnapshot:" + name,
              partial == entries[:len(partial)]
              and {e["id"] for e in events(f, "session.execution.started")}
              <= {e["eventID"] for e in partial})


def offline_correlations():
    artifact = DATA["offline-tool-correlation.json"]
    records = artifact["correlations"]
    check("offline:fourPreservedCorrelations", artifact["outcome"] == "passed" and len(records) == 4)
    expected = {(name, e["data"]["sessionID"], e["data"]["assistantMessageID"], e["data"]["id"])
                for name in (PRIMARY[0],) + DIAGNOSTICS
                for e in events(DATA[name], "session.tool.input.started")
                if e["data"]["name"] == "subagent"}
    check("offline:correlationOwnershipSet",
          {(r["fixture"], r["sessionID"], r["assistantMessageID"], r["toolID"]) for r in records} == expected)
    for r in records:
        f = DATA[r["fixture"]]
        key = (r["sessionID"], r["assistantMessageID"], r["toolID"])
        started = one(tool_events(f, "session.tool.input.started", key))["data"]
        called = one(tool_events(f, "session.tool.called", key))["data"]
        ended = one(tool_events(f, "session.tool.input.ended", key))["data"]
        asked = one([e for e in events(f, "permission.asked", key[0])
                     if e["data"]["source"]["messageID"] == key[1]
                     and e["data"]["source"]["id"] == key[2]])["data"]
        check("offline:computedNativeCorrelation:" + r["toolID"],
              started["name"] == r["nameFromInputStarted"] == "subagent"
              and asked["id"] == r["permissionRequestID"]
              and r["nameOrToolAbsentOnCalled"] is True and "name" not in called and "tool" not in called
              and r["rawInputEndedMatchesCalled"] is True and json.loads(ended["text"]) == called["input"])
        progress = tool_events(f, "session.tool.progress", key)
        check("offline:computedChildID:" + r["toolID"],
              r["childID"] == (one(progress)["data"]["metadata"]["sessionID"] if progress else None))


def setup_and_cleanup():
    setup = DATA["setup.json"]
    check("setup:projectCommittedBeforeNativeAccess",
          setup["initialGitCommit"] == PROJECT and setup["nativeAccessBeforeInitialCommit"] is False)
    check("setup:scopedFreeModelAndSnapshots",
          setup["config"]["model"] == "opencode/space-bunny-free#low"
          and setup["config"]["snapshots"] is True)
    expected_inputs = {
        "nested-marker.txt": "D_NESTED_MARKER_OK\n", "background-gate.txt": "D_BACKGROUND_MARKER_OK\n",
        "revert-target.txt": "D_REVERT_BEFORE\n",
    }
    check("setup:knownDisposableInputBytes", setup["inputs"] == expected_inputs)
    for name, content in {**expected_inputs, "revert-target-after.txt": "D_REVERT_AFTER\n"}.items():
        check("setup:retainedInputBytes:" + name, (ROOT / name).read_bytes() == content.encode("utf-8"))
    cleanup = DATA["cleanup.json"]
    owned = set(cleanup["allOwnedSessionIDs"])
    native_owned = {e["data"]["sessionID"] for name in CAPTURES
                    for e in events(DATA[name], "session.created")}
    disposed = set(cleanup["removedDisposableSessionIDs"])
    expected_disposed = {DATA[PRIMARY[1]]["summary"]["childSessionID"]}
    expected_disposed.update(DATA[n]["summary"]["rootSessionID"] for n in DIAGNOSTICS)
    check("cleanup:allEightOwnedSessionsThreeDisposedFiveRetained",
          owned == native_owned and len(owned) == 8 and disposed == expected_disposed and len(owned - disposed) == 5)
    active = response(one(calls(cleanup, "GET", "/api/session/active")))
    check("cleanup:noOwnedActiveSessions", not (owned & set(active))
          and cleanup["ownedActiveAfter"] == {k: v for k, v in active.items() if k in owned})
    for sid in sorted(owned):
        session = one(calls(cleanup, "GET", "/api/session/" + sid))
        if sid in disposed:
            check("cleanup:disposedNative404:" + sid,
                  session["status"] == 404 and session["response"]["_tag"] == "SessionNotFoundError"
                  and session["response"]["sessionID"] == sid)
            check("cleanup:recordedNativeDelete:" + sid,
                  any(c["status"] == 204 for name in CAPTURES
                      for c in calls(DATA[name], "DELETE", "/api/session/" + sid)))
        else:
            check("cleanup:retainedSessionSettled:" + sid,
                  session["status"] == 200 and response(session)["projectID"] == PROJECT
                  and response(session)["cost"] == 0 and response(session)["outcome"] == "succeeded")
            for kind in ("permission", "form", "inbox"):
                snapshot = one(calls(cleanup, "GET", "/api/session/" + sid + "/" + kind))
                check("cleanup:retainedEmpty:" + sid + ":" + kind,
                      snapshot["status"] == 200 and response(snapshot) == [])
    saved = one([c for c in cleanup["calls"] if c["method"] == "GET"
                 and c["path"] == "/api/permission/saved?projectID=" + PROJECT])
    check("cleanup:noSavedProjectGrants", saved["status"] == 200 and response(saved) == [])
    check("cleanup:summarySupportedByNativeCalls",
          cleanup["outcome"] == "passed" and cleanup["allRetainedOwnedInteractionsAndInboxEmpty"] is True
          and cleanup["savedProjectGrantsEmpty"] is True)


def provenance():
    p = DATA["provenance.json"]
    check("provenance:observedSubsetOnly",
          p["status"] == "delivered-awaiting-acceptance"
          and p.get("allDRequirementsAccepted", False) is False)
    check("provenance:actualBudgetAndCost",
          p["budget"]["actualExecutionsObserved"] == len(DATA["execution-ledger.json"]["executions"]) == 11
          and p["budget"]["actualExecutionCeiling"] == 12 and p["budget"]["observedCostUSD"] == 0)
    check("provenance:committedNativeProject",
          p["workspace"]["nativeProjectID"] == p["workspace"]["initialGitCommit"] == PROJECT)
    check("provenance:naturalRetryAndQuotaPending",
          p["pendingAcceptance"]["retry"]["nativeScheduledEventsObserved"] == 0
          and p["pendingAcceptance"]["retry"]["status"] == "inconclusive"
          and p["pendingAcceptance"]["quota"]["status"] == "inconclusive")


def redaction():
    failures = []

    def walk(value, key=""):
        normalized = re.sub(r"[^a-z0-9]", "", key.lower())
        if normalized in SECRET_FIELDS and value != "[REDACTED]":
            failures.append(key)
        if isinstance(value, dict):
            for child_key, child in value.items():
                walk(child, child_key)
        elif isinstance(value, list):
            for child in value:
                walk(child)

    # Previously generated reports are output, never evidence inputs.
    for path in sorted(ROOT.rglob("*.json")):
        if path.name != "validation.json":
            walk(json.loads(path.read_text(encoding="utf-8")))
    check("redaction:recursiveCredentialFields", failures == [])
    check("redaction:noCredentialEndpointCaptured",
          all(not urlsplit(c["path"]).path.startswith("/api/credential")
              for name in CAPTURES for c in DATA[name]["calls"]))


def manifest():
    path = ROOT / "SHA256SUMS"
    present = path.is_file()
    check("manifest:manifestPresent", present)
    if not present:
        return
    good, listed = True, set()
    for line in path.read_text(encoding="utf-8").splitlines():
        match = re.fullmatch(r"([0-9a-f]{64}) [ *](.+)", line)
        if not match:
            good = False
            continue
        digest, name = match.groups()
        target = ROOT / name
        if (name in listed or Path(name).is_absolute() or ".." in Path(name).parts
                or not target.resolve().is_relative_to(ROOT) or name == "SHA256SUMS"):
            good = False
            continue
        listed.add(name)
        good = good and target.is_file() and hashlib.sha256(target.read_bytes()).hexdigest() == digest
    check("manifest:allListedSHA256Digests", good and bool(listed))
    check("manifest:allRequiredEvidenceIncluded",
          set(REQUIRED_JSON) | {"README.md", "validate.py", "nested-marker.txt",
          "background-gate.txt", "revert-target.txt", "revert-target-after.txt"} <= listed)


def pending_coverage():
    native = [e for name in CAPTURES for e in DATA[name]["events"]]
    check("coverage:noNaturalRetryScheduledEvent", not any(e["type"] == "session.retry.scheduled" for e in native))
    quota = [d for d in dictionaries(native) if isinstance(d.get("type"), str)
             and re.search(r"quota|rate[._ -]?limit|throttl|overloaded", d["type"], re.I)]
    check("coverage:noNaturalQuotaOrRateLimitError", quota == [])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--report", action="store_true",
                        help="write deterministic validation.json after all read-only checks")
    args = parser.parse_args()
    load_fixtures()
    for name in CAPTURES:
        section(name, lambda name=name: common(name))
        section(name + ":tools", lambda name=name: tool_checks(name))
    for name, action in (
        ("foreground", foreground), ("background", background), ("revert", revert),
        ("diagnostics", diagnostics), ("ledger", ledger), ("offline", offline_correlations),
        ("cleanup", setup_and_cleanup), ("provenance", provenance),
        ("redaction", redaction), ("manifest", manifest), ("coverage", pending_coverage),
    ):
        section(name, action)
    failed = [c["check"] for c in CHECKS if not c["passed"]]
    report = {
        "unit": "V2-005D", "validationMode": "offline-read-only-evidence-checks",
        "outcome": "observed-subset-passed" if not failed else "failed",
        "allDRequirementsAccepted": False,
        "checksPassed": len(CHECKS) - len(failed), "checksFailed": len(failed),
        "observedActualExecutions": len(DATA.get("execution-ledger.json", {}).get("executions", [])),
        "executionCeiling": 12,
        "observedCostUsd": 0 if all(native_costs(DATA.get(n, {}))
                                   and all(c == 0 for c in native_costs(DATA[n]))
                                   for n in CAPTURES) else None,
        "pending": [
            {"scenario": "natural-provider-retry", "status": "pending/inconclusive",
             "reason": "No natural session.retry.scheduled was captured; source shape is not a runtime pass."},
            {"scenario": "natural-provider-quota-or-rate-limit", "status": "pending/inconclusive",
             "reason": "No natural quota/rate-limit failure was captured; no synthetic quota event proves it."},
        ],
        "checks": CHECKS,
    }
    if args.report:
        (ROOT / "validation.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    summary = {k: v for k, v in report.items() if k != "checks"}
    if failed:
        summary["failedChecks"] = failed
    print(json.dumps(summary, indent=2))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
