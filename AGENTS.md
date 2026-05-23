# AGENTS.md

## Scope

This repository packages the `zk-creative-process` Codex skill and its PowerShell helper scripts.

## Structure

- `skills/zk-creative-process/`: the installable, self-contained Codex skill.
- `skills/zk-creative-process/scripts/`: scripts bundled with the skill for direct use after copying the skill folder.
- `scripts/`: repository-level copies and wrappers for development, testing, and installer entry points.
- `docs/`: troubleshooting and longer usage notes.
- `examples/`: lightweight examples only; no private creative materials.

## Rules

- Keep the install path friendly for non-programmers: one installer command, clear next step, no silent destructive behavior.
- Default file handling must copy source videos. Moving originals requires an explicit `-Move` flag.
- Do not commit source videos, generated `creative-materials/`, private ad data, or strategy notes.
- Keep `README.md` as the entry guide. Put longer explanations in `docs/`.
- Validate PowerShell syntax after script changes.
