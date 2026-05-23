#!/bin/bash
# EXO 集群狀態檢查工具

echo "=== EXO 集群狀態檢查 ==="
echo ""

# 檢查 Mac
echo "🖥️  Mac (本地):"
if pgrep -f "exo" > /dev/null; then
  echo "   ✓ 進程運行中"
  if curl -s http://localhost:52415/state > /dev/null 2>&1; then
    echo "   ✓ API 正常響應"
    curl -s http://localhost:52415/state | python3 -c "
import sys, json
d = json.load(sys.stdin)
topo = d.get('topology', {})
print(f\"   拓撲節點：{len(topo.get('nodes', []))}\")
downloads = d.get('downloads', {})
total_pending = sum(1 for nid, entries in downloads.items() for e in entries if list(e.keys())[0] == 'DownloadPending')
total_completed = sum(1 for nid, entries in downloads.items() for e in entries if list(e.keys())[0] == 'DownloadCompleted')
print(f\"   下載：等待中={total_pending}, 已完成={total_completed}\")
" 2>/dev/null
  else
    echo "   ✗ API 無響應"
  fi
else
  echo "   ✗ 進程未運行"
fi
echo ""

# 檢查 sparka
echo "🔵 sparka (192.168.8.220):"
ssh admin@sparka "
if pgrep -f 'exo' > /dev/null; then
  echo '   ✓ 進程運行中'
  if curl -s http://localhost:52415/state > /dev/null 2>&1; then
    echo '   ✓ API 正常響應'
  else
    echo '   ✗ API 無響應'
  fi
else
  echo '   ✗ 進程未運行'
fi
echo '   最後日誌:'
tail -3 /tmp/monitor.log 2>/dev/null | sed 's/^/     /'
" 2>&1 | sed 's/^/   /'
echo ""

# 檢查 sparkb
echo "🔵 sparkb (192.168.8.230):"
ssh admin@sparkb "
if pgrep -f 'exo' > /dev/null; then
  echo '   ✓ 進程運行中'
  if curl -s http://localhost:52415/state > /dev/null 2>&1; then
    echo '   ✓ API 正常響應'
  else
    echo '   ✗ API 無響應'
  fi
else
  echo '   ✗ 進程未運行'
fi
echo '   最後日誌:'
tail -3 /tmp/monitor.log 2>/dev/null | sed 's/^/     /'
" 2>&1 | sed 's/^/   /'
echo ""

echo "=== 檢查完成 ==="
