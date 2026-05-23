#!/bin/bash
# EXO 三節點一鍵重啟 v2 - 用 launchd 管理 Mac exo，monitor 管理 workers
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== 三節點 EXO 重啟 ==="

# 0. 關閉 workers
echo "0/3 關閉 sparka/sparkb..."
for node in sparka sparkb; do
  ssh admin@$node "
    pkill -f 'monitor-exo\.sh' 2>/dev/null
    pkill -f '\.venv/bin/exo' 2>/dev/null
    pkill -f multiprocessing 2>/dev/null
    rm -f /tmp/exo_*.bin
  " || true
done

# 1. 讓 launchd 重啟 Mac exo（pkill 後 launchd KeepAlive 會自動拉起）
echo "1/3 重啟 Mac exo（via launchd）..."
pkill -f "\.venv/bin/exo" 2>/dev/null || true
sleep 5

echo "  等待 Mac exo 就緒..."
for i in $(seq 1 45); do
  if curl -s http://localhost:52415/state > /dev/null 2>&1; then
    echo "  Mac 就緒 (${i}s)"
    break
  fi
  sleep 1
done

# 2. 等待 libp2p 穩定
echo "2/3 等待 Mac 穩定 (15s)..."
sleep 15

# 3. 用 systemd 重啟 workers 的 monitor-exo.sh
echo "3/3 重啟 sparka/sparkb..."
for node in sparka sparkb; do
  echo "  → $node..."
  ssh admin@$node "systemctl --user restart exo-monitor 2>&1 || echo FAILED" &
done
wait

echo "=== 重啟完成 ==="
sleep 30
"$SCRIPT_DIR/check-cluster.sh"