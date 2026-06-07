As a Documentation Writer, my role is to create or update project documentation based on the context provided to me. Here's how I will approach this task:

### Phase 1 — Read the standards
I will read the project documentation standards from `~/.claude/skills/doc-standarts.md`.

### Phase 2 — Gather context
To gather the context for creating the CLUSTER documentation, I will proceed as follows:

* Mode A - Update docs after code changes (git diff): I'll determine if there are any relevant changes in the project that need to be documented by running `git diff HEAD`. If no changes are found, I'll try running `git diff` instead.
* Mode B - Improve or restructure an existing file: Since we didn't ask for updating an existing doc, I won't gather context from any specific file. However, I will still look for related files nearby by using the following command: `find . -name "*.md" -not -path "*/node_modules/*" -not -path "*/.git/*" | head -20`.
* Mode C - Restore content from a previous version: Not applicable in this case, as we are creating new documentation.
* Mode D - Write new documentation (explicit task): I will create the CLUSTER documentation based on the provided explicit task and context gathered from source files or existing docs if necessary.

### Phase 3 — Draft with Ollama
I'll build a focused prompt into a temporary file, call Ollama to generate the draft, and apply changes accordingly:
```bash
TMP_PROMPT=$(mktemp)
cat <<'EOF' > "$TMP_PROMPT"
You are a technical writer who writes like a human, not an AI. Your task is described below.

## Writing Style (Mandatory)
$(cat ~/.claude/skills/humanizer.md)

## Documentation standards
$(cat ~/.claude/skills/doc-standarts.md)

## Context
$(git diff HEAD > context.txt && cat context.txt || cat <context-file-or-inline-content>)

## Task
You are required to write a detailed documentation for the Cluster Mode feature. This document should include an overview table, sections on exo-config.json, various modes (distributed and combined), setup steps, ram planning, and source files.
EOF

bash ~/.claude/call_ollama.sh --role reviewer --prompt-file "$TMP_PROMPT"
rm -f "$TMP_PROMPT"
```
If Ollama is not running, start it first:
```bash
ollama serve > /dev/null 2>&1 &
sleep 3
```
### Phase 4 — Apply changes and report done
After reviews, I will verify every function name, parameter, and example matches the actual source. Then, I'll signal to the hook that doc-writer is active, apply changes, clean up, and finally report which files were updated or created.