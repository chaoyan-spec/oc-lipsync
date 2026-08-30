#!/bin/bash

set -euo pipefail

REALTIME_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REPO_ROOT="$(cd "$REALTIME_DIR/.." && pwd)"

verify_two_frame_character() {
  local directory="$1"
  local label="$2"
  local expected_dimensions=""

  for asset in idle talking; do
    local file="$REALTIME_DIR/Resources/Characters/$directory/$asset.png"
    if [[ ! -f "$file" ]]; then
      echo "Missing $label asset: $file" >&2
      exit 1
    fi
    if [[ "$(sips -g hasAlpha "$file" | awk '/hasAlpha/ {print $2}')" != "yes" ]]; then
      echo "$label asset must have alpha: $file" >&2
      exit 1
    fi

    local width
    local height
    width="$(sips -g pixelWidth "$file" | awk '/pixelWidth/ {print $2}')"
    height="$(sips -g pixelHeight "$file" | awk '/pixelHeight/ {print $2}')"
    if [[ -z "$width" || -z "$height" || "$width" -le 1 || "$height" -le 1 ]]; then
      echo "$label asset has invalid dimensions: $file" >&2
      exit 1
    fi

    local dimensions="${width}x${height}"
    if [[ -n "$expected_dimensions" && "$dimensions" != "$expected_dimensions" ]]; then
      echo "$label mouth canvases do not match: $directory" >&2
      exit 1
    fi
    expected_dimensions="$dimensions"
  done

  if cmp -s \
    "$REALTIME_DIR/Resources/Characters/$directory/idle.png" \
    "$REALTIME_DIR/Resources/Characters/$directory/talking.png"; then
    echo "$label mouth states must be visibly different: $directory" >&2
    exit 1
  fi
}

verify_two_frame_character "CatMeme" "Built-in cat"
verify_two_frame_character "HuhCat" "Huh cat"
verify_two_frame_character "HappyCat" "Happy cat"
verify_two_frame_character "ScreamingCat" "Screaming cat"

for frame in 0 1 2 3 4 5 6 7; do
  file="$REPO_ROOT/public/papalu-talking/frames/$frame.png"
  if [[ ! -f "$file" ]]; then
    echo "Missing authoritative PAPAlu frame: $file" >&2
    exit 1
  fi
done

echo "Built-in character resource contract passed"
