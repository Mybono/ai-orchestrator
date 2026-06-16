import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
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
 * Throws if generated content is suspiciously smaller than the existing file (stub guard).
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

    // Stub guard: if the existing file is substantially larger than the new output,
    // the model likely generated a stub instead of preserving existing code.
    if (existsSync(absolutePath)) {
      let existingContent: string | undefined;
      try {
        existingContent = readFileSync(absolutePath, 'utf8');
      } catch {
        // ignore read error — proceed with write
      }
      if (
        existingContent !== undefined &&
        existingContent.length > 300 &&
        file.content.length < existingContent.length * 0.6
      ) {
        const pct = Math.round((file.content.length / existingContent.length) * 100);
        throw new Error(
          `[stub-guard] ${file.relativePath}: generated ${file.content.length} chars but existing file has ${existingContent.length} chars (${pct}% < 60%). ` +
          `The model output is a stub — it must copy ALL existing code and only ADD new code.`,
        );
      }
    }

    mkdirSync(dirname(absolutePath), { recursive: true });
    writeFileSync(absolutePath, file.content, 'utf8');
    written.push(file.relativePath);
  }

  return written;
}

/**
 * Static prompt for code review tasks.
 * Instructs the LLM to analyze code and output a review report in %%FILE format.
 */
export const REVIEW_INSTRUCTIONS = `\
You are a senior code reviewer. Analyze the code provided in the context and produce a comprehensive review report.

CRITICAL: Output ONLY a single file block using this exact format. No text outside the block.

%%FILE review_report.md
# Code Review Report

## Executive Summary
<2-3 sentences summarizing overall code quality>

## Issues Found
<For each issue: file path, line range, severity (P0/P1/P2), description, and concrete fix suggestion>

## Positive Observations
<What is done well in the codebase>

## Recommendations
<Prioritized list of improvements>
%%ENDFILE

Rules:
- Reference ACTUAL files and line numbers from the code you received
- Do NOT invent files or issues that are not in the provided code
- Severity: P0=bug/security, P1=architecture/correctness, P2=style/maintainability
`;

/**
 * Static prompt that instructs Ollama to output file blocks.
 * Passed as --prompt-file; the task plan is passed as --context-file.
 */
export const CODE_GEN_INSTRUCTIONS = `\
You are a code implementation agent. Your job is to ADD new code to existing files.

CRITICAL: Output ONLY file blocks using this exact format. No text outside the blocks.

%%FILE relative/path/to/file.ext
<complete file content here>
%%ENDFILE

The context file contains a "## CURRENT FILE CONTENTS" section with the exact current state of
each file you must modify. You MUST follow this workflow for every file:

1. Copy the ENTIRE current file content into the %%FILE block verbatim
2. Add the new code described in the plan (new types, functions, methods) at the appropriate place
3. Your output MUST be longer than the current file — you are adding, not rewriting

Rules:
- NEVER remove, rename, or shorten any existing code — only ADD
- If a function or type already exists, keep it exactly as-is and add the new ones beside it
- Paths must be relative to the project root (e.g. src/foo.ts, not /absolute/path)
- Output the COMPLETE file content including all existing + all new code
- One %%FILE...%%ENDFILE block per file
- Do NOT wrap content in markdown code fences inside the blocks
- Do NOT output any explanation, preamble, or summary outside the blocks
`;
