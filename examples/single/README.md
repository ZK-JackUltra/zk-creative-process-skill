# Single Example

Run:

```powershell
.\scripts\process-reference-video-phase1.ps1 `
  -VideoPath "C:\path\to\reference.mp4" `
  -Slug "dragon-flight" `
  -Name "dragon-flight-飞龙换场景" `
  -BaseDir ".\creative-materials" `
  -ProductBriefPath ".\my-product-brief.md"
```

`-ProductBriefPath` is optional. If omitted, fill the generated `product-brief-产品信息.md` before asking Codex for product-specific script directions.

Then ask Codex:

```text
$zk-creative-process single .\creative-materials\2026-05-23-dragon-flight-飞龙换场景
```
