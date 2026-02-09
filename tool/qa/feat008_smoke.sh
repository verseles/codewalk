#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${1:-http://100.68.105.54:4096}"
OUT_DIR="${2:-/tmp/codewalk_feat008}"
PREFERRED_PROVIDER="${PREFERRED_PROVIDER:-openai}"
PREFERRED_MODEL="${PREFERRED_MODEL:-gpt-5.1-codex-mini}"
REQUEST_VARIANT="${REQUEST_VARIANT:-low}"

RUN_ID="$(date +%Y%m%d_%H%M%S)"
RUN_DIR="${OUT_DIR}/${RUN_ID}"
mkdir -p "${RUN_DIR}"

PASS_COUNT=0
FAIL_COUNT=0
SESSION_ID=""
PROVIDER_ID=""
MODEL_ID=""
TURN1_ID=""
TURN2_ID=""
LAST_ASSISTANT_ID=""

log() {
  printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"
}

record_pass() {
  local id="$1"
  local message="$2"
  echo "${id}:PASS:${message}" >> "${RUN_DIR}/results.txt"
  PASS_COUNT=$((PASS_COUNT + 1))
}

record_fail() {
  local id="$1"
  local reason="$2"
  echo "${id}:FAIL:${reason}" >> "${RUN_DIR}/results.txt"
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

finish_with_failure() {
  local id="$1"
  local reason="$2"
  record_fail "${id}" "${reason}"
  cat > "${RUN_DIR}/summary.txt" <<EOF
BASE_URL=${BASE_URL}
PREFERRED_PROVIDER=${PREFERRED_PROVIDER}
PREFERRED_MODEL=${PREFERRED_MODEL}
REQUEST_VARIANT=${REQUEST_VARIANT}
PROVIDER_ID=${PROVIDER_ID}
MODEL_ID=${MODEL_ID}
TURN1_ID=${TURN1_ID}
TURN2_ID=${TURN2_ID}
PASS_COUNT=${PASS_COUNT}
FAIL_COUNT=${FAIL_COUNT}
EOF
  log "QA smoke run finished with failure: ${id} - ${reason}"
  log "Artifacts: ${RUN_DIR}"
  exit 1
}

cleanup() {
  if [[ -n "${SESSION_ID}" ]]; then
    curl -fsS -X DELETE "${BASE_URL}/session/${SESSION_ID}" > "${RUN_DIR}/session_delete_response.json" 2>/dev/null || true
  fi
}
trap cleanup EXIT

extract_assistant_error() {
  local file="$1"
  jq -r '
    if .info.error == null then ""
    else
      (.info.error.name // "UnknownError")
      + ": "
      + (
          .info.error.data.message
          // .info.error.message
          // "Unknown error"
        )
    end
  ' "${file}"
}

wait_for_message_completion() {
  local qa_id="$1"
  local assistant_id="$2"
  local final_file="$3"

  for attempt in $(seq 1 90); do
    local poll_file="${RUN_DIR}/${qa_id}_poll_${attempt}.json"
    if ! curl -fsS "${BASE_URL}/session/${SESSION_ID}/message/${assistant_id}" > "${poll_file}"; then
      sleep 1
      continue
    fi

    if jq -e '.info.error != null' "${poll_file}" >/dev/null; then
      local err
      err="$(extract_assistant_error "${poll_file}")"
      finish_with_failure "${qa_id}" "assistant message returned error while polling (${err})"
    fi

    if jq -e '.info.time.completed != null' "${poll_file}" >/dev/null; then
      if jq -e '([.parts[]? | select(.type == "text" and (.text | tostring | length > 0))] | length) > 0' "${poll_file}" >/dev/null; then
        cp "${poll_file}" "${final_file}"
        return 0
      fi
    fi

    sleep 1
  done

  finish_with_failure "${qa_id}" "assistant message did not complete with text within timeout"
}

send_turn() {
  local qa_id="$1"
  local prompt="$2"
  local previous_assistant_id="${3:-}"
  local payload_file="${RUN_DIR}/${qa_id}_send_payload.json"
  local response_file="${RUN_DIR}/${qa_id}_send_response.json"
  local response_with_status_file="${RUN_DIR}/${qa_id}_send_response_with_status.txt"
  local final_message_file="${RUN_DIR}/${qa_id}_final_message.json"

  if [[ -n "${REQUEST_VARIANT}" && "${REQUEST_VARIANT}" != "auto" ]]; then
    jq -n \
      --arg pid "${PROVIDER_ID}" \
      --arg mid "${MODEL_ID}" \
      --arg variant "${REQUEST_VARIANT}" \
      --arg prompt "${prompt}" \
      '{
        model: {providerID: $pid, modelID: $mid},
        variant: $variant,
        noReply: false,
        parts: [{type: "text", text: $prompt}]
      }' > "${payload_file}"
  else
    jq -n \
      --arg pid "${PROVIDER_ID}" \
      --arg mid "${MODEL_ID}" \
      --arg prompt "${prompt}" \
      '{
        model: {providerID: $pid, modelID: $mid},
        noReply: false,
        parts: [{type: "text", text: $prompt}]
      }' > "${payload_file}"
  fi

  curl -sS -w '\n%{http_code}\n' \
    -X POST "${BASE_URL}/session/${SESSION_ID}/message" \
    -H "Content-Type: application/json" \
    --data @"${payload_file}" > "${response_with_status_file}"

  local status
  status="$(tail -n1 "${response_with_status_file}")"
  sed '$d' "${response_with_status_file}" > "${response_file}"

  if [[ "${status}" != "200" ]]; then
    finish_with_failure "${qa_id}" "unexpected HTTP status from send endpoint (${status})"
  fi

  local assistant_id
  assistant_id="$(jq -r '.info.id // empty' "${response_file}")"
  if [[ -z "${assistant_id}" ]]; then
    finish_with_failure "${qa_id}" "send response missing assistant message id"
  fi

  if [[ -n "${previous_assistant_id}" && "${assistant_id}" == "${previous_assistant_id}" ]]; then
    finish_with_failure "${qa_id}" "assistant id repeated from previous turn (${assistant_id})"
  fi

  if jq -e '.info.error != null' "${response_file}" >/dev/null; then
    local err
    err="$(extract_assistant_error "${response_file}")"
    finish_with_failure "${qa_id}" "immediate assistant response returned error (${err})"
  fi

  wait_for_message_completion "${qa_id}" "${assistant_id}" "${final_message_file}"
  record_pass "${qa_id}" "turn completed with non-empty assistant text"
  LAST_ASSISTANT_ID="${assistant_id}"
  return 0
}

log "Starting Feature 008 smoke run"
log "Base URL: ${BASE_URL}"
log "Run dir: ${RUN_DIR}"

# QA-001: Provider/model bootstrap with preferred defaults
if ! curl -fsS "${BASE_URL}/provider" > "${RUN_DIR}/provider_raw.json"; then
  finish_with_failure "QA-001" "failed to fetch /provider"
fi

if jq -e --arg p "${PREFERRED_PROVIDER}" '.all | any(.[]; .id == $p)' "${RUN_DIR}/provider_raw.json" >/dev/null; then
  PROVIDER_ID="${PREFERRED_PROVIDER}"
else
  PROVIDER_ID="$(jq -r '.connected[0] // .all[0].id // empty' "${RUN_DIR}/provider_raw.json")"
fi

if [[ -z "${PROVIDER_ID}" ]]; then
  finish_with_failure "QA-001" "could not determine provider id"
fi

if jq -e --arg p "${PROVIDER_ID}" --arg m "${PREFERRED_MODEL}" \
  '.all[] | select(.id == $p) | (.models | has($m))' "${RUN_DIR}/provider_raw.json" >/dev/null; then
  MODEL_ID="${PREFERRED_MODEL}"
else
  MODEL_ID="$(jq -r --arg p "${PROVIDER_ID}" '
    .default[$p]
    // (.all[] | select(.id == $p) | (.models | keys[0]))
    // empty
  ' "${RUN_DIR}/provider_raw.json")"
fi

if [[ -z "${MODEL_ID}" ]]; then
  finish_with_failure "QA-001" "could not determine model id for provider ${PROVIDER_ID}"
fi

jq --arg provider "${PROVIDER_ID}" \
  --arg model "${MODEL_ID}" \
  --arg preferredProvider "${PREFERRED_PROVIDER}" \
  --arg preferredModel "${PREFERRED_MODEL}" '
  {
    preferredProvider: $preferredProvider,
    preferredModel: $preferredModel,
    selectedProvider: $provider,
    selectedModel: $model,
    connected: .connected,
    selectedProviderDefault: .default[$provider],
    selectedProviderModels: (
      .all[]
      | select(.id == $provider)
      | (.models | keys)
    )
  }' "${RUN_DIR}/provider_raw.json" > "${RUN_DIR}/provider_selection.json"

rm -f "${RUN_DIR}/provider_raw.json"
record_pass "QA-001" "provider/model resolved (${PROVIDER_ID}/${MODEL_ID})"

# QA-002: Session lifecycle create
jq -n --arg title "QA Feature 008 ${RUN_ID}" '{title: $title}' > "${RUN_DIR}/session_create_payload.json"
if ! curl -fsS -X POST "${BASE_URL}/session" \
  -H "Content-Type: application/json" \
  --data @"${RUN_DIR}/session_create_payload.json" > "${RUN_DIR}/session_create.json"; then
  finish_with_failure "QA-002" "failed to create session"
fi

SESSION_ID="$(jq -r '.id // empty' "${RUN_DIR}/session_create.json")"
if [[ -z "${SESSION_ID}" ]]; then
  finish_with_failure "QA-002" "session create response missing id"
fi
record_pass "QA-002" "session created (${SESSION_ID})"

# QA-003: /event endpoint reachability and headers
set +e
timeout 10s curl -N -sS -D "${RUN_DIR}/event_headers.txt" "${BASE_URL}/event" > "${RUN_DIR}/event_sample.txt"
EVENT_RC=$?
set -e

if [[ "${EVENT_RC}" -ne 0 && "${EVENT_RC}" -ne 28 && "${EVENT_RC}" -ne 124 ]]; then
  finish_with_failure "QA-003" "event endpoint request failed with rc=${EVENT_RC}"
fi

EVENT_STATUS="$(head -n1 "${RUN_DIR}/event_headers.txt" | awk '{print $2}')"
EVENT_CONTENT_TYPE="$(grep -i '^Content-Type:' "${RUN_DIR}/event_headers.txt" | tail -n1 | tr -d '\r')"
if [[ "${EVENT_STATUS}" != "200" ]]; then
  finish_with_failure "QA-003" "event endpoint returned status ${EVENT_STATUS}"
fi
if [[ "${EVENT_CONTENT_TYPE}" != *"text/event-stream"* ]]; then
  finish_with_failure "QA-003" "event endpoint content-type is not text/event-stream"
fi
record_pass "QA-003" "event endpoint reachable (HTTP 200 + text/event-stream)"

# QA-004 and QA-005: Two-turn chat in same session with strict success criteria
send_turn "QA-004" "Responda apenas: OK-1"
TURN1_ID="${LAST_ASSISTANT_ID}"
send_turn "QA-005" "Responda apenas: OK-2" "${TURN1_ID}"
TURN2_ID="${LAST_ASSISTANT_ID}"

# QA-006: Final message list sanity
if ! curl -fsS "${BASE_URL}/session/${SESSION_ID}/message" > "${RUN_DIR}/messages.json"; then
  finish_with_failure "QA-006" "failed to list session messages"
fi

if ! jq -e --arg t1 "${TURN1_ID}" --arg t2 "${TURN2_ID}" '
  ([.[] | select((.role // .info.role) == "assistant" and .info.error == null)] | length) >= 2
  and (any(.[]; (.id // .info.id) == $t1))
  and (any(.[]; (.id // .info.id) == $t2))
' "${RUN_DIR}/messages.json" >/dev/null; then
  finish_with_failure "QA-006" "session list does not contain two successful assistant turns"
fi
record_pass "QA-006" "session contains two successful assistant turns"

# Explicit delete to verify lifecycle endpoint
if ! curl -fsS -X DELETE "${BASE_URL}/session/${SESSION_ID}" > "${RUN_DIR}/session_delete_response.json"; then
  finish_with_failure "QA-007" "failed to delete session"
fi
SESSION_ID=""
record_pass "QA-007" "session deleted"

cat > "${RUN_DIR}/summary.txt" <<EOF
BASE_URL=${BASE_URL}
PREFERRED_PROVIDER=${PREFERRED_PROVIDER}
PREFERRED_MODEL=${PREFERRED_MODEL}
REQUEST_VARIANT=${REQUEST_VARIANT}
PROVIDER_ID=${PROVIDER_ID}
MODEL_ID=${MODEL_ID}
TURN1_ID=${TURN1_ID}
TURN2_ID=${TURN2_ID}
PASS_COUNT=${PASS_COUNT}
FAIL_COUNT=${FAIL_COUNT}
EOF

log "QA smoke run finished: pass=${PASS_COUNT}, fail=${FAIL_COUNT}"
log "Artifacts: ${RUN_DIR}"
