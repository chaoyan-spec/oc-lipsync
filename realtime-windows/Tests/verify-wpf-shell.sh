#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
XAML="$ROOT/realtime-windows/PAPAluLive.Windows/MainWindow.xaml"
PROJECT="$ROOT/realtime-windows/PAPAluLive.Windows/PAPAluLive.Windows.csproj"

grep -q 'AllowsTransparency="True"' "$XAML"
grep -q 'WindowStyle="None"' "$XAML"
grep -q 'Background="Transparent"' "$XAML"
grep -q 'Topmost="True"' "$XAML"
grep -q '<TargetFramework>net10.0-windows10.0.19041.0</TargetFramework>' "$PROJECT"
grep -q '<EnableWindowsTargeting>true</EnableWindowsTargeting>' "$PROJECT"
grep -q '<PublishTrimmed>false</PublishTrimmed>' "$PROJECT"

echo "WPF shell contract passed"
