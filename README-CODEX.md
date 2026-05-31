# Skills for Copilot Studio in Codex

Codex-compatible mirror of [microsoft/skills-for-copilot-studio](https://github.com/microsoft/skills-for-copilot-studio).

This repository keeps the upstream plugin content and regenerates Codex metadata with
`tools/convert-copilot-studio-for-codex.ps1`. Keep upstream documentation in `README.md`; use this
file for Codex-specific installation and maintenance notes.

## What This Adds

- `.codex-plugin/plugin.json`
- Codex-compatible `name` / `description` frontmatter in every `skills/*/SKILL.md`
- path rewrites for Claude-specific `${CLAUDE_SKILL_DIR}` references
- a scheduled GitHub Actions workflow that merges upstream and reapplies the Codex conversion

## Manual Refresh

```powershell
git remote add upstream https://github.com/microsoft/skills-for-copilot-studio.git
git fetch upstream main
git merge upstream/main
pwsh ./tools/convert-copilot-studio-for-codex.ps1 -PluginRoot .
git add .
git commit -m "Sync upstream for Codex"
git push
```

The scheduled workflow `.github/workflows/sync-upstream-for-codex.yml` runs the same process daily.
If upstream changes conflict with local Codex conversion files, fix the merge manually and rerun the
conversion script before committing.

## Local Codex Testing

Clone this repository to your plugin directory and add a personal marketplace entry that points to
the local clone. The converter can also write the default local marketplace entry:

```powershell
pwsh ./tools/convert-copilot-studio-for-codex.ps1 -PluginRoot . -WriteMarketplace
codex plugin add copilot-studio@personal
```

After installing or updating the plugin, start a new Codex thread so the refreshed skills are loaded.
