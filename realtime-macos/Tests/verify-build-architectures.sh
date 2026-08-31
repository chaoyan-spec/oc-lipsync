#!/bin/bash

set -euo pipefail

REALTIME_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_SCRIPT="$REALTIME_DIR/build-app.sh"

for expected in \
  'arm64-apple-macosx13.0' \
  'x86_64-apple-macosx13.0' \
  'Apple-Silicon' \
  'Intel'; do
  if ! grep -Fq "$expected" "$BUILD_SCRIPT"; then
    echo "Missing macOS architecture build contract: $expected" >&2
    exit 1
  fi
done

if "$BUILD_SCRIPT" unsupported-architecture >/dev/null 2>&1; then
  echo "Unsupported macOS architecture must be rejected" >&2
  exit 1
fi

echo "macOS architecture build contract passed"
