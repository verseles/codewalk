#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${1:-http://100.68.105.54:4096}"
OUT_DIR="${2:-/tmp/codewalk_feat008}"
RUN_ID="$(date +%Y%m%d_%H%M%S)"
RUN_DIR="${OUT_DIR}/${RUN_ID}"
mkdir -p "${RUN_DIR}"

PASS_COUNT=0
FAIL_COUNT=0
SESSION_ID=""
PROVIDER_ID=""
MODEL_ID=""

log() {
  printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"
}

record_pass() {
  local id="$1"
  echo "${id}:PASS" >> "${RUN_DIR}/results.txt"
  PASS_COUNT=$((PASS_COUNT + 1))
}

record_fail() {
  local id="$1"
  local reason="$2"
  echo "${id}:FAIL:${reason}" >> "${RUN_DIR}/results.txt"
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

cleanup() {
  if [[ -n "${SESSION_ID}" ]]; then
    curl -fsS -X DELETE "${BASE_URL}/session/${SESSION_ID}" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

log "Starting Feature 008 smoke run"
log "Base URL: ${BASE_URL}"
log "Run dir: ${RUN_DIR}"

# QA-001/QA-002 bootstrap: provider + session CRUD
{
  curl -fsS "${BASE_URL}/provider" > "${RUN_DIR}/provider.json"
  PROVIDER_ID="$(jq -r '.connected[0] // .all[0].id // empty' "${RUN_DIR}/provider.json")"
  if [[ -z "${PROVIDER_ID}" ]]; then
    echo "No connected/available provider found" >&2
    exit 1
  fi

  MODEL_ID="$(jq -r --arg p "${PROVIDER_ID}" '.default[$p] // (.all[] | select(.id==$p).models | keys[0]) // empty' "${RUN_DIR}/provider.json")"
  if [[ -z "${MODEL_ID}" ]]; then
    echo "No model found for provider ${PROVIDER_ID}" >&2
    exit 1
  fi

  jq -n --arg title "QA Feature 008 ${RUN_ID}" '{title: $title}' > "${RUN_DIR}/session_create_payload.json"
  curl -fsS -X POST "${BASE_URL}/session" \
    -H "Content-Type: application/json" \
    --data @"${RUN_DIR}/session_create_payload.json" > "${RUN_DIR}/session_create.json"
  SESSION_ID="$(jq -r '.id // empty' "${RUN_DIR}/session_create.json")"
  if [[ -z "${SESSION_ID}" ]]; then
    echo "Failed to create session: missing id" >&2
    exit 1
  fi

  curl -fsS "${BASE_URL}/session" > "${RUN_DIR}/session_list.json"
  if ! jq -e --arg sid "${SESSION_ID}" 'any(.[]; .id == $sid)' "${RUN_DIR}/session_list.json" >/dev/null; then
    echo "Created session not found in list" >&2
    exit 1
  fi
}
record_pass "QA-001"
record_pass "QA-002"

# QA-003 chat + summarize
{
  MSG_ID="msg_qa_${RUN_ID}"
  jq -n \
    --arg pid "${PROVIDER_ID}" \
    --arg mid "${MODEL_ID}" \
    --arg msg "${MSG_ID}" \
    '{
      model: {providerID: $pid, modelID: $mid},
      messageID: $msg,
      noReply: false,
      parts: [{type: "text", text: "Reply with OK for QA feature 008."}]
    }' > "${RUN_DIR}/send_message_payload.json"

  curl -fsS -X POST "${BASE_URL}/session/${SESSION_ID}/message" \
    -H "Content-Type: application/json" \
    --data @"${RUN_DIR}/send_message_payload.json" > "${RUN_DIR}/send_message_response.json"

  ASSISTANT_FOUND=0
  for _ in $(seq 1 20); do
    curl -fsS "${BASE_URL}/session/${SESSION_ID}/message" > "${RUN_DIR}/messages.json"
    if jq -e '[.[] | select((.role // .info.role) == "assistant")] | length > 0' "${RUN_DIR}/messages.json" >/dev/null; then
      ASSISTANT_FOUND=1
      break
    fi
    sleep 2
  done
  if [[ "${ASSISTANT_FOUND}" -ne 1 ]]; then
    echo "Assistant message not found after polling window" >&2
    exit 1
  fi

  jq -n --arg pid "${PROVIDER_ID}" --arg mid "${MODEL_ID}" '{providerID: $pid, modelID: $mid}' > "${RUN_DIR}/summarize_payload.json"
  curl -fsS -X POST "${BASE_URL}/session/${SESSION_ID}/summarize" \
    -H "Content-Type: application/json" \
    --data @"${RUN_DIR}/summarize_payload.json" > "${RUN_DIR}/summarize_response.json"
}
record_pass "QA-003"

# QA-004 timeout constrained profile
{
  set +e
  curl -sS --max-time 0.001 "${BASE_URL}/provider" > "${RUN_DIR}/timeout_provider_output.txt" 2> "${RUN_DIR}/timeout_provider_error.txt"
  RC=$?
  set -e
  if [[ "${RC}" -eq 0 ]]; then
    echo "Timeout profile did not timeout as expected" >&2
    exit 1
  fi
  echo "${RC}" > "${RUN_DIR}/timeout_provider_rc.txt"
}
record_pass "QA-004"

# QA-005 intermittent disconnect + recovery
{
  set +e
  curl -sS --max-time 2 "http://127.0.0.1:1/provider" > "${RUN_DIR}/disconnect_output.txt" 2> "${RUN_DIR}/disconnect_error.txt"
  DISCONNECT_RC=$?
  set -e
  if [[ "${DISCONNECT_RC}" -eq 0 ]]; then
    echo "Expected connection failure did not happen" >&2
    exit 1
  fi
  echo "${DISCONNECT_RC}" > "${RUN_DIR}/disconnect_rc.txt"

  curl -fsS "${BASE_URL}/provider" > "${RUN_DIR}/recovery_provider.json"
  jq -e '.all | length > 0' "${RUN_DIR}/recovery_provider.json" >/dev/null
}
record_pass "QA-005"

# Delete session explicitly and disable trap cleanup for this resource
curl -fsS -X DELETE "${BASE_URL}/session/${SESSION_ID}" > "${RUN_DIR}/session_delete_response.json"
SESSION_ID=""

cat > "${RUN_DIR}/summary.txt" <<EOF
BASE_URL=${BASE_URL}
PROVIDER_ID=${PROVIDER_ID}
MODEL_ID=${MODEL_ID}
PASS_COUNT=${PASS_COUNT}
FAIL_COUNT=${FAIL_COUNT}
EOF

log "QA smoke run finished: pass=${PASS_COUNT}, fail=${FAIL_COUNT}"
log "Artifacts: ${RUN_DIR}"
