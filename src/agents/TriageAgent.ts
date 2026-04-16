import { existsSync, mkdtempSync, readdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
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

    let jsonFiles: string[];
    try {
      jsonFiles = readdirSync(graphifyDir).filter(f => f.endsWith('.json'));
    } catch {
      return undefined;
    }

    const matches: string[] = [];

    for (const file of jsonFiles) {
      const filePath = join(graphifyDir, file);
      let content: string;
      try {
        content = readFileSync(filePath, 'utf8');
      } catch {
        continue;
      }

      const lower = content.toLowerCase();
      const hasMatch = keywords.some(kw => lower.includes(kw));

      if (hasMatch) {
        matches.push(`### ${file}\n${content.slice(0, 500)}`);
      }
    }

    if (matches.length === 0) {
      return undefined;
    }

    return matches.join('\n\n');
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
