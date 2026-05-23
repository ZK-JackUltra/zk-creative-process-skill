# ZK Creative Process Skill

A Codex skill and PowerShell toolkit for processing game-ad reference videos into clean creative-analysis folders.

Core workflow:

```text
reference-video deconstruction -> product-brief-产品信息.md -> map into your own product
```

## What It Creates

```text
creative-materials/YYYY-MM-DD-slug-name/
  original-name.mp4
  keyframes-reference-storyboard-contact-sheet-name.jpg
  brief.md
  product-brief-产品信息.md
  outputs/
    reference-video-storyboard-原视频场景变化分镜.md
    creative-script-directions-创意脚本方向.md
  _system-review-系统复查资料/
    ai-input-pack.md
    frame-index.json
    run-manifest.json
    video_metadata.json
```

`product-brief-产品信息.md` is the bridge from reference analysis to your own product. If it is empty, Codex should not invent product facts; mapping stays pending.

## Install

Run from this repository root:

```powershell
.\scripts\install-skill.ps1
```

If the skill already exists, the installer stops. Choose explicitly:

```powershell
.\scripts\install-skill.ps1 -Backup
.\scripts\install-skill.ps1 -Force
```

`-Backup` keeps the old installed skill. `-Force` replaces it.

## Use In Codex

Single reference video:

```text
用 $zk-creative-process single 处理这个视频：C:\path\to\video.mp4
```

Same-direction batch:

```text
用 $zk-creative-process mix 把这几个同方向视频合并分析：C:\path\to\video-1.mp4, C:\path\to\video-2.mp4
```

The scripts copy source videos by default. Originals stay where they are. Use `-Move` only when you deliberately want originals moved into the material folder.

## Requirements

- PowerShell 7+ recommended.
- FFmpeg and FFprobe available on PATH, or pass `-FfmpegPath` and `-FfprobePath`.

Check environment:

```powershell
.\scripts\check-environment.ps1
```

Validate generated material:

```powershell
.\scripts\check-creative-material.ps1 -MaterialDir ".\creative-materials\YYYY-MM-DD-slug-name"
```

Validate skill metadata on Windows:

```powershell
$env:PYTHONUTF8='1'
python "$env:USERPROFILE\.codex\skills\.system\skill-creator\scripts\quick_validate.py" .\skills\zk-creative-process
```

## Docs

- [Creative process guide](docs/creative-process-guide.md)
- [Folder structure](docs/example-folder-structure.md)
- [Troubleshooting](docs/troubleshooting.md)
- [Single example](examples/single/README.md)
- [Mix example](examples/mix/README.md)

## Privacy

- Do not commit customer videos, competitor videos, ad data, product strategy, filled product briefs, or generated `creative-materials/`.
- `.gitignore` ignores common video formats, `.tmp/`, and generated folders by default, except the bundled public sample `shower.mp4`.
- The included scripts are generic and do not depend on a private project folder.
