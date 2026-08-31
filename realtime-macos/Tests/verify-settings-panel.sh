#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE="$SCRIPT_DIR/../Sources/PAPAluLive/CharacterSettingsController.swift"
APP_DELEGATE="$SCRIPT_DIR/../Sources/PAPAluLive/AppDelegate.swift"

if ! rg -Fq 'beginSheetModal(for:' "$SOURCE"; then
  echo "PNG picker must remain attached to the settings panel" >&2
  exit 1
fi

if ! rg -Fq 'withTitle: "删除自定义角色…"' "$APP_DELEGATE"; then
  echo "Context menu must expose custom character deletion" >&2
  exit 1
fi

if ! rg -Fq '#selector(deleteCustomCharacter)' "$APP_DELEGATE"; then
  echo "Delete menu item must call the custom character deletion action" >&2
  exit 1
fi

if ! rg -Fq 'deleteItem.isEnabled = catalog[.custom] != nil' "$APP_DELEGATE"; then
  echo "Delete menu item must be disabled when no custom character exists" >&2
  exit 1
fi

echo "Custom character settings-panel contract passed"
