param(
    [string]$CodexSkillsDir,
    [switch]$Force,
    [switch]$Backup
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptParent = Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')
$selfContainedSkill = Test-Path -LiteralPath (Join-Path $scriptParent.Path 'SKILL.md') -PathType Leaf
$source = if ($selfContainedSkill) {
    $scriptParent.Path
} else {
    Join-Path $scriptParent.Path 'skills\zk-creative-process'
}
$scriptsSource = Join-Path $source 'scripts'
if (-not (Test-Path -LiteralPath $source -PathType Container)) {
    throw "Skill source not found: $source"
}
if (-not (Test-Path -LiteralPath $scriptsSource -PathType Container)) {
    $scriptsSource = Join-Path $scriptParent.Path 'scripts'
}
if (-not (Test-Path -LiteralPath $scriptsSource -PathType Container)) {
    throw "Bundled scripts not found. Expected scripts in the skill folder or repository root."
}

if ([string]::IsNullOrWhiteSpace($CodexSkillsDir)) {
    $homeDir = if ($env:USERPROFILE) { $env:USERPROFILE } else { $HOME }
    if ([string]::IsNullOrWhiteSpace($homeDir)) {
        throw 'Cannot resolve home directory. Pass -CodexSkillsDir explicitly.'
    }
    $CodexSkillsDir = Join-Path $homeDir '.codex\skills'
}

New-Item -ItemType Directory -Path $CodexSkillsDir -Force | Out-Null
$destination = Join-Path $CodexSkillsDir 'zk-creative-process'
$sourceResolved = (Resolve-Path -LiteralPath $source).Path
$destinationResolved = if (Test-Path -LiteralPath $destination) {
    (Resolve-Path -LiteralPath $destination).Path
} else {
    [IO.Path]::GetFullPath($destination)
}

if ($sourceResolved -eq $destinationResolved) {
    "Skill is already installed at: $destinationResolved"
    exit 0
}

if (Test-Path -LiteralPath $destination) {
    if ($Backup) {
        $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        $backup = "$destination.backup-$stamp"
        Move-Item -LiteralPath $destination -Destination $backup
        "Existing skill backed up to: $backup"
    } elseif ($Force) {
        Remove-Item -LiteralPath $destination -Recurse -Force
    } else {
        throw "Skill already exists: $destination. Rerun with -Backup to keep a backup, or -Force to replace it."
    }
}

Copy-Item -LiteralPath $source -Destination $destination -Recurse
if (-not (Test-Path -LiteralPath (Join-Path $destination 'scripts') -PathType Container)) {
    Copy-Item -LiteralPath $scriptsSource -Destination (Join-Path $destination 'scripts') -Recurse
}
"Installed zk-creative-process skill to: $destination"
"Bundled scripts copied to: $(Join-Path $destination 'scripts')"
"Restart Codex or start a new session if the skill does not appear immediately."
