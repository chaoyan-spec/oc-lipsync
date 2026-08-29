#!/bin/bash

set -euo pipefail

REALTIME_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REPO_ROOT="$(cd "$REALTIME_DIR/.." && pwd)"

for asset in idle talking; do
  file="$REALTIME_DIR/Resources/Characters/CatMeme/$asset.png"
  if [[ ! -f "$file" ]]; then
    echo "Missing built-in cat asset: $file" >&2
    exit 1
  fi
  if [[ "$(sips -g hasAlpha "$file" | awk '/hasAlpha/ {print $2}')" != "yes" ]]; then
    echo "Built-in cat asset must have alpha: $file" >&2
    exit 1
  fi
done

for frame in 0 1 2 3 4 5 6 7; do
  file="$REPO_ROOT/public/papalu-talking/frames/$frame.png"
  if [[ ! -f "$file" ]]; then
    echo "Missing authoritative PAPAlu frame: $file" >&2
    exit 1
  fi
done

echo "Built-in character resource contract passed"
