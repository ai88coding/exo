#!/bin/bash
# EXO 集群一鍵啟動 v3 - 用 launchd 管理 Mac exo，monitor 管理 workers
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "=== 啟動 EXO 集群 ==="

# 0. 先殺 sparka/sparkb 的 exo 和 monitor
echo "0/3 預先關閉 sparka/sparkb..."
for node in sparka sparkb; do
  ssh admin@$node "
    pkill -f 'monitor-exo\.sh' 2>/dev/null
    pkill -f '\.venv/bin/exo' 2>/dev/null
    pkill -f multiprocessing 2>/dev/null
    sleep 1
    rm -f /tmp/exo_*.bin
  " || true
done

# 1. Mac exo 由 launchd 管理 — 確認正在運行
echo "1/3 確認 Mac exo（launchd 管理）..."
if curl -s http://localhost:52415/state > /dev/null 2>&1; then
  echo "  Mac exo 已運行"
else
  echo "  Mac exo 未運行，請重開機或手動啟動 launchd"
fi

# 2. 再等 15 秒讓 Mac 穩定
echo "2/3 等待 Mac 穩定 (15s)..."
sleep 15

# 3. 遠程啟動 sparka/sparkb（用 systemd 管理 monitor）
echo "3/3 遠程啟動 sparka/sparkb..."
for node in sparka sparkb; do
  echo "  → $node..."
  ssh admin@$node "systemctl --user restart exo-monitor 2>&1 || echo FAILED" &
done
wait

echo "=== 集群啟動完成 ==="
sleep 30
bash "$SCRIPT_DIR/check-cluster.sh"

# 等 Mac exo 準備好
echo "  等待 Mac exo 就緒..."
for i in $(seq 1 30); do
  if curl -s http://localhost:52415/state > /dev/null 2>&1; then
    echo "  Mac exo 就緒 (${i}s)"
    break
  fi
  sleep 1
done

# 2. 啟動 Mac 監控
echo "2/4 啟動 Mac 監控..."
pkill -f "monitor-exo\.sh" 2>/dev/null || true
sleep 1
nohup bash "$SCRIPT_DIR/monitor-exo.sh" > /tmp/monitor-mac.log 2>&1 &
echo "  PID: $!"

# 3. 再等 15 秒讓 Mac 穩定
echo "3/4 等待 Mac 穩定 (15s)..."
sleep 15

# 4. 遠程啟動 sparka/sparkb（用 monitor-exo.sh 確保進程存活）
echo "4/4 遠程啟動 sparka/sparkb..."
for node in sparka sparkb; do
  echo "  → $node..."
  ssh admin@$node "
    pkill -f '\.venv/bin/exo' 2>/dev/null || true
    sleep 2
    bash /home/admin/exo/scripts/monitor-exo.sh > /tmp/monitor.log 2>&1 &
    disown
  " &
done
wait

echo "=== 集群啟動完成 ==="
echo "查看狀態：bash $SCRIPT_DIR/check-cluster.sh"

# 等 30 秒後檢查狀態
sleep 30
bash "$SCRIPT_DIR/check-cluster.sh"
