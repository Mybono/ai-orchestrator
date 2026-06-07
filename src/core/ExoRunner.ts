import { existsSync, readFileSync } from 'node:fs';
import { homedir } from 'node:os';
import { join, resolve } from 'node:path';
import type { ExoGateway, Role, RunResult } from '../types/index.js';

const DEFAULT_TIMEOUT_MS = 5 * 60 * 1000;

/**
 * Inference runner backed by Exo's OpenAI-compatible HTTP API.
 * Accepts the `exo` section of ClusterConfig: { model, gateway }.
 * Implements the same run() interface as AgentRunner and DistributedRunner.
 */
export class ExoRunner {
  private readonly config: { readonly model: string; readonly gateway: ExoGateway };
  private readonly timeoutMs: number;
  private readonly projectRoot: string;

  constructor(
    config: { readonly model: string; readonly gateway: ExoGateway },
    projectRoot: string,
    timeoutMs = DEFAULT_TIMEOUT_MS,
  ) {
    this.config = config;
    this.projectRoot = resolve(projectRoot);
    this.timeoutMs = timeoutMs;
  }

  /**
   * Calls Exo's /v1/chat/completions endpoint.
   * System prompt is read from ~/.claude/agents/{role}.md or {projectRoot}/agents/{role}.md.
   * User prompt is the contents of promptFile; contextFile is appended if provided.
   * Returns RunResult — never throws.
   */
  async run(role: Role, promptFile: string, contextFile?: string): Promise<RunResult> {
    if (!existsSync(promptFile)) {
      return { ok: false, error: `prompt file not found: ${promptFile}` };
    }

    if (contextFile !== undefined && !existsSync(contextFile)) {
      return { ok: false, error: `context file not found: ${contextFile}` };
    }

    const systemPrompt = this.readSystemPrompt(role);
    if (systemPrompt === null) {
      return { ok: false, error: `system prompt not found for role: ${role}` };
    }

    let userContent: string;
    try {
      userContent = readFileSync(promptFile, 'utf8');
    } catch (err) {
      return { ok: false, error: `failed to read prompt file: ${String(err)}` };
    }

    if (contextFile !== undefined) {
      try {
        const ctx = readFileSync(contextFile, 'utf8');
        userContent = `${userContent}\n\n---\n\n${ctx}`;
      } catch (err) {
        return { ok: false, error: `failed to read context file: ${String(err)}` };
      }
    }

    const url = `http://${this.config.gateway.host}:${this.config.gateway.port}/v1/chat/completions`;

    const body = JSON.stringify({
      model: this.config.model,
      messages: [
        { role: 'system', content: systemPrompt },
        { role: 'user', content: userContent },
      ],
    });

    const controller = new AbortController();
    const timer = setTimeout(() => {
      controller.abort();
    }, this.timeoutMs);

    let response: Response;
    try {
      response = await fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body,
        signal: controller.signal,
      });
    } catch (err) {
      clearTimeout(timer);
      const isDomError =
        typeof err === 'object' &&
        err !== null &&
        (err as { name?: unknown }).name === 'AbortError';
      const message = isDomError
        ? `timeout after ${this.timeoutMs / 1000}s`
        : err instanceof Error
          ? err.message
          : String(err);
      return { ok: false, error: `Exo unreachable: ${message}` };
    }

    clearTimeout(timer);

    if (!response.ok) {
      let bodyText = '';
      try {
        bodyText = await response.text();
      } catch {
        // best-effort — ignore read error on error body
      }
      return {
        ok: false,
        error: `Exo API error: ${response.status} ${response.statusText} — ${bodyText.slice(0, 200)}`,
      };
    }

    let json: unknown;
    try {
      json = await response.json();
    } catch (err) {
      return { ok: false, error: `Exo response parse error: ${String(err)}` };
    }

    const text = extractContent(json);
    if (text === null) {
      return { ok: false, error: 'Exo response missing choices[0].message.content' };
    }

    return { ok: true, output: text.trim() };
  }

  /**
   * Resolves the system prompt markdown for the given role.
   * Search order: ~/.claude/agents/{role}.md then {projectRoot}/agents/{role}.md.
   * Returns null if neither path exists or both fail to read.
   */
  private readSystemPrompt(role: Role): string | null {
    const globalPath = join(homedir(), '.claude', 'agents', `${role}.md`);
    if (existsSync(globalPath)) {
      try {
        return readFileSync(globalPath, 'utf8');
      } catch {
        // fall through to local path
      }
    }

    const localPath = join(this.projectRoot, 'agents', `${role}.md`);
    if (existsSync(localPath)) {
      try {
        return readFileSync(localPath, 'utf8');
      } catch {
        return null;
      }
    }

    return null;
  }
}

/**
 * Extracts the text content from an OpenAI-compatible chat completion response.
 * Returns null if the expected shape is absent — caller returns an error RunResult.
 */
function extractContent(json: unknown): string | null {
  if (typeof json !== 'object' || json === null) return null;
  const choices = (json as Record<string, unknown>)['choices'];
  if (!Array.isArray(choices) || choices.length === 0) return null;
  const first = choices[0];
  if (typeof first !== 'object' || first === null) return null;
  const message = (first as Record<string, unknown>)['message'];
  if (typeof message !== 'object' || message === null) return null;
  const content = (message as Record<string, unknown>)['content'];
  if (typeof content !== 'string') return null;
  return content;
}
