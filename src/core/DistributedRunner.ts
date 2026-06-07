import { existsSync, readFileSync } from 'node:fs';
import { homedir } from 'node:os';
import { join, resolve } from 'node:path';
import type { ClusterConfig, ClusterNode, Role, RunResult } from '../types/index.js';

const DEFAULT_TIMEOUT_MS = 5 * 60 * 1000;
const FALLBACK_HOST = 'localhost';
const FALLBACK_PORT = 11434;

/**
 * Inference runner that dispatches each role to the first matching cluster node.
 * Implements the same run() interface as AgentRunner and ExoRunner.
 * Falls back to localhost:11434 with the model from llm-config.json when no
 * node claims the requested role.
 */
export class DistributedRunner {
  private readonly config: ClusterConfig;
  private readonly timeoutMs: number;
  private readonly projectRoot: string;

  constructor(config: ClusterConfig, projectRoot: string, timeoutMs = DEFAULT_TIMEOUT_MS) {
    this.config = config;
    this.projectRoot = resolve(projectRoot);
    this.timeoutMs = timeoutMs;
  }

  /**
   * Routes the request to the first cluster node that lists `role` in its roles map.
   * Falls back to localhost:11434 + model from llm-config.json if no node matches.
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

    const resolved = this.resolveNode(role);
    if (resolved === null) {
      return {
        ok: false,
        error: `no node found for role "${role}" and llm-config.json fallback unavailable`,
      };
    }

    const { host, port, model } = resolved;

    process.stderr.write(
      `[distributed-runner] role="${role}" -> ${host}:${port} model="${model}"\n`,
    );

    const url = `http://${host}:${port}/v1/chat/completions`;

    const body = JSON.stringify({
      model,
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
      return { ok: false, error: `node ${host}:${port} unreachable: ${message}` };
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
        error: `node ${host}:${port} API error: ${response.status} ${response.statusText} — ${bodyText.slice(0, 200)}`,
      };
    }

    let json: unknown;
    try {
      json = await response.json();
    } catch (err) {
      return { ok: false, error: `node ${host}:${port} response parse error: ${String(err)}` };
    }

    const text = extractContent(json);
    if (text === null) {
      return {
        ok: false,
        error: `node ${host}:${port} response missing choices[0].message.content`,
      };
    }

    return { ok: true, output: text.trim() };
  }

  /**
   * Finds the first node whose roles map contains the given role.
   * Returns { host, port, model } or falls back to llm-config.json + localhost:11434.
   * Returns null only when no node matches AND the fallback is unavailable.
   */
  private resolveNode(role: Role): { host: string; port: number; model: string } | null {
    for (let i = 0; i < this.config.nodes.length; i++) {
      const node: ClusterNode | undefined = this.config.nodes[i];
      if (node === undefined) continue;
      const model = node.roles[role];
      if (model !== undefined) {
        return { host: node.host, port: node.port, model };
      }
    }

    // No node claimed this role — fall back to llm-config.json + localhost:11434
    const fallbackModel = this.readFallbackModel(role);
    if (fallbackModel === null) {
      process.stderr.write(
        `[distributed-runner] role "${role}" not found in any node and llm-config.json has no entry\n`,
      );
      return null;
    }

    process.stderr.write(
      `[distributed-runner] role "${role}" not in cluster — falling back to ${FALLBACK_HOST}:${FALLBACK_PORT} model="${fallbackModel}"\n`,
    );
    return { host: FALLBACK_HOST, port: FALLBACK_PORT, model: fallbackModel };
  }

  /**
   * Reads the model for a role from ~/.claude/llm-config.json.
   * Returns null if the file is absent, unreadable, or the role is not listed.
   */
  private readFallbackModel(role: Role): string | null {
    const configPath = join(homedir(), '.claude', 'llm-config.json');
    if (!existsSync(configPath)) return null;

    let raw: string;
    try {
      raw = readFileSync(configPath, 'utf8');
    } catch {
      return null;
    }

    let parsed: unknown;
    try {
      parsed = JSON.parse(raw);
    } catch {
      return null;
    }

    if (typeof parsed !== 'object' || parsed === null || Array.isArray(parsed)) return null;
    const models = (parsed as Record<string, unknown>)['models'];
    if (typeof models !== 'object' || models === null || Array.isArray(models)) return null;
    const model = (models as Record<string, unknown>)[role];
    if (typeof model !== 'string' || model.trim().length === 0) return null;
    return model.trim();
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
 * Returns null if the expected shape is absent.
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
