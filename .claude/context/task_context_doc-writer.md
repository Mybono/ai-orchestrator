# Task Context

## Language
Markdown documentation files (e.g., `README.md`, any `.md` under `docs/`)

## Key Standards for This Task
- **Documentation Standards Skill** – all generated docs must follow the project’s documentation style (section headings, code fences, links, and table of contents).
- **Markdown linting** – no trailing spaces, proper heading hierarchy (`#`, `##`, `###`), and use of fenced code blocks with language identifiers.
- **PreToolUse hook** – updates must be written via the doc‑writer agent; direct edits to `README.md` or any `docs/` path are blocked by `settings.json`.

## Task
Update the project documentation (README and any existing docs) to reflect the current state and recent changes.

## Plan
- Run the doc‑writer agent to scan the repository, collect change information, and generate updated markdown content.
- Write the generated content back to the appropriate files (`README.md` and any `docs/*.md`), ensuring the files pass the markdown linting rules.

## Files to Change
- `README.md`: replace the existing content with a refreshed version that includes an updated project overview, usage examples, and a changelog summary.
- `docs/architecture.md` (if present): refresh the architecture diagram description to match any recent structural changes.

## Exact Signatures
*No new functions are added.* The doc‑writer agent invokes the existing CLI:

```bash
~/.claude/call_ollama.sh \
  --role doc-writer \
  --prompt-file plugins/documentation/commands/generate-readme.md \
  --context-dir .claude/context
```

The agent reads the generated output blocks (`%%FILE ... %%ENDFILE`) via `FileWriter.parseFileBlocks` and writes them to disk.

## Patterns to Follow
```ts
// src/core/FileWriter.ts – writing files from LLM blocks
export async function writeFilesToProject(
  projectRoot: string,
  fileBlocks: Record<string, string>,
): Promise<void> {
  for (const [relativePath, content] of Object.entries(fileBlocks)) {
    const absolutePath = resolve(projectRoot, relativePath);
    // guard against path traversal
    if (!absolutePath.startsWith(projectRoot)) continue;
    await writeFile(absolutePath, content, 'utf8');
  }
}
```

```md
<!-- Example of a generated markdown block -->
%%FILE README.md%%
# Project Title

...

%%ENDFILE%%
```

## Anti-patterns — Do NOT do this
- Edit `README.md` or files under `docs/` directly in a shell script; always go through the doc‑writer agent so the PreToolUse hook can approve the change.
- Insert raw HTML or non‑markdown elements that break the markdown linting rules.
- Omit the required `%%FILE … %%ENDFILE` markers; without them the `FileWriter` will not write the output.

## Edge Cases to Handle
- If a `docs/` directory does not exist, the agent should create it before writing any `%%FILE docs/…%%ENDFILE` blocks.
- When the repository already contains a `CHANGELOG.md`, the doc‑writer should prepend a concise “Latest updates” section rather than overwriting the whole file.
- Respect the project’s `.gitignore` – never generate documentation files that would match an ignored pattern (e.g., temporary build artifacts).
