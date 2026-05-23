param(
    [Parameter(Mandatory = $true)]
    [string[]]$VideoPaths,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[a-z0-9][a-z0-9-]*$')]
    [string]$Slug,

    [Parameter(Mandatory = $true)]
    [string]$Name,

    [string]$BaseDir,

    [string]$FfmpegPath,

    [string]$FfprobePath,

    [string]$ProductBriefPath,

    [switch]$Copy,

    [switch]$Move,

    [switch]$KeepWork,

    [int]$StoryboardFrames = 8
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($VideoPaths.Count -lt 2) {
    throw 'mix mode requires at least two videos.'
}
if ($Copy -and $Move) {
    throw 'Use either -Copy or -Move, not both. Copy is the default.'
}
if ($StoryboardFrames -lt 4 -or $StoryboardFrames -gt 30) {
    throw 'StoryboardFrames must be between 4 and 30.'
}
if ($Name -match '[\\/:*?"<>|]') {
    throw "Name contains invalid filename characters: $Name"
}

function Resolve-Executable {
    param([string]$ExplicitPath, [string]$CommandName)
    if (-not [string]::IsNullOrWhiteSpace($ExplicitPath)) {
        return (Resolve-Path -LiteralPath $ExplicitPath).Path
    }
    $cmd = Get-Command $CommandName -ErrorAction SilentlyContinue
    if (-not $cmd) {
        throw "$CommandName not found. Run scripts/install-ffmpeg.ps1 or pass explicit paths."
    }
    return $cmd.Source
}

function Invoke-Logged {
    param([string]$Exe, [string[]]$Arguments, [string]$LogPath)
    & $Exe @Arguments *> $LogPath
    if ($LASTEXITCODE -ne 0) {
        throw "Command failed. See log: $LogPath"
    }
}

$ffmpeg = Resolve-Executable -ExplicitPath $FfmpegPath -CommandName 'ffmpeg'
$ffprobe = Resolve-Executable -ExplicitPath $FfprobePath -CommandName 'ffprobe'
if ([string]::IsNullOrWhiteSpace($BaseDir)) {
    $BaseDir = Join-Path (Get-Location).Path 'creative-materials'
}
New-Item -ItemType Directory -Path $BaseDir -Force | Out-Null
$baseDirResolved = Resolve-Path -LiteralPath $BaseDir

$datePrefix = Get-Date -Format 'yyyy-MM-dd'
$materialDir = Join-Path $baseDirResolved.Path "$datePrefix-$Slug-$Name"
if (Test-Path -LiteralPath $materialDir) {
    throw "Material folder already exists: $materialDir"
}
$outputsDir = Join-Path $materialDir 'outputs'
$systemDir = Join-Path $materialDir '_system-review-系统复查资料'
$workDir = Join-Path $materialDir 'keyframes-work'
New-Item -ItemType Directory -Path $materialDir, $outputsDir, $systemDir, $workDir -Force | Out-Null

$productBriefOutputPath = Join-Path $materialDir 'product-brief-产品信息.md'
if (-not [string]::IsNullOrWhiteSpace($ProductBriefPath)) {
    $resolvedProductBrief = (Resolve-Path -LiteralPath $ProductBriefPath).Path
    Copy-Item -LiteralPath $resolvedProductBrief -Destination $productBriefOutputPath
} else {
@"
# Product Brief

Fill this before asking AI to map the reference videos into your own product.

## Product Basics

- Product/game name: TODO
- Genre/category: TODO
- Target market and audience: TODO
- Platform and ad channel: TODO

## Core Gameplay

- Main loop: TODO
- First 30 seconds of real user experience: TODO
- Core interaction the ad can truthfully show: TODO
- Progression, upgrade, merge, battle, puzzle, building, collection, or other system: TODO

## Sellable Hooks

- Strongest fantasy or desire: TODO
- Visual assets already available: TODO
- Mechanics that can connect to this shared reference direction: TODO
- Emotional payoff after the hook: TODO

## Constraints

- Must show: TODO
- Must avoid: TODO
- Production constraints: TODO
- Compliance/platform constraints: TODO

## Mapping Goal

- Acquisition goal: TODO
- Creative angle to test: TODO
- Success metric: TODO

## Privacy Reminder

Do not include API keys, unreleased financial data, personal information, or private partner data in this file.
"@ | Set-Content -LiteralPath $productBriefOutputPath -Encoding UTF8
}

$metadataItems = @()
$frameItems = @()
$videoIndex = 0
foreach ($path in $VideoPaths) {
    $videoIndex++
    $source = (Resolve-Path -LiteralPath $path).Path
    $extension = [IO.Path]::GetExtension($source)
    if ([string]::IsNullOrWhiteSpace($extension)) { $extension = '.mp4' }
    $destName = 'video-{0:D2}-{1}{2}' -f $videoIndex, ([IO.Path]::GetFileNameWithoutExtension($source)), $extension
    $dest = Join-Path $materialDir $destName
    if ($Move) { Move-Item -LiteralPath $source -Destination $dest } else { Copy-Item -LiteralPath $source -Destination $dest }

    $probeJson = & $ffprobe -v error -print_format json -show_streams -show_format $dest | Out-String
    if ($LASTEXITCODE -ne 0) { throw "ffprobe failed for $dest" }
    $probe = $probeJson | ConvertFrom-Json
    $videoStream = @($probe.streams | Where-Object { $_.codec_type -eq 'video' } | Select-Object -First 1)[0]
    $duration = if ($videoStream.duration) { [double]$videoStream.duration } else { [double]$probe.format.duration }
    $metadataItems += [ordered]@{
        index = $videoIndex
        file = $destName
        duration_seconds = [Math]::Round($duration, 3)
        width = $videoStream.width
        height = $videoStream.height
        codec = $videoStream.codec_name
    }

    $selectedDir = Join-Path $workDir ('selected-{0:D2}' -f $videoIndex)
    New-Item -ItemType Directory -Path $selectedDir -Force | Out-Null
    $framesForVideo = @()
    $startTime = 0.03
    $endTime = [Math]::Max($startTime, $duration - 0.35)
    for ($i = 0; $i -lt $StoryboardFrames; $i++) {
        $ratio = if ($StoryboardFrames -eq 1) { 0 } else { $i / ($StoryboardFrames - 1) }
        $timestamp = $startTime + (($endTime - $startTime) * $ratio)
        $frameName = 'selected-{0:D2}.jpg' -f ($i + 1)
        Invoke-Logged -Exe $ffmpeg -Arguments @(
            '-hide_banner', '-y',
            '-ss', ([string][Math]::Round($timestamp, 3)),
            '-i', $dest,
            '-frames:v', '1',
            '-q:v', '2',
            '-vf', 'scale=360:-1',
            '-update', '1',
            (Join-Path $selectedDir $frameName)
        ) -LogPath (Join-Path $workDir ('ffmpeg-video-{0:D2}-frame-{1:D2}.log' -f $videoIndex, ($i + 1)))
        $framesForVideo += [ordered]@{
            index = $i + 1
            timestamp_seconds = [Math]::Round($timestamp, 3)
        }
    }
    $sheet = Join-Path $materialDir ('keyframes-reference-storyboard-contact-sheet-{0}-video-{1:D2}.jpg' -f $Name, $videoIndex)
    $rows = [Math]::Ceiling($StoryboardFrames / 4)
    Invoke-Logged -Exe $ffmpeg -Arguments @(
        '-hide_banner', '-y',
        '-framerate', '1',
        '-i', (Join-Path $selectedDir 'selected-%02d.jpg'),
        '-vf', "tile=4x${rows}:padding=4:margin=2",
        '-frames:v', '1',
        $sheet
    ) -LogPath (Join-Path $workDir ('ffmpeg-sheet-video-{0:D2}.log' -f $videoIndex))
    $frameItems += [ordered]@{
        video_index = $videoIndex
        video_file = $destName
        contact_sheet = Split-Path -Leaf $sheet
        frames = $framesForVideo
    }
}

[ordered]@{
    generated_at = (Get-Date).ToString('s')
    mode = 'mix'
    videos = $metadataItems
} | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $systemDir 'video_metadata.json') -Encoding UTF8

[ordered]@{
    generated_at = (Get-Date).ToString('s')
    mode = 'mix'
    frame_count_per_video = $StoryboardFrames
    videos = $frameItems
} | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $systemDir 'frame-index.json') -Encoding UTF8

$briefPath = Join-Path $materialDir 'brief.md'
@"
# $Name Mixed Reference Creative Task

## Source Videos

$(
    ($metadataItems | ForEach-Object { "- Video $($_.index): $($_.file), $($_.duration_seconds)s, $($_.width)x$($_.height)" }) -join "`r`n"
)

## Generated Assets

- Per-video keyframe contact sheets are in the material root.
- System files are in `_system-review-系统复查资料/`.
- Shared analysis goes in `outputs/`.
- Product brief: [product-brief-产品信息.md](product-brief-产品信息.md)

## Shared Direction

TODO: describe the shared hook, theme, or creative direction.

## Product Mapping Context

Fill `product-brief-产品信息.md` before mapping this shared direction into your own product.
"@ | Set-Content -LiteralPath $briefPath -Encoding UTF8

$sharedPath = Join-Path $outputsDir 'shared-analysis-同方向素材共性拆解.md'
@"
# Shared Analysis

## Common Hook

TODO

## Differences Between Videos

TODO

## Transferable Structure

TODO

## Product Mapping

Use `../product-brief-产品信息.md`. If it still contains TODO or lacks product-specific information, list missing questions and mark product mapping as pending.

## Creative Direction Pool

TODO
"@ | Set-Content -LiteralPath $sharedPath -Encoding UTF8

$aiPackPath = Join-Path $systemDir 'ai-input-pack.md'
@"
# AI Input Pack: $Name

This is a same-direction multi-video batch.

## Files

- Brief: $briefPath
- Shared analysis: $sharedPath
- Product brief: $productBriefOutputPath
- Frame index: $(Join-Path $systemDir 'frame-index.json')
- Metadata: $(Join-Path $systemDir 'video_metadata.json')

## Rule

Analyze these videos as one direction-level creative task. Do not split them into independent single-video folders.
Use product-brief-产品信息.md for product mapping. If product information is missing, do not invent product facts; output the missing questions and keep product mapping marked as pending.
"@ | Set-Content -LiteralPath $aiPackPath -Encoding UTF8

$manifestPath = Join-Path $systemDir 'run-manifest.json'
[ordered]@{
    generated_at = (Get-Date).ToString('s')
    mode = 'mix'
    script = $PSCommandPath
    material_folder = $materialDir
    ai_input_pack = $aiPackPath
    brief = $briefPath
    product_brief = $productBriefOutputPath
    outputs = @($sharedPath)
    video_count = $metadataItems.Count
} | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $manifestPath -Encoding UTF8

$materialResolved = Resolve-Path -LiteralPath $materialDir
$workResolved = Resolve-Path -LiteralPath $workDir
if (-not $workResolved.Path.StartsWith($materialResolved.Path)) {
    throw "Refusing to remove work directory outside material folder: $($workResolved.Path)"
}
if (-not $KeepWork) {
    Remove-Item -LiteralPath $workResolved.Path -Recurse -Force
}

[ordered]@{
    material_folder = $materialDir
    ai_input_pack = $aiPackPath
    brief = $briefPath
    product_brief = $productBriefOutputPath
    shared_analysis = $sharedPath
    manifest = $manifestPath
    temp_work_dir_kept = [bool]$KeepWork
} | ConvertTo-Json -Depth 6
