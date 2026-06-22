# 008 — Rename project to Velxon

## Problem

The project is named `ai-orchestrator` — a generic, descriptive slug that doesn't work as a product name. As the system matures into a fully autonomous agent it needs a unique, brandable identity. The chosen name is **Velxon**.

## Goal

Rename every occurrence of `ai-orchestrator` / `AI Orchestrator` / `ai_orchestrator` to `velxon` / `Velxon` / `velxon` across the entire codebase, configs, scripts, and documentation. After this ticket is done, no user-facing surface should show the old name.

## Scope

### 1. Repository & directory
- [ ] Rename GitHub repo: `ai-orchestrator` → `velxon`
- [ ] Rename local directory: `/Users/user/Projects/ai-orchestrator` → `/Users/user/Projects/velxon`
- [ ] Update git remote URL after repo rename

### 2. `package.json`
- [ ] `"name": "ai-orchestrator"` → `"velxon"`
- [ ] `"description"` — replace product name
- [ ] `"bin"` keys: `"ai-orchestrator"` → `"velxon"`, `"ai-orchestrator-ts"` → `"velxon-ts"`

### 3. Scripts (`scripts/`)
- [ ] `install.sh` — references to `ai-orchestrator` CLI name
- [ ] `check-update.sh` — package name check
- [ ] `stats.sh` — display name

### 4. Documentation (`*.md`)
Files containing `ai-orchestrator` or `AI Orchestrator`:
- [ ] `README.md`
- [ ] `CHANGELOG.md`
- [ ] `CONTRIBUTING.md`
- [ ] `CODE_OF_CONDUCT.md`
- [ ] `SECURITY.md`
- [ ] `documentation/CLAUDE.md`
- [ ] `documentation/SKILLS.md`
- [ ] `documentation/BITBUCKET_INTEGRATION.md`
- [ ] `plugins/documentation/commands/generate-readme.md`
- [ ] `plugins/orchestrator/commands/stats.md`
- [ ] `commands/update-orchestrator.md`
- [ ] `.github/ISSUE_TEMPLATE/bug_report.md`
- [ ] `.github/ISSUE_TEMPLATE/feature_request.md`
- [ ] `agents/commit.md`

### 5. Config files
- [ ] `mcp-config.json` — any path or name references
- [ ] `.claude/settings.json` — path references
- [ ] `.claude/settings.local.json` — path references
- [ ] `.claude/context/review_capture_trigger.md`
- [ ] `.claude/context/review_prompt_devops.md`

### 6. Global CLAUDE.md (`~/.claude/CLAUDE.md`)
- [ ] Update working directory reference from `ai-orchestrator` to `velxon`
- [ ] Update memory path reference

### 7. Claude memory
- [ ] Memory is stored at `~/.claude/projects/-Users-user-Projects-ai-orchestrator/`
- [ ] After directory rename, Claude will auto-create a new memory dir at `-Users-user-Projects-velxon/`
- [ ] Manually copy memory files to new path OR symlink old path → new path

### 8. SVG / visual assets
- [ ] `ai_orchestrator_pipeline.svg` — rename file, update any title text inside

## Acceptance criteria

- `grep -r "ai-orchestrator" . --include="*.md" --include="*.json" --include="*.sh" --include="*.ts" | grep -v node_modules | grep -v CHANGELOG` returns 0 results
- `velxon --help` works after reinstall (`npm install -g .`)
- README title shows **Velxon**
- GitHub repo URL resolves to `github.com/<org>/velxon`

## Suggested execution order

1. Rename GitHub repo (UI)
2. Rename local directory + update git remote
3. `sed` pass over all listed files
4. Update `package.json` manually (bin keys, name, description)
5. Rename SVG asset
6. Copy Claude memory files
7. Run acceptance grep

## Files touched

- `package.json`
- `scripts/install.sh`, `check-update.sh`, `stats.sh`
- All `.md` files listed above
- `mcp-config.json`
- `.claude/settings.json`, `.claude/settings.local.json`
- `~/.claude/CLAUDE.md`
- `ai_orchestrator_pipeline.svg`
