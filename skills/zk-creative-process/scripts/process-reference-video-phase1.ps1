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

    [double]$SceneThreshold = 0.23,

    [switch]$StrictCheck
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $PSCommandPath
$startScript = Join-Path $scriptDir 'start-reference-video.ps1'
$checkScript = Join-Path $scriptDir 'check-creative-material.ps1'

$startArgs = @{
    VideoPath = $VideoPath
    Slug = $Slug
    Name = $Name
    StoryboardFrames = $StoryboardFrames
    SceneThreshold = $SceneThreshold
}
if (-not [string]::IsNullOrWhiteSpace($BaseDir)) { $startArgs.BaseDir = $BaseDir }
if (-not [string]::IsNullOrWhiteSpace($FfmpegPath)) { $startArgs.FfmpegPath = $FfmpegPath }
if (-not [string]::IsNullOrWhiteSpace($FfprobePath)) { $startArgs.FfprobePath = $FfprobePath }
if (-not [string]::IsNullOrWhiteSpace($ProductBriefPath)) { $startArgs.ProductBriefPath = $ProductBriefPath }
if ($Copy) { $startArgs.Copy = $true }
if ($Move) { $startArgs.Move = $true }
if ($KeepWork) { $startArgs.KeepWork = $true }

$startJson = & $startScript @startArgs | Out-String
if ($LASTEXITCODE -ne 0) {
    throw 'start-reference-video.ps1 failed.'
}
$startResult = $startJson | ConvertFrom-Json

$checkArgs = @{
    MaterialDir = $startResult.material_folder
    Json = $true
}
if ($StrictCheck) { $checkArgs.Strict = $true }

$checkJson = & $checkScript @checkArgs | Out-String
$checkExit = $LASTEXITCODE
$checkResult = $checkJson | ConvertFrom-Json

[ordered]@{
    material_folder = $startResult.material_folder
    ai_input_pack = $startResult.ai_input_pack
    final_storyboard_sheet = $startResult.final_storyboard_sheet
    frame_index = $startResult.frame_index
    brief = $startResult.brief
    product_brief = $startResult.product_brief
    reference_storyboard = $startResult.reference_storyboard
    creative_directions = $startResult.creative_directions
    manifest = $startResult.manifest
    check_status = $checkResult.status
    check_errors = $checkResult.errors
    check_warnings = $checkResult.warnings
    next_step = 'AI reads _system-review-系统复查资料/ai-input-pack.md, product-brief-产品信息.md, and the keyframe contact sheet, then replaces the output skeleton documents. If product brief is incomplete, product mapping stays pending.'
} | ConvertTo-Json -Depth 8

if ($checkExit -ne 0) {
    exit $checkExit
}
