#!/bin/bash
# EXO 集群一鍵啟動 v2 - Mac 先起來，sparka/sparkb 等 Mac 站穩再連
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "=== 啟動 EXO 集群 ==="

# 0. 先殺 sparka/sparkb 的 exo，避免它們先跑起來
echo "0/4 預先關閉 sparka/sparkb exo..."
for node in sparka sparkb; do
  ssh admin@$node "pkill -f '\.venv/bin/exo' 2>/dev/null; pkill -f 'uv run exo' 2>/dev/null; sleep 1" || true
done

# 1. 啟動 Mac exo
echo "1/4 啟動 Mac exo..."
cd /Users/wilson/exo
pkill -f "uv run exo" 2>/dev/null || true
sleep 2
nohup uv run exo > /tmp/exo.log 2>&1 &
MAC_PID=$!
echo "  PID: $MAC_PID"

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

# 4. 遠程啟動 sparka/sparkb（先殺乾淨再啟動）
echo "4/4 遠程啟動 sparka/sparkb..."
for node in sparka sparkb; do
  echo "  → $node..."
  ssh admin@$node "
    pkill -f '\.venv/bin/exo' 2>/dev/null || true
    pkill -f 'uv run exo' 2>/dev/null || true
    pkill -f 'monitor-exo\.sh' 2>/dev/null || true
    sleep 2
    nohup bash /home/admin/exo/scripts/monitor-exo.sh > /tmp/monitor.log 2>&1 &
  " &
done
wait

echo "=== 集群啟動完成 ==="
echo "查看狀態：bash $SCRIPT_DIR/check-cluster.sh"

# 等 30 秒後檢查狀態
sleep 30
bash "$SCRIPT_DIR/check-cluster.sh"
