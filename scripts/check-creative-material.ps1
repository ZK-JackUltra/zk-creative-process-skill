param(
    [Parameter(Mandatory = $true)]
    [string]$MaterialDir,

    [switch]$Strict,

    [switch]$Json
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Add-Issue {
    param(
        [System.Collections.Generic.List[object]]$Issues,
        [string]$Severity,
        [string]$Code,
        [string]$Message,
        [string]$Path = ''
    )
    $Issues.Add([ordered]@{
        severity = $Severity
        code = $Code
        message = $Message
        path = $Path
    }) | Out-Null
}

$resolvedMaterial = Resolve-Path -LiteralPath $MaterialDir -ErrorAction SilentlyContinue
if (-not $resolvedMaterial) {
    throw "MaterialDir not found: $MaterialDir"
}

$materialPath = $resolvedMaterial.Path
$outputsDir = Join-Path $materialPath 'outputs'
$systemDir = Join-Path $materialPath '_system-review-系统复查资料'
$issues = [System.Collections.Generic.List[object]]::new()

foreach ($file in @('brief.md', 'product-brief-产品信息.md')) {
    $path = Join-Path $materialPath $file
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        Add-Issue -Issues $issues -Severity 'error' -Code 'missing_required_file' -Message "Missing required file: $file" -Path $path
    }
}

if (-not (Test-Path -LiteralPath $systemDir -PathType Container)) {
    Add-Issue -Issues $issues -Severity 'error' -Code 'missing_system_dir' -Message 'Missing _system-review-系统复查资料 directory.' -Path $systemDir
}

foreach ($file in @('video_metadata.json', 'run-manifest.json', 'frame-index.json', 'ai-input-pack.md')) {
    $path = Join-Path $systemDir $file
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        Add-Issue -Issues $issues -Severity 'error' -Code 'missing_system_file' -Message "Missing system file: $file" -Path $path
    }
}

$storyboardSheets = @(Get-ChildItem -LiteralPath $materialPath -File -Filter 'keyframes-reference-storyboard-contact-sheet-*.jpg' -ErrorAction SilentlyContinue)
if ($storyboardSheets.Count -eq 0) {
    Add-Issue -Issues $issues -Severity 'error' -Code 'missing_contact_sheet' -Message 'Missing keyframes contact sheet.' -Path $materialPath
}

$videos = @(Get-ChildItem -LiteralPath $materialPath -File -Filter 'original-*' -ErrorAction SilentlyContinue)
if ($videos.Count -eq 0) {
    $videos = @(Get-ChildItem -LiteralPath $materialPath -File -Filter 'video-*' -ErrorAction SilentlyContinue)
}
if ($videos.Count -eq 0) {
    Add-Issue -Issues $issues -Severity 'error' -Code 'missing_reference_video' -Message 'Missing reference video. Expected original-* for single or video-* for mix.' -Path $materialPath
}

if (-not (Test-Path -LiteralPath $outputsDir -PathType Container)) {
    Add-Issue -Issues $issues -Severity 'error' -Code 'missing_outputs_dir' -Message 'Missing outputs directory.' -Path $outputsDir
} else {
    $singleOutputFiles = @('reference-video-storyboard-原视频场景变化分镜.md', 'creative-script-directions-创意脚本方向.md')
    $hasSingleOutputs = $true
    foreach ($file in $singleOutputFiles) {
        $path = Join-Path $outputsDir $file
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            $hasSingleOutputs = $false
        }
    }

    $hasMixOutput = @(Get-ChildItem -LiteralPath $outputsDir -File -Filter 'shared-analysis-*.md' -ErrorAction SilentlyContinue).Count -gt 0
    if (-not $hasSingleOutputs -and -not $hasMixOutput) {
        Add-Issue -Issues $issues -Severity 'error' -Code 'missing_output_file' -Message 'Missing output files. Expected single outputs or shared-analysis-*.md for mix.' -Path $outputsDir
    }
}

$mdFiles = @(
    Get-ChildItem -LiteralPath $materialPath -Recurse -File -Filter '*.md' -ErrorAction SilentlyContinue |
        Where-Object { -not $_.FullName.StartsWith($systemDir) }
)
foreach ($file in $mdFiles) {
    $content = Get-Content -LiteralPath $file.FullName -Raw
    if ($content -match 'TODO') {
        Add-Issue -Issues $issues -Severity 'warning' -Code 'placeholder_text' -Message 'Markdown file still contains placeholder text.' -Path $file.FullName
    }
}

$errorCount = @($issues | Where-Object { $_.severity -eq 'error' }).Count
$warningCount = @($issues | Where-Object { $_.severity -eq 'warning' }).Count
$result = [ordered]@{
    material_folder = $materialPath
    checked_at = (Get-Date).ToString('s')
    status = if ($errorCount -gt 0 -or ($Strict -and $warningCount -gt 0)) { 'failed' } else { 'passed' }
    errors = $errorCount
    warnings = $warningCount
    issues = $issues
}

if ($Json) {
    $result | ConvertTo-Json -Depth 8
} else {
    "Material check: $($result.status)"
    "Errors: $errorCount"
    "Warnings: $warningCount"
    foreach ($issue in $issues) {
        "[$($issue.severity)] $($issue.code): $($issue.message) $($issue.path)"
    }
}

if ($errorCount -gt 0 -or ($Strict -and $warningCount -gt 0)) {
    exit 1
}
