param(
    [string]$FfmpegPath,
    [string]$FfprobePath,
    [string]$TestDir
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-Executable {
    param([string]$ExplicitPath, [string]$CommandName)
    if (-not [string]::IsNullOrWhiteSpace($ExplicitPath)) {
        $resolved = Resolve-Path -LiteralPath $ExplicitPath -ErrorAction SilentlyContinue
        if ($resolved) {
            return $resolved.Path
        }
        return $null
    }
    $cmd = Get-Command $CommandName -ErrorAction SilentlyContinue
    if ($cmd) {
        return $cmd.Source
    }
    return $null
}

function Add-Check {
    param(
        [System.Collections.Generic.List[object]]$Checks,
        [string]$Name,
        [bool]$Passed,
        [string]$Detail,
        [string]$Fix = ''
    )
    $Checks.Add([ordered]@{
        name = $Name
        passed = $Passed
        detail = $Detail
        fix = $Fix
    }) | Out-Null
}

$checks = [System.Collections.Generic.List[object]]::new()

$psVersion = $PSVersionTable.PSVersion.ToString()
Add-Check -Checks $checks `
    -Name 'PowerShell version' `
    -Passed ($PSVersionTable.PSVersion.Major -ge 5) `
    -Detail "Detected PowerShell $psVersion. PowerShell 7+ is recommended, 5.1+ should work." `
    -Fix 'Install PowerShell 7 from https://github.com/PowerShell/PowerShell if you hit compatibility issues.'

$ffmpeg = Resolve-Executable -ExplicitPath $FfmpegPath -CommandName 'ffmpeg'
Add-Check -Checks $checks `
    -Name 'ffmpeg available' `
    -Passed (-not [string]::IsNullOrWhiteSpace($ffmpeg)) `
    -Detail ($(if ($ffmpeg) { "Found: $ffmpeg" } else { 'ffmpeg was not found.' })) `
    -Fix 'Install FFmpeg or pass -FfmpegPath. Windows: winget install Gyan.FFmpeg. macOS: brew install ffmpeg. Linux: use your package manager.'

$ffprobe = Resolve-Executable -ExplicitPath $FfprobePath -CommandName 'ffprobe'
Add-Check -Checks $checks `
    -Name 'ffprobe available' `
    -Passed (-not [string]::IsNullOrWhiteSpace($ffprobe)) `
    -Detail ($(if ($ffprobe) { "Found: $ffprobe" } else { 'ffprobe was not found.' })) `
    -Fix 'ffprobe ships with FFmpeg. Install FFmpeg or pass -FfprobePath.'

if ([string]::IsNullOrWhiteSpace($TestDir)) {
    $TestDir = Join-Path (Get-Location).Path '.tmp\environment-check'
}

try {
    New-Item -ItemType Directory -Path $TestDir -Force | Out-Null
    $testFile = Join-Path $TestDir 'utf8 path test-中文.txt'
    'utf8-ok' | Set-Content -LiteralPath $testFile -Encoding UTF8
    $readBack = Get-Content -LiteralPath $testFile -Raw
    Add-Check -Checks $checks `
        -Name 'filesystem write/read' `
        -Passed ($readBack -match 'utf8-ok') `
        -Detail "Created and read a UTF-8 test file at: $testFile" `
        -Fix 'Choose a writable BaseDir or run the shell with access to the target directory.'
} catch {
    Add-Check -Checks $checks `
        -Name 'filesystem write/read' `
        -Passed $false `
        -Detail $_.Exception.Message `
        -Fix 'Choose a writable BaseDir or run the shell with access to the target directory.'
}

try {
    if (Test-Path -LiteralPath $TestDir) {
        Remove-Item -LiteralPath $TestDir -Recurse -Force
    }
} catch {
    # Non-fatal cleanup failure.
}

$failed = @($checks | Where-Object { -not $_.passed })

"# Environment Check"
""
foreach ($check in $checks) {
    $status = if ($check.passed) { 'OK' } else { 'FAIL' }
    "[$status] $($check.name): $($check.detail)"
    if (-not $check.passed -and -not [string]::IsNullOrWhiteSpace($check.fix)) {
        "  Fix: $($check.fix)"
    }
}
""
if ($failed.Count -eq 0) {
    'All required checks passed.'
    exit 0
}

"$($failed.Count) check(s) failed."
exit 1

