# EXO 集群監控與管理系統

## 📁 目錄結構

```
/Users/wilson/exo/scripts/
├── monitor-exo.sh        # 主監控腳本（自動部署到所有節點）
├── deploy-to-spark.sh    # 部署腳本
├── check-cluster.sh      # 狀態檢查工具
└── README.md             # 本文檔
```

## 🚀 功能特點

### 1. 智能監控
- ✅ 進程存活檢測
- ✅ API 健康檢查
- ✅ 環境變量驗證
- ✅ 資源使用監控（內存、CPU）
- ✅ 自動重啟機制（最多重試 3 次）

### 2. 角色識別
- **Mac 角色**: 主節點，負責模型管理和 API 服務
- **Worker 角色**: sparka/sparkb，rsync-only 模式

### 3. 自動修復
- 進程崩潰自動重啟
- 環境變量自動設置
- 健康檢查失敗自動恢復

## 📋 使用說明

### 啟動監控
```bash
# Mac
bash /Users/wilson/exo/scripts/monitor-exo.sh

# sparka/sparkb (已自動部署)
bash /home/admin/exo/scripts/monitor-exo.sh
```

### 檢查集群狀態
```bash
bash /Users/wilson/exo/scripts/check-cluster.sh
```

### 重新部署
```bash
bash /Users/wilson/exo/scripts/deploy-to-spark.sh
```

## 🔍 日誌位置

| 節點 | 監控日誌 | EXO 日誌 |
|------|----------|---------|
| Mac | `/tmp/monitor.log` | `/tmp/exo_mac.log` |
| sparka | `/tmp/monitor.log` | `/tmp/exo.log` |
| sparkb | `/tmp/monitor.log` | `/tmp/exo.log` |

## 🛠️ 故障排除

### 1. 檢查進程狀態
```bash
# Mac
ps aux | grep exo

# sparka/sparkb
ssh admin@sparka "ps aux | grep exo"
ssh admin@sparkb "ps aux | grep exo"
```

### 2. 查看監控日誌
```bash
tail -50 /tmp/monitor.log
```

### 3. 查看 EXO 日誌
```bash
# Mac
tail -50 /tmp/exo_mac.log

# sparka/sparkb
ssh admin@sparka "tail -50 /tmp/exo.log"
ssh admin@sparkb "tail -50 /tmp/exo.log"
```

### 4. 手動重啟
```bash
# 停止監控
pkill -f monitor-exo

# 停止 EXO
pkill -f exo

# 重新啟動監控（會自動啟動 EXO）
bash /Users/wilson/exo/scripts/monitor-exo.sh
```

## 📊 監控指標

### 健康檢查
- HTTP 200: API 正常
- HTTP 503: 服務不可用
- 無響應: 進程可能已崩潰

### 資源閾值
- 內存警告：< 5GB 可用
- CPU 警告：負載 > 4.0

### 重試機制
- 最大重試次數：3 次
- 重試間隔：10 秒
- 檢查間隔：10 秒

## 🔧 配置選項

可在腳本開頭修改以下配置：

```bash
MAX_RETRIES=3              # 最大重試次數
RETRY_DELAY=10             # 重試間隔（秒）
CHECK_INTERVAL=10          # 檢查間隔（秒）
RESOURCE_CHECK_INTERVAL=6  # 資源檢查間隔（次）
HEALTH_CHECK_PORT="52415"  # API 端口
```

## 📝 版本歷史

- **v2.0**: 完整監控系統，包含環境檢查、資源監控、健康檢查
- **v1.0**: 基礎進程監控

## 👥 維護

- 作者：EXO 集群管理組
- 更新日期：2026-05-23
- 狀態：✅ 運行中
