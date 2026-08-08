#!/bin/zsh

set -u

SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"
cd -- "$SCRIPT_DIR" || exit 1

PORT_NUMBER="${PORT:-4173}"
LOCAL_URL="http://127.0.0.1:${PORT_NUMBER}"
OPENER_PID=""

cleanup() {
  if [[ -n "$OPENER_PID" ]]; then
    kill "$OPENER_PID" 2>/dev/null || true
  fi
}

trap cleanup EXIT INT TERM

echo "OC 口播机正在启动……"
echo "如果浏览器没有自动打开，请访问：$LOCAL_URL"
echo "使用结束后，在本窗口按 Control-C 停止。"

(
  for _attempt in {1..100}; do
    if /usr/bin/curl --fail --silent --output /dev/null "$LOCAL_URL"; then
      /usr/bin/open "$LOCAL_URL"
      exit 0
    fi
    sleep 0.1
  done
) &
OPENER_PID=$!

npm start
