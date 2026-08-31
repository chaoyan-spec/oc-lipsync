#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
XAML="$ROOT/realtime-windows/PAPAluLive.Windows/MainWindow.xaml"
PROJECT="$ROOT/realtime-windows/PAPAluLive.Windows/PAPAluLive.Windows.csproj"
MENU="$ROOT/realtime-windows/PAPAluLive.Windows/Presentation/CharacterMenuBuilder.cs"
MAIN_WINDOW="$ROOT/realtime-windows/PAPAluLive.Windows/MainWindow.xaml.cs"

grep -q 'AllowsTransparency="True"' "$XAML"
grep -q 'WindowStyle="None"' "$XAML"
grep -q 'Background="Transparent"' "$XAML"
grep -q 'Topmost="True"' "$XAML"
grep -q '<TargetFramework>net10.0-windows10.0.19041.0</TargetFramework>' "$PROJECT"
grep -q '<EnableWindowsTargeting>true</EnableWindowsTargeting>' "$PROJECT"
grep -q '<PublishTrimmed>false</PublishTrimmed>' "$PROJECT"
grep -q 'Header = CreateCharacterHeader' "$MENU"
grep -q 'private static FrameworkElement CreateCharacterHeader' "$MENU"
grep -q 'Width = ThumbnailSize' "$MENU"
grep -q 'Height = ThumbnailSize' "$MENU"
grep -q 'Stretch = Stretch.Uniform' "$MENU"
if grep -q 'Icon = thumbnail' "$MENU"; then
    echo "Character thumbnails must not use the clipped WPF icon slot" >&2
    exit 1
fi
grep -q '"删除自定义角色…"' "$MENU"
grep -q 'deleteCustomItem.IsEnabled = available' "$MENU"
grep -q 'DeleteCustomCharacter' "$MAIN_WINDOW"
grep -q 'customCharacterStore.Delete()' "$MAIN_WINDOW"

echo "WPF shell contract passed"
