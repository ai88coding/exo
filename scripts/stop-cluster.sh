#!/bin/bash
# EXO 三節點一鍵關機 v1
set -e

echo "=== 三節點 EXO 關機 ==="

# 同時關閉 sparka/sparkb
echo "關閉 sparka/sparkb..."
for node in sparka sparkb; do
  ssh admin@$node "
    pkill -f '\.venv/bin/exo' 2>/dev/null
    pkill -f multiprocessing 2>/dev/null
    pkill -f 'monitor-exo\.sh' 2>/dev/null
    rm -f /tmp/exo_*.bin
  " || true
done

# 關閉 Mac exo
echo "關閉 Mac exo..."
pkill -f "\.venv/bin/exo" 2>/dev/null || true
pkill -f multiprocessing 2>/dev/null || true

echo "=== 三節點已全部關閉 ==="