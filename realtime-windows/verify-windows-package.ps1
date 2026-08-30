param(
    [Parameter(Mandatory = $true)]
    [string]$PublishDirectory
)

$ErrorActionPreference = "Stop"
$resolvedDirectory = Resolve-Path -LiteralPath $PublishDirectory
$executable = Join-Path $resolvedDirectory "PAPAluLive.Windows.exe"

if (-not (Test-Path -LiteralPath $executable -PathType Leaf)) {
    throw "Missing PAPAluLive.Windows.exe"
}

if ((Get-Item -LiteralPath $executable).Length -le 0) {
    throw "PAPAluLive.Windows.exe is empty"
}

$forbidden = Get-ChildItem -LiteralPath $resolvedDirectory -Recurse -File |
    Where-Object { $_.Extension.ToLowerInvariant() -in ".wav", ".m4a", ".mp3" }
if ($forbidden) {
    throw "Audio recordings must not be included in the Windows package"
}

$cameraFiles = Get-ChildItem -LiteralPath $resolvedDirectory -Recurse -File |
    Where-Object { $_.Name -match "camera|webcam|capture-video" }
if ($cameraFiles) {
    throw "Camera assets must not be included in the Windows package"
}

Write-Host "Windows package contract passed"
