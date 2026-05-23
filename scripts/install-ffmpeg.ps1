param(
    [switch]$PrintOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ((Get-Command ffmpeg -ErrorAction SilentlyContinue) -and (Get-Command ffprobe -ErrorAction SilentlyContinue)) {
    "FFmpeg and FFprobe are already available on PATH."
    exit 0
}

$platform = if ($PSVersionTable.ContainsKey('Platform')) { [string]$PSVersionTable.Platform } else { '' }
$runningOnWindows = $platform -eq 'Win32NT' -or ($env:OS -like '*Windows*')
$runningOnMac = $false
if (-not $runningOnWindows) {
    try {
        $runningOnMac = ((& uname 2>$null) -eq 'Darwin')
    } catch {
        $runningOnMac = $false
    }
}

if ($runningOnWindows) {
    $cmd = 'winget install --id Gyan.FFmpeg -e'
    if ($PrintOnly) {
        $cmd
        exit 0
    }
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        throw "winget was not found. Install FFmpeg manually from https://ffmpeg.org/download.html, then rerun scripts/check-environment.ps1."
    }
    winget install --id Gyan.FFmpeg -e
    "If ffmpeg is still not found, close and reopen your terminal, then run scripts/check-environment.ps1."
    exit $LASTEXITCODE
}

if ($runningOnMac) {
    $cmd = 'brew install ffmpeg'
    if ($PrintOnly) {
        $cmd
        exit 0
    }
    if (-not (Get-Command brew -ErrorAction SilentlyContinue)) {
        throw 'Homebrew was not found. Install Homebrew or install FFmpeg manually.'
    }
    brew install ffmpeg
    exit $LASTEXITCODE
}

$commands = @(
    'sudo apt install ffmpeg',
    'sudo dnf install ffmpeg',
    'sudo pacman -S ffmpeg'
)

"Automatic Linux installation is distro-specific. Use one of these commands:"
$commands
exit 1
