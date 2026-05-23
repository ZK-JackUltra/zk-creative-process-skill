# Troubleshooting

## FFmpeg Not Found

The scripts need both `ffmpeg` and `ffprobe`.

Install options:

```powershell
winget install Gyan.FFmpeg
```

```bash
brew install ffmpeg
```

```bash
sudo apt install ffmpeg
```

If FFmpeg is installed but not on PATH, pass explicit paths:

```powershell
.\scripts\process-reference-video-phase1.ps1 `
  -VideoPath "C:\path\to\video.mp4" `
  -Slug "test-video" `
  -Name "test-video-测试视频" `
  -ProductBriefPath ".\my-product-brief.md" `
  -FfmpegPath "C:\ffmpeg\bin\ffmpeg.exe" `
  -FfprobePath "C:\ffmpeg\bin\ffprobe.exe"
```

## PowerShell Script Execution Is Disabled

If Windows blocks script execution, run PowerShell as your normal user and set:

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

Or run one command with bypass:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\check-environment.ps1
```

## Paths With Spaces Or Non-English Characters

Use quoted paths:

```powershell
-VideoPath "C:\Users\Me\Videos\test video.mp4"
```

The scripts use `-LiteralPath` internally and should support spaces and non-English characters.

## Skill Validation Fails On Windows Encoding

If `quick_validate.py` fails with a `UnicodeDecodeError`, enable UTF-8 for that terminal session:

```powershell
$env:PYTHONUTF8='1'
python "$env:USERPROFILE\.codex\skills\.system\skill-creator\scripts\quick_validate.py" .\skills\zk-creative-process
```

This repository intentionally uses Chinese filenames in generated analysis files, so UTF-8 validation is expected.

## Source Video Disappeared

Current scripts copy source videos by default. Originals stay in their original folder.

If a source video was moved, check whether the command used `-Move`. That flag deliberately moves originals into the generated material folder.

## Long Videos Are Slow

The default extracts 12 selected frames plus intermediate frames. For very long videos, first trim to the ad segment or lower the frame count:

```powershell
-StoryboardFrames 8
```

## Output Contains TODO

This is expected immediately after script setup. The script creates skeleton files. Codex should then fill:

- `product-brief-产品信息.md`
- `outputs/reference-video-storyboard-原视频场景变化分镜.md`
- `outputs/creative-script-directions-创意脚本方向.md`

For a `mix` folder, Codex should fill:

- `outputs/shared-analysis-同方向素材共性拆解.md`

## Product Mapping Looks Generic

Fill `product-brief-产品信息.md` or pass an existing file with `-ProductBriefPath`.

Without product context, Codex should only deconstruct the reference video and list missing product questions. It should not invent gameplay, assets, audience, or compliance constraints.

## Do Not Commit Generated Materials

Generated folders may include source videos and derived frames. Keep them out of git. This repository's `.gitignore` already ignores `creative-materials/`, `.tmp/`, and common video file extensions.
