#!/bin/bash
# EXO 守護進程 v3.3 - 穩定版：PID 存活優先判斷，移除誤判記憶體檢查
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/tmp/exo.log"
MONITOR_LOG="/tmp/monitor.log"
PID_FILE="/tmp/exo.pid"
MAX_RETRIES=5
RETRY_DELAY=10
HEALTH_CHECK_PORT="52415"

CHECK_INTERVAL=10
PEER_CHECK_INTERVAL=3
MAX_PEER_ABSENT_CYCLES=10
LOG_STALE_TIMEOUT=3000

if [[ "$OSTYPE" == "darwin"* ]]; then
  ROLE="mac"
  export EXO_LIBP2P_NAMESPACE="wilson-cluster"
  export EXO_MODELS_DIRS="/Users/wilson/.lmstudio/models/"
  export EXO_RSYNC_TARGETS="admin@sparka:/home/admin/.lmstudio/models/,admin@sparkb:/home/admin/.lmstudio/models/"
  export PATH="/opt/homebrew/bin:/Users/wilson/.cargo/bin:/usr/bin:/bin:/usr/sbin:/sbin:/Users/wilson/.local/bin"
  EXO_CMD="/Users/wilson/exo/.venv/bin/exo"
  CD_DIR="/Users/wilson/exo"
else
  ROLE="worker"
  export EXO_LIBP2P_NAMESPACE="wilson-cluster"
  export EXO_RSYNC_MODEL_SOURCE="wilson@192.168.8.250:/Users/wilson/.exo/models/"
  export EXO_MODEL_SOURCE="rsync-only"
  export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/home/admin/.local/bin:/usr/local/bin"
  EXO_CMD="/home/admin/exo/.venv/bin/exo"
  CD_DIR="/home/admin/exo"
fi

export PATH

log() {
  local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [$ROLE] $1"
  echo "$msg" >> "$MONITOR_LOG"
}

health_check() {
  curl -s -o /dev/null -w "%{http_code}" "http://localhost:$HEALTH_CHECK_PORT/state" 2>/dev/null
}

check_peers() {
  local state=$(curl -s "http://localhost:$HEALTH_CHECK_PORT/state" 2>/dev/null)
  if [ -z "$state" ]; then return 2; fi

  local peer_count=$(echo "$state" | python3 -c "
import sys, json
try:
  d = json.load(sys.stdin)
  print(len(d.get('nodeIdentities', {})))
except: print(0)
" 2>/dev/null)

  [ -z "$peer_count" ] || [ "$peer_count" -le 0 ] && return 2
  [ "$peer_count" -ge 2 ] && return 0 || return 1
}

check_log_stale() {
  if [ ! -f "$LOG_FILE" ]; then return 0; fi
  local now=$(date +%s)
  local mtime=$(stat -c %Y "$LOG_FILE" 2>/dev/null || stat -f %m "$LOG_FILE" 2>/dev/null)
  if [ -z "$mtime" ]; then return 0; fi
  local age=$((now - mtime))
  if [ "$age" -gt "$LOG_STALE_TIMEOUT" ]; then
    log "日誌 ${age} 秒未更新，視為進程卡死"
    return 1
  fi
  return 0
}

cleanup() {
  log "清理舊進程..."
  pkill -f "uv run exo" 2>/dev/null || true
  sleep 1
  pkill -f "\.venv/bin/exo" 2>/dev/null || true
  pkill -f "multiprocessing" 2>/dev/null || true
  sleep 2
  pgrep -f "\.venv/bin/exo" > /dev/null && { pkill -9 -f "\.venv/bin/exo" 2>/dev/null || true; }
  pgrep -f "multiprocessing" > /dev/null && { pkill -9 -f "multiprocessing" 2>/dev/null || true; sleep 1; }
  rm -f /tmp/exo_initial_idx
}

start_exo() {
  local retry_count=0
  while [ $retry_count -lt $MAX_RETRIES ]; do
    log "啟動 exo (${retry_count}/$MAX_RETRIES)..."
    cleanup
    cd "$CD_DIR" || { log "無法進入 $CD_DIR"; return 1; }
    nohup "$EXO_CMD" > "$LOG_FILE" 2>&1 &
    local pid=$!
    echo $pid > "$PID_FILE"
    log "PID: $pid"
    sleep 15
    local code=$(health_check)
    if [ "$code" = "200" ]; then
      log "exo 啟動成功"
      return 0
    fi
    log "健康檢查失敗 (HTTP $code)，重試..."
    retry_count=$((retry_count + 1))
    sleep $RETRY_DELAY
  done
  log "啟動失敗，已重試 $MAX_RETRIES 次"
  return 1
}

kill_old_monitors() {
  if [ "$ROLE" = "worker" ]; then
    local self_pid=$$
    for pid in $(pgrep -f "monitor-exo" 2>/dev/null); do
      if [ "$pid" != "$self_pid" ] && [ "$pid" != "$(pgrep -f "bash.*monitor-exo" 2>/dev/null)" ]; then
        kill "$pid" 2>/dev/null || true
      fi
    done
  fi
}

main() {
  log "=== EXO 守護進程 v3.3 啟動 ==="
  log "角色: $ROLE | 目錄: $CD_DIR"

  kill_old_monitors

  local check_count=0
  local peer_absent_cycles=0
  local init_delay_done=0
  local startup_grace_done=0

  while true; do
    check_count=$((check_count + 1))

    if [ $init_delay_done -eq 0 ] && pgrep -f "\.venv/bin/exo" > /dev/null; then
      sleep 30
      init_delay_done=1
      log "初始延遲完成，全面監控"
    fi

    if ! pgrep -f "\.venv/bin/exo" > /dev/null; then
      log "進程未運行，重啟..."
      start_exo
      init_delay_done=0
      peer_absent_cycles=0
      continue
    fi

    local code=$(health_check)
    if [ "$code" != "200" ]; then
      log "健康檢查失敗 (HTTP $code)，重啟..."
      start_exo
      init_delay_done=0
      peer_absent_cycles=0
      continue
    fi

    if ! check_log_stale; then
      log "進程卡死，重啟..."
      start_exo
      init_delay_done=0
      peer_absent_cycles=0
      continue
    fi

    if [ $startup_grace_done -eq 0 ] && [ $check_count -ge 12 ]; then
      startup_grace_done=1
      log "啟動寬限期結束，開始節點檢查"
      check_peers
      local peer_ok=$?

      if [ $peer_ok -ne 0 ]; then
        peer_absent_cycles=$((peer_absent_cycles + 1))
        log "節點連接不足 ($peer_absent_cycles/$MAX_PEER_ABSENT_CYCLES)"

        if [ $peer_absent_cycles -ge $MAX_PEER_ABSENT_CYCLES ]; then
          log "節點持續離線，重啟..."
          start_exo
          peer_absent_cycles=0
          init_delay_done=0
          continue
        fi
      else
        peer_absent_cycles=0
      fi
    fi

    sleep $CHECK_INTERVAL
  done
}

main