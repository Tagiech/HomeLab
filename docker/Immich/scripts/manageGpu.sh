#!/usr/bin/env bash
set -euo pipefail

#--------------- Params init ---------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CONFIG_FILE="$SCRIPT_DIR/.manageGpu.env"
[[ -f "$CONFIG_FILE" ]] && source "$CONFIG_FILE"

LOG_FILE="${LOG_FILE:-${SCRIPT_DIR}/manageGpu.log}"

: "${IMMICH_API_KEY:?IMMICH_API_KEY is not set}"
IMMICH_BASE_URL="${IMMICH_BASE_URL:?IMMICH_BASE_URL is not set}"
CHECK_INTERVAL="${CHECK_INTERVAL:-2}"

#--------------- Helpers ----------------
log() {
  local msg="$1"
  local ts
  ts="$(date '+%F %T')"
  echo "$ts  $msg" >>"$LOG_FILE" 2>/dev/null || true
}

api_get_config() {
  curl -sf --max-time 10 \
    -H "Accept: application/json" \
    -H @<(printf "x-api-key: %s" "$IMMICH_API_KEY") \
    "${IMMICH_BASE_URL}/system-config"
}

api_put_config() {
  local body="$1"
  curl -sf --max-time 10 \
    -X PUT \
    -H "Content-Type: application/json" \
    -H @<(printf "x-api-key: %s" "$IMMICH_API_KEY") \
    "${IMMICH_BASE_URL}/system-config" \
    -d "$body"
}

is_plex_on_gpu() {
  nvidia-smi pmon -c 1 2>/dev/null | grep -E "Plex|plex" >/dev/null
}

set_ml_state() {
  local desired="$1"

  local cfg
  if ! cfg="$(api_get_config)"; then
    log "ERROR: failed to GET /system-config"
    return
  fi

  local current
  current="$(echo "$cfg" | jq -r '.machineLearning.enabled')"

  if [[ "$current" == "$desired" ]]; then
    return
  fi

  local new_cfg
  if [[ "$desired" == "true" ]]; then
    new_cfg="$(echo "$cfg" | jq '.machineLearning.enabled = true')"
  else
    new_cfg="$(echo "$cfg" | jq '.machineLearning.enabled = false')"
  fi

  if api_put_config "$new_cfg"; then
    log "machineLearning.enabled set to ${desired}"
  else
    log "ERROR: failed to PUT /system-config (desired=${desired})"
  fi
}

#--------------- Main ----------------
main_loop() {
  local state="unknown"

  log "Immich GPU watchdog started (base URL: ${IMMICH_BASE_URL})"

  while true; do
    if is_plex_on_gpu; then
      if [[ "$state" != "plex-active" ]]; then
        set_ml_state "false"
        state="plex-active"
        log "INFO: plex is active, turned immich off"
      fi
    else
      if [[ "$state" != "idle" ]]; then
        set_ml_state "true"
        state="idle"
        log "INFO: plex is inactive, turned immich on"
      fi
    fi

    sleep "$CHECK_INTERVAL"
  done
}

main_loop
