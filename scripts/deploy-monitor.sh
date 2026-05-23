#!/bin/bash
# 部署 EXO 守護進程 v3.1 - 清理舊進程 + 快速恢復
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MONITOR="$SCRIPT_DIR/monitor-exo.sh"

deploy() {
  local node=$1
  echo "=== 部署到 $node ==="
  
  ssh admin@$node "mkdir -p /home/admin/exo/scripts"
  scp "$MONITOR" admin@$node:/home/admin/exo/scripts/monitor-exo.sh
  ssh admin@$node "chmod +x /home/admin/exo/scripts/monitor-exo.sh"
  
  # 停止所有 monitor 進程（新舊全部殺掉）
  echo "  停止所有 monitor..."
  ssh admin@$node "pkill -f 'monitor-exo\.sh' 2>/dev/null; pkill -f 'start-monitor' 2>/dev/null; sleep 1"
  
  # 刪除舊腳本
  echo "  刪除舊腳本..."
  ssh admin@$node "rm -f /home/admin/monitor-exo.sh /home/admin/monitor-exo-v2.sh /home/admin/start-monitor.sh" 2>/dev/null || true
  
  # 啟動新監控
  echo "  啟動 v3.1 監控..."
  ssh admin@$node "nohup bash /home/admin/exo/scripts/monitor-exo.sh > /tmp/monitor.log 2>&1 &"
  echo "  ✓ $node 完成"
}

echo "=== 部署 EXO 守護進程 v3.1 ==="
deploy "sparka"
sleep 2
deploy "sparkb"
sleep 2
echo ""

# 確認
echo "=== 部署狀態 ==="
for node in sparka sparkb; do
  echo -n "$node: "
  ssh admin@$node "ps aux | grep 'monitor-exo' | grep -v grep | wc -l" 2>&1 | tr -d ' '
  echo " 個監控進程"
done

echo ""
echo "=== 等待 60 秒後檢查集群狀態 ==="
sleep 60
echo "集群狀態:"
bash "$SCRIPT_DIR/check-cluster.sh"
