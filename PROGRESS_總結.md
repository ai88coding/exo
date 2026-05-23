# EXO 三節點集群建置進度總結

## 📋 專案目標
建立並維護三節點分散式 EXO 集群（Mac + sparka + sparkb），配備 NVIDIA DGX Spark 主題儀表板。Mac 負責透過 LM Studio 管理所有模型，sparka/sparkb 為唯讀消費者，絕不從網際網路下載模型。

## 🏗️ 集群架構

### 節點配置
| 節點 | IP 位置 | 角色 | 後端 | 記憶體 |
|------|---------|------|------|--------|
| **Mac Studio M2 Ultra** | 192.168.8.250 | 主節點、模型管理、儀表板主機 | MLX Metal | 192GB |
| **sparka** (DGX Spark GB10) | 192.168.8.220 | 工作節點 | NVIDIA CUDA 13.0 | 128GB |
| **sparkb** (DGX Spark GB10) | 192.168.8.230 | 工作節點 | NVIDIA CUDA 13.0 | 128GB |

### 技術規格
- **MLX 版本**: 0.32.0 客製化分支 (rltakashige/mlx-jaccl-fix-small-recv)
- **Python**: 3.13.13 (透過 uv)
- **CUDA**: 13.0
- **命名空間**: `EXO_LIBP2P_NAMESPACE=wilson-cluster`
- **模型來源**: 僅 Mac 可從網際網路下載，sparka/sparkb 設定為 `EXO_MODEL_SOURCE=rsync-only`

## ✅ 已完成的修復

### 1. 下載協調器修復 (`coordinator.py`)
- **問題**: scp 拉取模型時只嘗試單一路徑
- **解決方案**: 修改 `_start_download` 方法，嘗試兩種可能的源路徑：
  - 有組織前綴：`mlx-community/model-name`
  - 無組織前綴：`model-name`
- **結果**: 成功從 Mac 傳輸模型到 sparka/sparkb

### 2. 下載狀態處理
- **問題**: `DownloadFailed` 狀態被錯誤覆蓋
- **解決方案**: 
  - 允許 `DownloadFailed` 重試（之前被跳過）
  - 防止 `_emit_existing_download_progress` 覆蓋 `DownloadFailed` 狀態
  - scp 失敗時正確發出 `DownloadFailed` 狀態

### 3. API 導入修復 (`main.py`)
- **問題**: 缺少 `resolve_existing_model` 導入導致 `NameError`
- **解決方案**: 添加導入語句 `from exo.download.download_utils import resolve_existing_model`
- **結果**: Models API 正常運作，返回 122 個模型

### 4. SSH 認證配置
- **問題**: sparka/sparkb 無法透過 SSH 連接 Mac
- **解決方案**: 
  - 在 sparka/sparkb 上生成 SSH 金鑰
  - 將公鑰添加到 Mac 的 `authorized_keys`
  - 測試雙向連接
- **結果**: scp 傳輸正常運作

### 5. 儀表板 UI 修復
- **問題**: 模型選擇列表和啟動按鈕消失
- **解決方案**: 
  - 重新構建儀表板
  - 修復 API 錯誤
  - 清除瀏覽器緩存
- **結果**: 儀表板正常顯示所有功能

### 6. 節點穩定性提升
- **問題**: sparkb 節點不穩定，經常離線
- **解決方案**: 
  - 在三個節點上創建監控腳本 (`monitor-exo.sh`)
  - 每 10 秒檢查進程狀態
  - 自動重崩潰的進程
- **結果**: 三節點穩定運行

## 🔧 已修改的檔案

### 核心代碼
1. `/Users/wilson/exo/src/exo/download/coordinator.py`
   - 修改 rsync-only 模式，嘗試兩個源路徑
   - 改進失敗處理和狀態管理

2. `/Users/wilson/exo/src/exo/api/main.py`
   - 添加缺少的 `resolve_existing_model` 導入
   - 修復語法錯誤

3. `/Users/wilson/exo/dashboard/`
   - 重新構建儀表板

### 監控腳本
1. **Mac**: `/tmp/monitor-exo-mac.sh`
2. **sparka**: `/home/admin/monitor-exo.sh`
3. **sparkb**: `/home/admin/monitor-exo.sh`

## 📊 當前集群狀態

### 拓撲節點
```\
拓撲中的節點數：3
1. sparka  - 12D3KooWFhKjKXsW...
2. macos   - 12D3KooWDhLAn3gE...
3. sparkb  - 12D3KooWF4D2hk6r...
```

### 下載統計
| 節點 | 等待中 | 已完成 | 失敗 |
|------|--------|--------|------|
| sparka | 116 | 4 | 2 |
| macos | 119 | 3 | 0 |
| sparkb | 119 | 2 | 1 |

### 測試結果
- ✅ 模型下載功能正常（測試模型：`mlx-community/gemma-4-31b-it-4bit`）
- ✅ 失敗處理正常（測試模型：`mlx-community/gemma-4-e4b-it-6bit` 正確顯示失敗）
- ✅ scp 傳輸正常（速度約 325 MB/s）
- ✅ 儀表板所有功能正常

## 🚀 啟動指令

### Mac (主節點)
```bash
cd /Users/wilson/exo
EXO_LIBP2P_NAMESPACE=wilson-cluster \
EXO_MODELS_DIRS=/Users/wilson/.lmstudio/models/ \
EXO_RSYNC_TARGETS=admin@sparka:/home/admin/.lmstudio/models/,admin@sparkb:/home/admin/.lmstudio/models/ \
nohup uv run exo > /tmp/exo_mac.log 2>&1 &
```

### sparka/sparkb (工作節點)
```bash
cd /home/admin/exo
EXO_MODEL_SOURCE=rsync-only \
EXO_RSYNC_MODEL_SOURCE=wilson@192.168.8.250:/Users/wilson/.lmstudio/models/ \
EXO_LIBP2P_NAMESPACE=wilson-cluster \
nohup uv run exo > /tmp/exo.log 2>&1 &
```

## 📁 重要路徑

### Mac
- LMStudio 模型：`/Users/wilson/.lmstudio/models/`
- exo 日誌：`/tmp/exo_mac.log`
- 監控日誌：`/tmp/monitor.log`

### sparka/sparkb
- 唯讀模型：`/home/admin/.lmstudio/models/` (指向 Mac)
- 實際模型：`/home/admin/.local/share/exo/models/`
- exo 日誌：`/tmp/exo.log`
- 監控日誌：`/tmp/monitor.log`

## 🌐 儀表板

- **URL**: http://192.168.8.250:52415
- **功能**: 
  - 模型管理與下載
  - 節點監控
  - 推理任務管理
  - 實時狀態更新

## 🔍 已知問題

1. **模型路徑命名**: 部分模型在 Mac 上沒有組織前綴，需要嘗試兩種路徑
2. **下載失敗處理**: 模型不存在時會正確顯示失敗，需要手動重試或移除

## 📝 下一步計劃

1. 測試多節點推論功能（例如：Qwen3.6-35B-A3B-4bit）
2. 優化 scp 傳輸效率
3. 增加更多監控指標
4. 建立自動備份機制

## 👥 貢獻者

- 系統架構與實作
- 問題排查與修復
- 監控腳本開發

## 📅 更新日期

2026 年 5 月 23 日

---

**狀態**: ✅ 集群穩定運行中
**版本**: v1.0 - 三節點集群建置完成
