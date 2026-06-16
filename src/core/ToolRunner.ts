import { existsSync, readdirSync, readFileSync, statSync, writeFileSync } from 'node:fs';
import { resolve, relative, join } from 'node:path';
import { spawnSync } from 'node:child_process';
import { randomUUID } from 'node:crypto';
import type { AgentDomain, Goal, GoalStatus } from '../types/index.js';

const MAX_FILE_BYTES = 60_000;
const MAX_SEARCH_RESULTS = 80;

export type ToolDefinition = {
  readonly type: 'function';
  readonly function: {
    readonly name: string;
    readonly description: string;
    readonly parameters: {
      readonly type: 'object';
      readonly properties: Record<string, { readonly type: string; readonly description: string }>;
      readonly required: readonly string[];
    };
  };
};

export type ToolCall = {
  readonly id: string;
  readonly type: 'function';
  readonly function: {
    readonly name: string;
    readonly arguments: string;
  };
};

export const PLANNER_TOOLS: readonly ToolDefinition[] = [
  {
    type: 'function',
    function: {
      name: 'read_file',
      description: 'Read the contents of a file. Path is relative to the project root.',
      parameters: {
        type: 'object',
        properties: {
          path: { type: 'string', description: 'File path relative to project root' },
        },
        required: ['path'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'list_dir',
      description: 'List files and directories at the given path (relative to project root).',
      parameters: {
        type: 'object',
        properties: {
          path: { type: 'string', description: 'Directory path relative to project root (use "." for root)' },
        },
        required: ['path'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'search_files',
      description: 'Search for a pattern in files under a directory (recursive grep).',
      parameters: {
        type: 'object',
        properties: {
          pattern: { type: 'string', description: 'Search pattern (grep regex)' },
          directory: { type: 'string', description: 'Directory to search in (relative to project root, default "src")' },
        },
        required: ['pattern'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'write_task_context',
      description: 'Write the completed task_context.md and signal that planning is done. Call this ONCE when the context file is complete.',
      parameters: {
        type: 'object',
        properties: {
          content: { type: 'string', description: 'Full content of task_context.md' },
        },
        required: ['content'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'decompose_goal',
      description: 'Decompose a goal into multiple sub-goals. Return an array of sub-goal descriptions that will be executed in sequence or parallel depending on dependencies.',
      parameters: {
        type: 'object',
        properties: {
          goal: { type: 'string', description: 'The goal description to decompose' },
        },
        required: ['goal'],
      },
    },
  },
];

export class ToolRunner {
  private readonly projectRoot: string;
  private readonly contextDir: string;
  private taskContextContent: string | undefined = undefined;

  constructor(projectRoot: string, contextDir: string) {
    this.projectRoot = resolve(projectRoot);
    this.contextDir = resolve(contextDir);
  }

  /** Execute a tool call and return the result as a string. */
  execute(call: ToolCall): string {
    let args: Record<string, unknown>;
    try {
      args = JSON.parse(call.function.arguments) as Record<string, unknown>;
    } catch {
      return `[error] invalid JSON arguments: ${call.function.arguments}`;
    }

    switch (call.function.name) {
      case 'read_file':
        return this.readFile(String(args['path'] ?? ''));
      case 'list_dir':
        return this.listDir(String(args['path'] ?? '.'));
      case 'search_files':
        return this.searchFiles(String(args['pattern'] ?? ''), String(args['directory'] ?? 'src'));
      case 'write_task_context':
        return this.writeTaskContext(String(args['content'] ?? ''));
      case 'decompose_goal':
        return this.decomposeGoal(args);
      default:
        return `[error] unknown tool: ${call.function.name}`;
    }
  }

  /** Returns the task_context content written by write_task_context, or undefined. */
  getTaskContext(): string | undefined {
    return this.taskContextContent;
  }

  private decomposeGoal(args: Record<string, unknown>): string {
    const goalDesc = String(args['goal'] ?? '');
    if (!goalDesc.trim()) {
      return JSON.stringify({ ok: false, error: 'goal description required' });
    }
    try {
      const now = new Date().toISOString();
      const baseGoal: Omit<Goal, 'id' | 'description'> = {
        projectRoot: this.projectRoot,
        status: 'pending' as GoalStatus,
        createdAt: now,
      };
      const lines = goalDesc
        .split('\n')
        .map(l => l.trim())
        .filter(Boolean);

      const subGoals: Goal[] = [];
      let previousId: string | undefined;
      for (const description of lines) {
        const id = randomUUID();
        const goal: Goal = {
          id,
          description,
          ...baseGoal,
          ...(previousId ? { dependsOn: [previousId] } : {}),
        };
        subGoals.push(goal);
        previousId = id;
      }

      return JSON.stringify({ ok: true, subGoals }, null, 2);
    } catch (err) {
      return JSON.stringify({ ok: false, error: err instanceof Error ? err.message : String(err) });
    }
  }

  private safe(relPath: string): string | null {
    if (relPath.trim() === '') return null;
    const abs = resolve(this.projectRoot, relPath);
    if (!abs.startsWith(this.projectRoot + '/') && abs !== this.projectRoot) return null;
    return abs;
  }

  private readFile(relPath: string): string {
    const abs = this.safe(relPath);
    if (abs === null) return `[error] path outside project root: ${relPath}`;
    if (!existsSync(abs)) return `[error] file not found: ${relPath}`;

    try {
      const stat = statSync(abs);
      if (stat.size > MAX_FILE_BYTES) {
        const content = readFileSync(abs, 'utf8');
        const truncated = content.slice(0, MAX_FILE_BYTES);
        return `${truncated}\n[truncated — file is ${stat.size} bytes, showing first ${MAX_FILE_BYTES}]`;
      }
      return readFileSync(abs, 'utf8');
    } catch (err) {
      return `[error] ${String(err)}`;
    }
  }

  private listDir(relPath: string): string {
    const abs = this.safe(relPath);
    if (abs === null) return `[error] path outside project root: ${relPath}`;
    if (!existsSync(abs)) return `[error] not found: ${relPath}`;

    try {
      const entries = readdirSync(abs, { withFileTypes: true });
      return entries
        .map(e => `${e.isDirectory() ? 'd' : 'f'} ${join(relPath, e.name)}`)
        .join('\n');
    } catch (err) {
      return `[error] ${String(err)}`;
    }
  }

  private searchFiles(pattern: string, directory: string): string {
    const abs = this.safe(directory);
    if (abs === null) return `[error] path outside project root: ${directory}`;

    const result = spawnSync(
      'grep',
      ['-r', '--include=*.ts', '--include=*.md', '-n', '-l', pattern, abs],
      { encoding: 'utf8', cwd: this.projectRoot },
    );

    const files = (result.stdout ?? '').trim().split('\n').filter(Boolean);
    if (files.length === 0) return `[no results for pattern: ${pattern}]`;

    const lines: string[] = [];
    for (const file of files.slice(0, MAX_SEARCH_RESULTS)) {
      const rel = relative(this.projectRoot, file);
      const grep = spawnSync('grep', ['-n', pattern, file], { encoding: 'utf8' });
      const matches = (grep.stdout ?? '').trim().split('\n').slice(0, 5).join('\n');
      lines.push(`${rel}:\n${matches}`);
    }

    return lines.join('\n\n');
  }

  private writeTaskContext(content: string): string {
    if (content.trim().length === 0) return '[error] content is empty';
    this.taskContextContent = content;
    try {
      writeFileSync(join(this.contextDir, 'task_context.md'), content, 'utf8');
      return 'task_context.md written successfully';
    } catch (err) {
      return `[error] write failed: ${String(err)}`;
    }
  }
}


