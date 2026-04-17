import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, join, normalize, resolve } from 'node:path';

export type ParsedFile = {
  readonly relativePath: string;
  readonly content: string;
};

/**
 * Matches blocks of the form:
 *   %%FILE path/to/file.ext
 *   ...content...
 *   %%ENDFILE
 *
 * The `m` flag makes ^ / $ match line boundaries so %%ENDFILE
 * is anchored to the start of its line.
 */
const FILE_BLOCK_RE = /^%%FILE ([^\n]+)\n([\s\S]*?)^%%ENDFILE/gm;

/**
 * Parse all %%FILE...%%ENDFILE blocks from an Ollama output string.
 * Returns an empty array if the model produced no file blocks.
 */
export function parseFileBlocks(output: string): ParsedFile[] {
  const results: ParsedFile[] = [];
  FILE_BLOCK_RE.lastIndex = 0;
  let match: RegExpExecArray | null;
  while ((match = FILE_BLOCK_RE.exec(output)) !== null) {
    const relativePath = (match[1] ?? '').trim();
    const content = match[2] ?? '';
    if (relativePath.length === 0) continue;
    results.push({ relativePath, content });
  }
  return results;
}

/**
 * Write parsed files to disk under projectRoot.
 * Throws if any path would escape projectRoot (path traversal guard).
 * Returns the list of relative paths that were written.
 */
export function writeFilesToProject(files: ParsedFile[], projectRoot: string): string[] {
  const resolvedRoot = resolve(projectRoot);
  const written: string[] = [];

  for (const file of files) {
    const absolutePath = join(resolvedRoot, normalize(file.relativePath));

    if (!absolutePath.startsWith(resolvedRoot + '/') && absolutePath !== resolvedRoot) {
      throw new Error(`FileWriter: path escapes project root: "${file.relativePath}"`);
    }

    mkdirSync(dirname(absolutePath), { recursive: true });
    writeFileSync(absolutePath, file.content, 'utf8');
    written.push(file.relativePath);
  }

  return written;
}

/**
 * Static prompt that instructs Ollama to output file blocks.
 * Passed as --prompt-file; the task plan is passed as --context-file.
 */
export const CODE_GEN_INSTRUCTIONS = `\
You are a code implementation agent. Implement the plan described in the context.

CRITICAL: Output ONLY file blocks using this exact format. No text outside the blocks.

%%FILE relative/path/to/file.ext
<complete file content here>
%%ENDFILE

Rules:
- Paths must be relative to the project root (e.g. src/foo.ts, not /absolute/path)
- Output the COMPLETE file content — not diffs, not partial snippets
- One %%FILE...%%ENDFILE block per file
- Do NOT wrap content in markdown code fences inside the blocks
- Do NOT output any explanation, preamble, or summary outside the blocks
`;
