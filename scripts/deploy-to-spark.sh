#!/bin/bash
# 部署監控腳本到 sparka/sparkb

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MONITOR_SCRIPT="$SCRIPT_DIR/monitor-exo.sh"

deploy_to_node() {
  local node=$1
  echo "正在部署到 $node..."
  
  # 創建遠程目錄
  ssh admin@$node "mkdir -p /home/admin/exo/scripts"
  
  # 複製腳本
  scp "$MONITOR_SCRIPT" admin@$node:/home/admin/exo/scripts/monitor-exo.sh
  ssh admin@$node "chmod +x /home/admin/exo/scripts/monitor-exo.sh"
  
  # 創建 systemd 服務或啟動腳本
  ssh admin@$node "cat > /home/admin/start-monitor.sh << 'INNEREOF'
#!/bin/bash
cd /home/admin/exo/scripts
nohup bash monitor-exo.sh > /tmp/monitor-stdout.log 2>&1 &
echo \"監控進程 PID: \$!\"
INNEREOF
  "
  ssh admin@$node "chmod +x /home/admin/start-monitor.sh"
  
  # 啟動監控
  ssh admin@$node "bash /home/admin/start-monitor.sh"
  
  echo "✓ 部署到 $node 完成"
}

# 部署到兩個節點
deploy_to_node "sparka"
deploy_to_node "sparkb"

echo "✓ 所有節點部署完成"
