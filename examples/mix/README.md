# Mix Example

Use `mix` when several videos share the same creative direction.

Run:

```powershell
.\scripts\process-reference-videos-mix.ps1 `
  -VideoPaths "C:\path\to\hook-1.mp4","C:\path\to\hook-2.mp4","C:\path\to\hook-3.mp4" `
  -Slug "animal-hooks" `
  -Name "animal-hooks-动物钩子" `
  -BaseDir ".\creative-materials" `
  -ProductBriefPath ".\my-product-brief.md"
```

`-ProductBriefPath` is optional. If omitted, fill the generated `product-brief-产品信息.md` before asking Codex to map the shared direction into your own product.

Then ask Codex:

```text
$zk-creative-process mix .\creative-materials\2026-05-23-animal-hooks-动物钩子
```

The output should be one direction-level folder, not three independent single-video folders.
