import { existsSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import type { AgentDomain, TriageResult } from '../types/index.js';
import type { AgentRunner } from './AgentRunner.js';

const KNOWN_DOMAINS: readonly AgentDomain[] = ['coder', 'unit-tester', 'doc-writer', 'devops'];

const TRIAGE_FALLBACK: TriageResult = {
  domains: ['coder'],
  reasoning: 'LLM call failed — fallback to coder',
  graphifyContext: undefined,
};

type GraphNode = {
  readonly id: string;
  readonly label: string;
  readonly source_file: string | undefined;
  readonly community: number | undefined;
};

type GraphLink = {
  readonly source: string;
  readonly target: string;
  readonly relation: string | undefined;
  readonly confidence: string | undefined;
};

type GraphData = {
  readonly nodes: readonly GraphNode[];
  readonly links: readonly GraphLink[];
};

export class TriageAgent {
  constructor(
    private readonly runner: AgentRunner,
    private readonly contextDir: string,
    private readonly projectRoot: string,
  ) {}

  async analyze(task: string): Promise<TriageResult> {
    try {
      const projectSnapshot = this.scanProject();
      const graphifyContext = this.readGraphifyContext(task);
      const prompt = this.buildPrompt(task, projectSnapshot, graphifyContext);

      const tmpDir = mkdtempSync(join(tmpdir(), 'triage-'));
      const promptFile = join(tmpDir, 'prompt.txt');

      let result;
      try {
        writeFileSync(promptFile, prompt, 'utf8');
        result = await this.runner.run('triage', promptFile);
      } finally {
        rmSync(tmpDir, { recursive: true, force: true });
      }

      if (!result.ok) {
        process.stderr.write(`[triage] LLM call failed: ${result.error}\n`);

        return TRIAGE_FALLBACK;
      }

      const triageResult = this.parseResponse(result.output, graphifyContext);

      try {
        this.writeTriageOutput(task, triageResult);
      } catch (writeErr) {
        process.stderr.write(`[triage] failed to write triage_ts.md: ${String(writeErr)}\n`);
      }

      return triageResult;
    } catch (err) {
      process.stderr.write(`[triage] unexpected error: ${String(err)}\n`);

      return TRIAGE_FALLBACK;
    }
  }

  private scanProject(): string {
    const checks: string[] = [];

    const checkExists = (relPath: string, label: string): void => {
      if (existsSync(join(this.projectRoot, relPath))) {
        checks.push(`- ${label}: YES (${relPath})`);
      } else {
        checks.push(`- ${label}: NO`);
      }
    };

    checkExists('src/agents', 'agents dir');
    checkExists('src/core', 'core dir');
    checkExists('src/types', 'types dir');
    checkExists('tests', 'tests dir');
    checkExists('test', 'test dir (alt)');
    checkExists('docs', 'docs dir');
    checkExists('.github/workflows', 'CI workflows');
    checkExists('graphify-out', 'graphify knowledge graph');

    return checks.join('\n');
  }

  private readGraphJson(): GraphData | undefined {
    const graphPath = join(this.projectRoot, 'graphify-out', 'graph.json');
    if (!existsSync(graphPath)) {
      return undefined;
    }
    try {
      const raw: unknown = JSON.parse(readFileSync(graphPath, 'utf8'));
      if (
        raw === null ||
        typeof raw !== 'object' ||
        !Array.isArray((raw as Record<string, unknown>)['nodes']) ||
        !Array.isArray((raw as Record<string, unknown>)['links'])
      ) {
        return undefined;
      }
      return raw as GraphData;
    } catch {
      return undefined;
    }
  }

  private readGraphifyContext(task: string): string | undefined {
    const graphifyDir = join(this.projectRoot, 'graphify-out');
    if (!existsSync(graphifyDir)) {
      return undefined;
    }

    const keywords = task
      .toLowerCase()
      .split(/\s+/)
      .filter(w => w.length > 3);

    if (keywords.length === 0) {
      return undefined;
    }

    const graph = this.readGraphJson();
    if (graph === undefined) {
      return undefined;
    }

    // Find seed nodes whose label matches any keyword
    const seedIds = new Set<string>();
    for (const node of graph.nodes) {
      const lower = node.label.toLowerCase();
      if (keywords.some(kw => lower.includes(kw))) {
        seedIds.add(node.id);
      }
    }

    if (seedIds.size === 0) {
      return undefined;
    }

    // Build adjacency map: id -> [{ id, relation }]
    const adjacency = new Map<string, Array<{ id: string; relation: string }>>();
    for (const link of graph.links) {
      const rel = link.relation ?? 'related';
      if (!adjacency.has(link.source)) adjacency.set(link.source, []);
      if (!adjacency.has(link.target)) adjacency.set(link.target, []);
      adjacency.get(link.source)!.push({ id: link.target, relation: rel });
      adjacency.get(link.target)!.push({ id: link.source, relation: rel });
    }

    // BFS depth=2 from seed nodes
    const visited = new Map<string, number>(); // id -> depth first seen
    const queue: Array<{ id: string; depth: number }> = [];
    for (const id of seedIds) {
      visited.set(id, 0);
      queue.push({ id, depth: 0 });
    }

    while (queue.length > 0) {
      const item = queue.shift();
      if (item === undefined) break;
      const { id, depth } = item;
      if (depth >= 2) continue;
      for (const neighbor of adjacency.get(id) ?? []) {
        if (!visited.has(neighbor.id)) {
          visited.set(neighbor.id, depth + 1);
          queue.push({ id: neighbor.id, depth: depth + 1 });
        }
      }
    }

    // Build node lookup
    const nodeById = new Map<string, GraphNode>();
    for (const node of graph.nodes) {
      nodeById.set(node.id, node);
    }

    // Format structured output
    const seedLabels = [...seedIds]
      .map(id => nodeById.get(id)?.label ?? id)
      .join(', ');

    const neighborLines: string[] = [];
    for (const [id, depth] of visited) {
      if (depth === 0) continue;
      const node = nodeById.get(id);
      if (node === undefined) continue;
      const link = graph.links.find(
        l =>
          (l.source === id || l.target === id) &&
          (visited.get(l.source === id ? l.target : l.source) ?? 99) < depth,
      );
      const rel = link?.relation ?? 'related';
      neighborLines.push(`- ${node.label} (via ${rel})`);
    }

    const lines: string[] = [
      `Affected nodes: ${seedLabels}`,
      'Connected to:',
      ...neighborLines,
    ];

    return lines.join('\n').slice(0, 1500);
  }

  private buildPrompt(
    task: string,
    projectSnapshot: string,
    graphifyContext: string | undefined,
  ): string {
    const parts: string[] = [
      '## Task to Triage',
      '',
      task,
      '',
      '## Project Structure',
      '',
      projectSnapshot,
    ];

    if (graphifyContext !== undefined) {
      parts.push('', '## Knowledge Graph Context (from graphify-out/)', '', graphifyContext);
    }

    parts.push(
      '',
      '## Instructions',
      '',
      'Read agents/triage-ts.md for the output format. Determine which agent domains this task requires.',
      'Think step by step: what does the task touch? Does it affect tests? Docs? CI?',
      'Output exactly the structured format described in triage-ts.md.',
    );

    return parts.join('\n');
  }

  private parseResponse(output: string, graphifyContext: string | undefined): TriageResult {
    const domainsMatch = output.match(/##\s+Domains\s*\n([\s\S]*?)(?=##|$)/i);
    const reasoningMatch = output.match(/##\s+Reasoning\s*\n([\s\S]*?)(?=##|$)/i);

    if (domainsMatch === null) {
      process.stderr.write('[triage] could not parse ## Domains section — fallback to coder\n');

      return {
        domains: ['coder'],
        reasoning: 'LLM output unparseable — fallback to coder',
        graphifyContext,
      };
    }

    const domainBlock = domainsMatch[1];
    if (domainBlock === undefined) {
      return { domains: ['coder'], reasoning: 'Empty domains block', graphifyContext };
    }

    const parsedDomains = domainBlock
      .split('\n')
      .map(line => line.replace(/^[-*]\s*/, '').trim())
      .filter(line => line.length > 0)
      .filter((line): line is AgentDomain => (KNOWN_DOMAINS as readonly string[]).includes(line));

    const domains: readonly AgentDomain[] = parsedDomains.length > 0 ? parsedDomains : ['coder'];

    const reasoningBlock = reasoningMatch?.[1]?.trim() ?? 'No reasoning provided';

    return { domains, reasoning: reasoningBlock, graphifyContext };
  }

  private writeTriageOutput(task: string, result: TriageResult): void {
    const lines: string[] = [
      '# Triage Result',
      '',
      '## Task',
      task,
      '',
      '## Domains',
      ...result.domains.map(d => `- ${d}`),
      '',
      '## Reasoning',
      result.reasoning,
    ];

    if (result.graphifyContext !== undefined) {
      lines.push('', '## Graphify Context Used', result.graphifyContext);
    }

    const outputFile = join(this.contextDir, 'triage_ts.md');
    writeFileSync(outputFile, lines.join('\n'), 'utf8');
  }
}

// CLI entry point: npx tsx src/agents/TriageAgent.ts "<task>"
const isMain = import.meta.url === `file://${process.argv[1]}`;
if (isMain) {
  const task = process.argv[2];
  if (!task) {
    process.stderr.write('Usage: npx tsx src/agents/TriageAgent.ts "<task description>"\n');
    process.exit(1);
  }

  const { AgentRunner } = await import('./AgentRunner.js');
  const { resolve } = await import('node:path');

  const projectRoot = process.cwd();
  const configPath = resolve(projectRoot, 'llm-config.json');
  const contextDir = resolve(projectRoot, '.claude/context');

  const runner = new AgentRunner(configPath);
  const agent = new TriageAgent(runner, contextDir, projectRoot);
  const result = await agent.analyze(task);

  process.stdout.write(`Domains: ${result.domains.join(', ')}\n`);
  process.stdout.write(`Written: .claude/context/triage_ts.md\n`);
}
