param(
    [Parameter(Mandatory = $true)]
    [string]$VideoPath,

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

    [int]$StoryboardFrames = 12,

    [double]$SceneThreshold = 0.23
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-SafeFileNamePart {
    param([string]$Value, [string]$FieldName)
    if ([string]::IsNullOrWhiteSpace($Value)) {
        throw "$FieldName cannot be empty."
    }
    if ($Value -match '[\\/:*?"<>|]') {
        throw "$FieldName contains invalid filename characters: $Value"
    }
}

function Resolve-FilePath {
    param([string]$Path)
    $resolved = Resolve-Path -LiteralPath $Path -ErrorAction SilentlyContinue
    if (-not $resolved) {
        throw "Path not found: $Path"
    }
    return $resolved.Path
}

function Resolve-Executable {
    param([string]$ExplicitPath, [string]$CommandName)
    if (-not [string]::IsNullOrWhiteSpace($ExplicitPath)) {
        return Resolve-FilePath $ExplicitPath
    }
    $cmd = Get-Command $CommandName -ErrorAction SilentlyContinue
    if (-not $cmd) {
        $paramName = if ($CommandName -eq 'ffmpeg') { 'FfmpegPath' } elseif ($CommandName -eq 'ffprobe') { 'FfprobePath' } else { "$($CommandName)Path" }
        throw "Required executable not found on PATH: $CommandName. Install FFmpeg first, then rerun scripts/check-environment.ps1. Windows: winget install Gyan.FFmpeg. macOS: brew install ffmpeg. Linux: use your package manager. If it is already installed, pass -$paramName with the full executable path."
    }
    return $cmd.Source
}

function Parse-Fps {
    param([string]$Rate)
    if (-not $Rate -or $Rate -notmatch '/') {
        return $null
    }
    $parts = $Rate.Split('/')
    $num = [double]$parts[0]
    $den = [double]$parts[1]
    if ($den -eq 0) {
        return $null
    }
    return [Math]::Round($num / $den, 4)
}

function Invoke-Logged {
    param(
        [string]$Exe,
        [string[]]$Arguments,
        [string]$LogPath,
        [switch]$AllowFailure
    )
    & $Exe @Arguments *> $LogPath
    if ($LASTEXITCODE -ne 0) {
        if ($AllowFailure) {
            return $false
        }
        throw "Command failed. See log: $LogPath"
    }
    if ($AllowFailure) {
        return $true
    }
    return $true
}

function New-TileSheet {
    param(
        [string]$Ffmpeg,
        [string]$Pattern,
        [int]$Count,
        [int]$Columns,
        [string]$OutputPath,
        [string]$LogPath
    )
    if ($Count -le 0) {
        return $false
    }
    $rows = [Math]::Ceiling($Count / $Columns)
    Invoke-Logged -Exe $Ffmpeg -Arguments @(
        '-hide_banner', '-y',
        '-framerate', '1',
        '-i', $Pattern,
        '-vf', "tile=${Columns}x${rows}:padding=4:margin=2",
        '-frames:v', '1',
        $OutputPath
    ) -LogPath $LogPath | Out-Null
    return $true
}

Assert-SafeFileNamePart -Value $Name -FieldName 'Name'
if ($Copy -and $Move) {
    throw 'Use either -Copy or -Move, not both. Copy is the default.'
}
if ($StoryboardFrames -lt 4 -or $StoryboardFrames -gt 30) {
    throw 'StoryboardFrames must be between 4 and 30.'
}

$ffmpeg = Resolve-Executable -ExplicitPath $FfmpegPath -CommandName 'ffmpeg'
$ffprobe = Resolve-Executable -ExplicitPath $FfprobePath -CommandName 'ffprobe'

if ([string]::IsNullOrWhiteSpace($BaseDir)) {
    $BaseDir = Join-Path (Get-Location).Path 'creative-materials'
}
if (-not (Test-Path -LiteralPath $BaseDir -PathType Container)) {
    New-Item -ItemType Directory -Path $BaseDir -Force | Out-Null
}
$baseDirResolved = Resolve-Path -LiteralPath $BaseDir

$sourceVideo = Resolve-FilePath $VideoPath
$extension = [IO.Path]::GetExtension($sourceVideo)
if ([string]::IsNullOrWhiteSpace($extension)) {
    $extension = '.mp4'
}

$datePrefix = Get-Date -Format 'yyyy-MM-dd'
$materialName = "$datePrefix-$Slug-$Name"
$materialDir = Join-Path $baseDirResolved.Path $materialName
if (Test-Path -LiteralPath $materialDir) {
    throw "Material folder already exists: $materialDir"
}

New-Item -ItemType Directory -Path $materialDir | Out-Null
$outputsDir = Join-Path $materialDir 'outputs'
$systemDir = Join-Path $materialDir '_system-review-系统复查资料'
New-Item -ItemType Directory -Path $outputsDir, $systemDir | Out-Null

$destVideo = Join-Path $materialDir "original-$Name$extension"
if ($Move) {
    Move-Item -LiteralPath $sourceVideo -Destination $destVideo
    $videoAction = 'moved'
} else {
    Copy-Item -LiteralPath $sourceVideo -Destination $destVideo
    $videoAction = 'copied'
}

$productBriefOutputPath = Join-Path $materialDir 'product-brief-产品信息.md'
if (-not [string]::IsNullOrWhiteSpace($ProductBriefPath)) {
    $resolvedProductBrief = Resolve-FilePath $ProductBriefPath
    Copy-Item -LiteralPath $resolvedProductBrief -Destination $productBriefOutputPath
} else {
@"
# Product Brief

Fill this before asking AI to map the reference video into your own product.

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
- Mechanics that can connect to the reference hook: TODO
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

$probeJson = & $ffprobe -v error -print_format json -show_streams -show_format $destVideo | Out-String
if ($LASTEXITCODE -ne 0) {
    throw 'ffprobe failed.'
}
$probe = $probeJson | ConvertFrom-Json
$videoStreams = @($probe.streams | Where-Object { $_.codec_type -eq 'video' } | Select-Object -First 1)
if ($videoStreams.Count -eq 0) {
    throw 'No video stream found.'
}
$videoStream = $videoStreams[0]
$audioStreams = @($probe.streams | Where-Object { $_.codec_type -eq 'audio' } | Select-Object -First 1)
$audioStream = if ($audioStreams.Count -gt 0) { $audioStreams[0] } else { $null }

$duration = $null
if ($videoStream.duration) {
    $duration = [double]$videoStream.duration
} elseif ($probe.format.duration) {
    $duration = [double]$probe.format.duration
}
if (-not $duration -or $duration -le 0) {
    throw 'Cannot determine video duration.'
}

$metadataPath = Join-Path $systemDir 'video_metadata.json'
[ordered]@{
    generated_at = (Get-Date).ToString('s')
    source_video_action = $videoAction
    material_folder = $materialDir
    file = Split-Path -Leaf $destVideo
    video = [ordered]@{
        codec = $videoStream.codec_name
        width = $videoStream.width
        height = $videoStream.height
        r_frame_rate = $videoStream.r_frame_rate
        fps = Parse-Fps $videoStream.r_frame_rate
        duration_seconds = [Math]::Round($duration, 3)
        nb_frames = $videoStream.nb_frames
    }
    audio = if ($audioStream) {
        [ordered]@{
            codec = $audioStream.codec_name
            duration_seconds = if ($audioStream.duration) { [Math]::Round([double]$audioStream.duration, 3) } else { $null }
        }
    } else {
        $null
    }
    format = [ordered]@{
        duration_seconds = if ($probe.format.duration) { [Math]::Round([double]$probe.format.duration, 3) } else { $null }
        size_bytes = if ($probe.format.size) { [int64]$probe.format.size } else { $null }
        bit_rate = $probe.format.bit_rate
    }
} | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $metadataPath -Encoding UTF8

$workDir = Join-Path $materialDir 'keyframes-work'
$uniformDir = Join-Path $workDir 'uniform'
$sceneDir = Join-Path $workDir 'scene'
$selectedDir = Join-Path $workDir 'selected'
New-Item -ItemType Directory -Path $uniformDir, $sceneDir, $selectedDir -Force | Out-Null

Invoke-Logged -Exe $ffmpeg -Arguments @(
    '-hide_banner', '-y',
    '-i', $destVideo,
    '-vf', 'fps=1,scale=360:-1',
    (Join-Path $uniformDir 'uniform-%03d.jpg')
) -LogPath (Join-Path $workDir 'ffmpeg-uniform.log') | Out-Null

Invoke-Logged -Exe $ffmpeg -Arguments @(
    '-hide_banner', '-y',
    '-i', $destVideo,
    '-vf', "select='gt(scene,$SceneThreshold)',scale=360:-1",
    '-vsync', 'vfr',
    (Join-Path $sceneDir 'scene-%03d.jpg')
) -LogPath (Join-Path $workDir 'ffmpeg-scene.log') -AllowFailure | Out-Null

$startTime = 0.03
$endTime = [Math]::Max($startTime, $duration - 0.35)
$selectedFrames = @()
for ($i = 0; $i -lt $StoryboardFrames; $i++) {
    $ratio = if ($StoryboardFrames -eq 1) { 0 } else { $i / ($StoryboardFrames - 1) }
    $timestamp = $startTime + (($endTime - $startTime) * $ratio)
    $nameForFrame = 'selected-{0:D2}.jpg' -f ($i + 1)
    Invoke-Logged -Exe $ffmpeg -Arguments @(
        '-hide_banner', '-y',
        '-ss', ([string][Math]::Round($timestamp, 3)),
        '-i', $destVideo,
        '-frames:v', '1',
        '-q:v', '2',
        '-vf', 'scale=360:-1',
        '-update', '1',
        (Join-Path $selectedDir $nameForFrame)
    ) -LogPath (Join-Path $workDir ('ffmpeg-selected-{0:D2}.log' -f ($i + 1))) | Out-Null
    $selectedFrames += [ordered]@{
        index = $i + 1
        timestamp_seconds = [Math]::Round($timestamp, 3)
        work_file = $nameForFrame
        contact_sheet_position = [ordered]@{
            row = [int]([Math]::Floor($i / 4) + 1)
            column = [int](($i % 4) + 1)
        }
        ai_instruction = "Use contact sheet frame $($i + 1) at approximately $([Math]::Round($timestamp, 2))s."
    }
}

$frameIndexPath = Join-Path $systemDir 'frame-index.json'
[ordered]@{
    generated_at = (Get-Date).ToString('s')
    source_video = Split-Path -Leaf $destVideo
    contact_sheet = "keyframes-reference-storyboard-contact-sheet-$Name.jpg"
    frame_count = $StoryboardFrames
    selection_method = 'uniform timestamps across source duration'
    frames = $selectedFrames
} | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $frameIndexPath -Encoding UTF8

$finalSheet = Join-Path $materialDir "keyframes-reference-storyboard-contact-sheet-$Name.jpg"
New-TileSheet -Ffmpeg $ffmpeg `
    -Pattern (Join-Path $selectedDir 'selected-%02d.jpg') `
    -Count $StoryboardFrames `
    -Columns 4 `
    -OutputPath $finalSheet `
    -LogPath (Join-Path $workDir 'ffmpeg-final-sheet.log') | Out-Null

$briefPath = Join-Path $materialDir 'brief.md'
@"
# $Name Reference Video Creative Task

## Source Video

- File: [original-$Name$extension](original-$Name$extension)
- Video: $([Math]::Round($duration, 2)) seconds, $($videoStream.width)x$($videoStream.height), $((Parse-Fps $videoStream.r_frame_rate))fps.
- Metadata: [_system-review-系统复查资料/video_metadata.json](_system-review-系统复查资料/video_metadata.json)

## Generated Assets

- Keyframe contact sheet: [keyframes-reference-storyboard-contact-sheet-$Name.jpg](keyframes-reference-storyboard-contact-sheet-$Name.jpg)
- Output folder: [outputs](outputs/)
- Product brief: [product-brief-产品信息.md](product-brief-产品信息.md)

## Product Context

Fill `product-brief-产品信息.md` before mapping the reference structure into your own product.

## AI Output Requirements

- Fill `outputs/reference-video-storyboard-原视频场景变化分镜.md`.
- Fill `outputs/creative-script-directions-创意脚本方向.md`.
- First produce a story-direction pool only.
- Do not create production storyboard or prompt folders until a direction is selected.
"@ | Set-Content -LiteralPath $briefPath -Encoding UTF8

$referencePath = Join-Path $outputsDir 'reference-video-storyboard-原视频场景变化分镜.md'
@"
# Reference Video Storyboard

## Keyframe And Metadata

- Keyframe contact sheet: [keyframes-reference-storyboard-contact-sheet-$Name.jpg](../keyframes-reference-storyboard-contact-sheet-$Name.jpg)
- Metadata: [video_metadata.json](../_system-review-系统复查资料/video_metadata.json)

## Scene Progression

| Order | Representative frame | Scene content | Information progress | Transferable structure |
| --- | --- | --- | --- | --- |
| 1 | TODO | TODO | TODO | TODO |

## Underlying Structure

TODO

## Transfer Notes

TODO

## Do Not Copy Directly

TODO
"@ | Set-Content -LiteralPath $referencePath -Encoding UTF8

$directionsPath = Join-Path $outputsDir 'creative-script-directions-创意脚本方向.md'
@"
# Creative Script Directions

## Assumptions

TODO

## Direction Overview

| Direction | Core hook | User desire | What to test | Risk |
| --- | --- | --- | --- | --- |
| 1 | TODO | TODO | TODO | TODO |

## Direction 1

### Core Hypothesis

TODO

### Hook

TODO

### Story Premise

TODO

### Conflict And Trigger

TODO

### Product Bridge

TODO

### Product Mapping

Use `../product-brief-产品信息.md`. If it still contains TODO or lacks product-specific information, list missing questions and mark product mapping as pending.

### Scalable Variants

TODO

### Metrics To Test

TODO

### Human Decision Questions

TODO
"@ | Set-Content -LiteralPath $directionsPath -Encoding UTF8

$aiInputPackPath = Join-Path $systemDir 'ai-input-pack.md'
@"
# AI Input Pack: $Name

Read this file first, then inspect the keyframe contact sheet and frame-index.

## Paths

- Material folder: $materialDir
- Source video: $destVideo
- Keyframe contact sheet: $finalSheet
- Frame index: $frameIndexPath
- Reference storyboard: $referencePath
- Creative directions: $directionsPath
- Product brief: $productBriefOutputPath

## Video

- Duration: $([Math]::Round($duration, 2)) seconds
- Size: $($videoStream.width)x$($videoStream.height)
- FPS: $((Parse-Fps $videoStream.r_frame_rate))
- Selected frames: $StoryboardFrames

## First Stage Rules

- Fill reference-video-storyboard-原视频场景变化分镜.md.
- Fill creative-script-directions-创意脚本方向.md.
- Use product-brief-产品信息.md for product mapping.
- If product-brief-产品信息.md still contains TODO or lacks product-specific information, do not invent product facts. Output the missing questions and keep product mapping marked as pending.
- Only create a story-direction pool.
- Do not create production scripts or prompts until the user selects a direction.
"@ | Set-Content -LiteralPath $aiInputPackPath -Encoding UTF8

$manifestPath = Join-Path $systemDir 'run-manifest.json'
[ordered]@{
    generated_at = (Get-Date).ToString('s')
    script = $PSCommandPath
    material_folder = $materialDir
    video = $destVideo
    metadata = $metadataPath
    frame_index = $frameIndexPath
    final_storyboard_sheet = $finalSheet
    ai_input_pack = $aiInputPackPath
    brief = $briefPath
    product_brief = $productBriefOutputPath
    outputs = @($referencePath, $directionsPath)
    temp_work_dir_kept = [bool]$KeepWork
    frame_counts = [ordered]@{
        selected = $StoryboardFrames
        uniform = @(Get-ChildItem -LiteralPath $uniformDir -Filter '*.jpg').Count
        scene = @(Get-ChildItem -LiteralPath $sceneDir -Filter '*.jpg').Count
    }
    next_ai_inputs = @(
        'Read _system-review-系统复查资料/ai-input-pack.md.',
        'Open final_storyboard_sheet once.',
        'Use _system-review-系统复查资料/frame-index.json for timestamp and contact-sheet positions.',
        'Replace skeleton text in outputs with AI analysis.'
    )
} | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $manifestPath -Encoding UTF8

if (-not $KeepWork) {
    $rootResolved = Resolve-Path -LiteralPath $materialDir
    $workResolved = Resolve-Path -LiteralPath $workDir
    if (-not $workResolved.Path.StartsWith($rootResolved.Path)) {
        throw "Refusing to delete work dir outside material folder: $($workResolved.Path)"
    }
    Remove-Item -LiteralPath $workResolved.Path -Recurse -Force
}

[ordered]@{
    material_folder = $materialDir
    ai_input_pack = $aiInputPackPath
    final_storyboard_sheet = $finalSheet
    frame_index = $frameIndexPath
    brief = $briefPath
    product_brief = $productBriefOutputPath
    reference_storyboard = $referencePath
    creative_directions = $directionsPath
    manifest = $manifestPath
} | ConvertTo-Json -Depth 4
