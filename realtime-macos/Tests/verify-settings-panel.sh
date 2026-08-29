#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE="$SCRIPT_DIR/../Sources/PAPAluLive/CharacterSettingsController.swift"

if ! rg -Fq 'beginSheetModal(for:' "$SOURCE"; then
  echo "PNG picker must remain attached to the settings panel" >&2
  exit 1
fi

echo "Custom character settings-panel contract passed"
