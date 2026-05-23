# Creative Process Guide

## Philosophy

The workflow separates deterministic processing from creative judgment.

Scripts should handle:

- folder creation
- source video placement
- metadata extraction
- keyframe extraction
- contact sheet creation
- manifest generation
- skeleton markdown files

The AI should handle:

- scene understanding
- hook analysis
- structure transfer
- creative direction pools
- test hypotheses

## Folder Structure

```text
material-folder/
  original-name.mp4
  keyframes-reference-storyboard-contact-sheet-name.jpg
  brief.md
  product-brief-产品信息.md
  outputs/
    reference-video-storyboard-原视频场景变化分镜.md
    creative-script-directions-创意脚本方向.md
  _system-review-系统复查资料/
```

The root is for humans. `_system-review-系统复查资料/` is for automation and future AI review.

`product-brief-产品信息.md` is required for mapping the reference structure into the user's own product. If it is blank, the AI should deconstruct the reference video and ask for missing product context instead of inventing product facts.

## Single And Mix

Default to `single` unless the user explicitly says multiple videos belong to the same direction, same hook type, or same batch.

Use `mix` for same-direction batches. A mix folder should contain all source videos, one contact sheet per video, one shared `brief.md`, and one shared analysis file:

```text
outputs/shared-analysis-同方向素材共性拆解.md
```

## Product Mapping

Reference-video deconstruction and product mapping are different steps.

The product brief should cover:

- product category, audience, market, platform, and ad channel
- core gameplay loop and first 30 seconds of real experience
- mechanics that can truthfully bridge from hook to gameplay
- available assets, production limits, and compliance limits
- creative test goal and success metric

If these fields are missing, keep product mapping pending and output the missing questions.

## First Stage Only

The first stage should not create production storyboards or prompts. It should create a story-direction pool that a human can choose from.

Only after a direction is selected should an AI create production scripts, storyboard prompts, or asset-generation folders.
