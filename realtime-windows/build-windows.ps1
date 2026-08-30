$ErrorActionPreference = "Stop"

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$project = Join-Path $PSScriptRoot "PAPAluLive.Windows/PAPAluLive.Windows.csproj"
$coreTests = Join-Path $PSScriptRoot "PAPAluLive.Core.Tests/PAPAluLive.Core.Tests.csproj"
$smokeTests = Join-Path $PSScriptRoot "PAPAluLive.Windows.SmokeTests/PAPAluLive.Windows.SmokeTests.csproj"
$artifactRoot = Join-Path $PSScriptRoot "artifacts"
$publishDirectory = Join-Path $artifactRoot "publish/win-x64"
$outputDirectory = Join-Path $repositoryRoot "outputs/windows"
$zipPath = Join-Path $outputDirectory "悬浮说话角色-win-x64.zip"

$dotnet = Get-Command dotnet -ErrorAction Stop
$sdkVersion = & $dotnet.Source --version
if ($sdkVersion -notmatch '^10\.') {
    throw ".NET 10 SDK is required. Current SDK: $sdkVersion"
}

& $dotnet.Source run --project $coreTests -c Release
if ($LASTEXITCODE -ne 0) { throw "Core tests failed" }

& $dotnet.Source run --project $smokeTests -c Release
if ($LASTEXITCODE -ne 0) { throw "Windows smoke tests failed" }

if (Test-Path -LiteralPath $publishDirectory) {
    Remove-Item -LiteralPath $publishDirectory -Recurse -Force
}
New-Item -ItemType Directory -Path $publishDirectory -Force | Out-Null

& $dotnet.Source publish $project `
    -c Release `
    -r win-x64 `
    --self-contained true `
    -o $publishDirectory `
    -p:PublishSingleFile=true `
    -p:EnableCompressionInSingleFile=true `
    -p:IncludeNativeLibrariesForSelfExtract=true `
    -p:PublishTrimmed=false `
    -p:DebugType=None `
    -p:DebugSymbols=false
if ($LASTEXITCODE -ne 0) { throw "Windows publish failed" }

Copy-Item -LiteralPath (Join-Path $PSScriptRoot "README.md") `
    -Destination (Join-Path $publishDirectory "README-Windows.md") `
    -Force

& (Join-Path $PSScriptRoot "verify-windows-package.ps1") `
    -PublishDirectory $publishDirectory

New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
if (Test-Path -LiteralPath $zipPath) {
    Remove-Item -LiteralPath $zipPath -Force
}
Compress-Archive -Path (Join-Path $publishDirectory "*") `
    -DestinationPath $zipPath `
    -CompressionLevel Optimal

$zip = Get-Item -LiteralPath $zipPath
Write-Host "Windows acceptance package: $($zip.FullName)"
Write-Host "Archive size: $($zip.Length) bytes"
