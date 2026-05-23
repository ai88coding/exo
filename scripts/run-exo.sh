#!/bin/bash
# launchd wrapper — 只啟動 Mac exo（workers 由 Restart 按鈕處理）
set -e

EXO_DIR="/Users/wilson/exo"
exec "$EXO_DIR/.venv/bin/exo"