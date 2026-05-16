#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/.pg_backup.env"
LOGFILE="$SCRIPT_DIR/pg_backup.log"
TIMESTAMP=$(date +%F_%H-%M)

log() {
   printf '%s %s\n' "$TIMESTAMP" "$1" >> "$LOGFILE"
}

if [[ -f "$CONFIG_FILE" ]]; then
  source "$CONFIG_FILE"
else
  log "ERROR: Config file $CONFIG_FILE not found" 
  exit 1
fi

: "${POSTGRES_PASSWORD:?'POSTGRES_PASSWORD is not set in .pg_backup.env'}"

is_sunday() {
  [[ "$(date +%u)" == "7" ]]
}

if is_sunday; then
  TYPE="weekly"
  KEEP=${WEEKLY_KEEP:-4}
else
  TYPE="daily"
  KEEP=${DAILY_KEEP:-7}
fi

mkdir -p "$BACKUP_BASE_DIR" || {
  log "ERROR: Cannot create base backup dir $BACKUP_BASE_DIR" >&2;
  exit 2;
  }
docker exec -u 0 -i "$POSTGRES_CONTAINER" \
    sh -c "mkdir -p '$CONTAINER_BACKUP_DIR'" || {
      log "ERROR: Cannot create container backup dir $CONTAINER_BACKUP_DIR" >&2;
      exit 2;
      }

# ------------MAIN-------------
for DB in $DB_LIST; do
  FILENAME="${DB}_${TYPE}_${TIMESTAMP}.dump"

  HOST_TARGET_DIR="$BACKUP_BASE_DIR/$DB"
  CONTAINER_TARGET_DIR="$CONTAINER_BACKUP_DIR/$DB"

  CONTAINER_FILE_PATH="${CONTAINER_TARGET_DIR}/${FILENAME}"

  mkdir -p "$HOST_TARGET_DIR" || {
      log "[DB:$DB] ERROR: cannot create target dir $HOST_TARGET_DIR";
      continue;
    }
  docker exec -u 0 -i "$POSTGRES_CONTAINER" sh -c "mkdir -p '$CONTAINER_BACKUP_DIR/$DB'" || {
    log "ERROR: Cannot create container target dir $CONTAINER_BACKUP_DIR/$DB" >&2;
    continue;
    }

  LOCKDIR="/var/lock/pg_backup_${DB}.lock"
  if ! mkdir "$LOCKDIR" 2>/dev/null; then
    log "[DB:$DB] SKIP: another backup is running"
    continue
  fi

  ERRFILE=$(mktemp)
  if docker exec -e PGPASSWORD="$POSTGRES_PASSWORD" -i "$POSTGRES_CONTAINER" \
       sh -c "pg_dump -U '$POSTGRES_USER' -d '$DB' -F c --no-owner --no-privileges -f '$CONTAINER_FILE_PATH'" 2>"$ERRFILE"; then

    docker exec -u 0 -i "$POSTGRES_CONTAINER" sh -c "test -s '$CONTAINER_FILE_PATH'" || {
      log "[DB:$DB] ERROR: dump empty, removing.";
      docker exec -u 0 -i "$POSTGRES_CONTAINER" sh -c "rm -f '$CONTAINER_FILE_PATH'";
      rm -f "$ERRFILE";
      continue;
    }

    docker exec -u 0 -i "$POSTGRES_CONTAINER" sh -c "gzip '$CONTAINER_FILE_PATH'"
    docker exec -u 0 -i "$POSTGRES_CONTAINER" sh -c \
     "cd '${CONTAINER_BACKUP_DIR}/${DB}' && sha256sum '${FILENAME}.gz'" \
      | sed "s|${FILENAME}.gz|${HOST_TARGET_DIR}/${FILENAME}.gz|" \
     > "${HOST_TARGET_DIR}/${FILENAME}.gz.sha256"

    log "[DB:$DB] INFO: Created $TYPE backup: $HOST_TARGET_DIR/$FILENAME.gz"

  else
    ERRMSG=$(tr '\n' ' ' <"$ERRFILE")
    log "[DB:$DB] ERROR: $ERRMSG"
    rm -f "$ERRFILE"
    rm -rf "$LOCKDIR"
    docker exec -u 0 -i "$POSTGRES_CONTAINER" sh -c "rm -f '$CONTAINER_FILE_PATH'"
    continue
  fi

  rm -f "$ERRFILE"
  rm -rf "$LOCKDIR"

  ls -1t "$HOST_TARGET_DIR"/*.gz 2>/dev/null \
    | grep "${DB}_${TYPE}_" \
    | tail -n +$((KEEP+1)) \
    | while read -r old; do
      rm -f "$old" "$old.sha256"
      log "[DB:$DB] INFO: Removed old $TYPE backup: $old"
    done

done

exit 0
