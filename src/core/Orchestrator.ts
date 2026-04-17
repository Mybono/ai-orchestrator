import { existsSync, readFileSync, writeFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { AgentRunner } from '../agents/AgentRunner.js';
import { DependencyGraph } from './DependencyGraph.js';
import type { AgentDomain, AgentResult, AgentTask } from '../types/index.js';

const DOMAIN_DEPENDENCIES: Record<AgentDomain, readonly AgentDomain[]> = {
  coder: [],
  'unit-tester': ['coder'],
  'doc-writer': ['coder'],
  devops: ['coder', 'unit-tester', 'doc-writer'],
};

export class Orchestrator {
  private readonly runner: AgentRunner;
  private readonly contextDir: string;

  constructor(configPath: string, contextDir: string) {
    const resolvedConfig = resolve(configPath);
    this.contextDir = resolve(contextDir);

    try {
      readFileSync(resolvedConfig, 'utf8');
    } catch {
      throw new Error(`Orchestrator: configPath not found: ${resolvedConfig}`);
    }

    this.runner = new AgentRunner(resolvedConfig);
  }

  /**
   * Reads pre-written task_context_<domain>.md files from contextDir,
   * builds the dependency graph, executes in topological order, then reviews.
   */
  async run(domains: AgentDomain[]): Promise<AgentResult[]> {
    if (domains.length === 0) {
      process.stderr.write('[orchestrator] no domains provided\n');

      return [];
    }

    console.log(`[orchestrator] domains: ${domains.join(', ')}`);

    const tasks = this.buildTasks(domains);
    const results = await this.execute(tasks);
    await this.review(results);

    return results;
  }

  private buildTasks(domains: AgentDomain[]): AgentTask[] {
    return domains.map(domain => {
      const domainContextFile = join(this.contextDir, `task_context_${domain}.md`);
      const fallbackContextFile = join(this.contextDir, 'task_context.md');

      if (existsSync(domainContextFile)) {
        return {
          domain,
          dependencies: DOMAIN_DEPENDENCIES[domain],
          contextFile: domainContextFile,
        };
      }

      if (existsSync(fallbackContextFile)) {
        process.stderr.write(
          `[orchestrator] task_context_${domain}.md not found — falling back to task_context.md\n`,
        );

        return {
          domain,
          dependencies: DOMAIN_DEPENDENCIES[domain],
          contextFile: fallbackContextFile,
        };
      }

      process.stderr.write(
        `[orchestrator] warning: neither task_context_${domain}.md nor task_context.md found — proceeding with empty context\n`,
      );

      return {
        domain,
        dependencies: DOMAIN_DEPENDENCIES[domain],
        contextFile: '',
      };
    });
  }

  /**
   * Executes tasks level by level (dependency order).
   * Within each level, tasks run concurrently.
   */
  private async execute(tasks: AgentTask[]): Promise<AgentResult[]> {
    const graph = new DependencyGraph(tasks);
    const levels = graph.getLevels();
    const allResults: AgentResult[] = [];

    for (const level of levels) {
      console.log(`[orchestrator] executing: ${level.map(t => t.domain).join(', ')}`);

      const levelResults = await Promise.all(
        level.map(async (agentTask): Promise<AgentResult> => {
          const result = await this.runner.run(agentTask.domain, agentTask.contextFile);
          const output = result.ok ? result.output : `ERROR: ${result.error}`;

          this.writeOutputFile(agentTask.domain, output);

          return {
            domain: agentTask.domain,
            output,
            contextFile: agentTask.contextFile,
          };
        }),
      );

      allResults.push(...levelResults);
    }

    return allResults;
  }

  private writeOutputFile(domain: AgentDomain, output: string): void {
    const outputPath = join(this.contextDir, `ollama_output_${domain}.md`);
    writeFileSync(outputPath, output, 'utf8');
    console.log(`[orchestrator] wrote output: ${outputPath}`);
  }

  /**
   * Runs reviewer role for each result's context file concurrently.
   */
  private async review(results: AgentResult[]): Promise<void> {
    await Promise.all(
      results.map(async result => {
        const reviewResult = await this.runner.run('reviewer', result.contextFile);
        if (!reviewResult.ok) {
          process.stderr.write(
            `[orchestrator] review failed for ${result.domain}: ${reviewResult.error}\n`,
          );
        } else {
          console.log(`[orchestrator] reviewed ${result.domain}: ok`);
        }
      }),
    );
  }
}
