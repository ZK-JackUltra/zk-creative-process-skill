---
name: zk-creative-process
description: >
  Generic creative material processing for game ad reference videos. Use when
  the user invokes $zk-creative-process, single, or mix to process new
  reference videos, generate keyframe contact sheets, create material folders,
  create product-brief-产品信息.md, analyze game-ad hooks, map reference
  structures into the user's own product, or build story-direction pools.
  Supports single for one reference video and mix for multiple same-direction
  videos analyzed in one folder.
---

# ZK Creative Process

Use this skill to process game-ad reference videos into clean, reviewable creative-analysis folders.

Command modes:

- `single`: one reference video, one material folder.
- `mix`: multiple same-direction reference videos, one direction-level material folder.

Both modes are code-first. Use the bundled scripts before AI writing. Prefer this skill directory's `scripts/` folder. If working inside the cloned repository, the root `scripts/` folder is equivalent. Keep human-facing files in the material root and automation files in `_system-review-系统复查资料/`.

## Routing

Use `single` when the user gives one new reference video or does not explicitly say the videos belong to one shared direction.

Use `mix` when the user says multiple videos are one direction, one hook type, one batch, or should be analyzed together.

If ambiguous, default to `single`.

## Hard Rules

- Run code setup before writing analysis.
- Copy source videos by default. Use `-Move` only when the user explicitly asks to move originals.
- Keep original videos and keyframe contact sheets in the material root.
- Keep product context in `product-brief-产品信息.md`.
- Put metadata, frame index, manifest, and AI input pack in `_system-review-系统复查资料/`.
- Use product information for product mapping. If product information is missing or still contains TODO, do not invent product facts; list missing questions and mark product mapping as pending.
- First produce a story-direction pool. Do not create production storyboard, prompt, or `script-*` folders until the user selects a specific direction.
- Separate selection from completion: selection records a chosen direction; completion archives and cleans final production assets.
- Keep outputs human-readable: conclusion and priority first, details second.

## single Workflow

Run from the repository root, or from the installed skill's `scripts/` folder:

```powershell
.\scripts\process-reference-video-phase1.ps1 `
  -VideoPath "C:\path\to\reference.mp4" `
  -Slug "short-slug" `
  -Name "english-name-中文说明" `
  -BaseDir ".\creative-materials" `
  -ProductBriefPath ".\my-product-brief.md"
```

`-ProductBriefPath` is optional. If omitted, the script creates a blank `product-brief-产品信息.md` template.

Then read:

- `_system-review-系统复查资料/ai-input-pack.md`
- `_system-review-系统复查资料/frame-index.json`
- `_system-review-系统复查资料/video_metadata.json`
- `keyframes-reference-storyboard-contact-sheet-*.jpg`
- `product-brief-产品信息.md`

Fill:

- `brief.md`
- `outputs/reference-video-storyboard-原视频场景变化分镜.md`
- `outputs/creative-script-directions-创意脚本方向.md`

## mix Workflow

For multiple same-direction videos, create one direction folder, not multiple single folders:

```powershell
.\scripts\process-reference-videos-mix.ps1 `
  -VideoPaths "C:\path\to\video-1.mp4","C:\path\to\video-2.mp4" `
  -Slug "shared-direction" `
  -Name "shared-direction-同方向说明" `
  -BaseDir ".\creative-materials" `
  -ProductBriefPath ".\my-product-brief.md"
```

The `brief.md` should list all videos, their shared theme, differences, transferable structure, and unified test goal.

Fill:

- `brief.md`
- `product-brief-产品信息.md`
- `outputs/shared-analysis-同方向素材共性拆解.md`

## Product Mapping Requirements

Before turning a reference structure into scripts for the user's product, check `product-brief-产品信息.md`.

Required product context:

- game/product category, audience, market, platform, and ad channel
- core gameplay loop and first real user experience
- mechanics that can truthfully bridge from the hook into gameplay
- available visual assets and production constraints
- must-show, must-avoid, compliance limits, and success metric

If these are missing, output a concise missing-information checklist. Keep the reference-video deconstruction useful, but do not claim the product mapping is complete.

## Output Requirements

For both modes, analyze:

- scene progression
- opening hook
- conflict and pressure
- visual language and edit rhythm
- BGM, SFX, voice, and captions when available
- transferable structure versus surface style
- bridge into actual gameplay or product value

Each story direction should include:

- core hypothesis
- hook
- story premise
- conflict and trigger mechanism
- product bridge
- product mapping fit and missing product information
- scalable variants
- metrics to test
- risks
- human decision questions

## Completion Checks

Before responding:

- Confirm mode used: `single` or `mix`.
- Confirm code setup ran before AI writing.
- Confirm material folder path.
- Confirm `_system-review-系统复查资料/` contains metadata, frame index, manifest, and AI input pack.
- Confirm root contains reference video, keyframe sheet, brief, product brief, and outputs.
- Confirm whether product mapping is complete or pending due to missing product information.
- Confirm no production folder was created before a direction was selected.
