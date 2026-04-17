import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
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

    mkdirSync(this.contextDir, { recursive: true });
    this.runner = new AgentRunner();
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
        `[orchestrator] warning: neither task_context_${domain}.md nor task_context.md found — skipping domain\n`,
      );

      return {
        domain,
        dependencies: DOMAIN_DEPENDENCIES[domain],
        contextFile: undefined,
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
    const failedDomains = new Set<AgentDomain>();

    for (const level of levels) {
      console.log(`[orchestrator] executing: ${level.map(t => t.domain).join(', ')}`);

      const levelResults = await Promise.all(
        level.map(async (agentTask): Promise<AgentResult> => {
          const blockedBy = agentTask.dependencies.find(dep => failedDomains.has(dep));
          if (blockedBy !== undefined) {
            process.stderr.write(
              `[orchestrator] blocking ${agentTask.domain}: dependency "${blockedBy}" failed\n`,
            );
            failedDomains.add(agentTask.domain);

            return { domain: agentTask.domain, output: '', contextFile: agentTask.contextFile, status: 'blocked' };
          }

          if (agentTask.contextFile === undefined) {
            process.stderr.write(
              `[orchestrator] skipping ${agentTask.domain}: no context file found\n`,
            );
            failedDomains.add(agentTask.domain);

            return { domain: agentTask.domain, output: '', contextFile: undefined, status: 'skipped' };
          }

          const result = await this.runner.run(agentTask.domain, agentTask.contextFile);

          if (!result.ok) {
            process.stderr.write(`[orchestrator] ${agentTask.domain} failed: ${result.error}\n`);
            failedDomains.add(agentTask.domain);

            return { domain: agentTask.domain, output: '', contextFile: agentTask.contextFile, status: 'failed' };
          }

          this.writeOutputFile(agentTask.domain, result.output);

          return { domain: agentTask.domain, output: result.output, contextFile: agentTask.contextFile, status: 'done' };
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
    const errors: string[] = [];

    await Promise.all(
      results.map(async result => {
        if (result.status !== 'done') {
          process.stderr.write(
            `[orchestrator] review skipped for ${result.domain}: status=${result.status}\n`,
          );

          return;
        }

        const outputPath = join(this.contextDir, `ollama_output_${result.domain}.md`);
        if (!existsSync(outputPath)) {
          process.stderr.write(
            `[orchestrator] review skipped for ${result.domain}: output file not found\n`,
          );

          return;
        }

        const reviewResult = await this.runner.run('reviewer', outputPath);
        if (!reviewResult.ok) {
          errors.push(`${result.domain}: ${reviewResult.error}`);
          process.stderr.write(
            `[orchestrator] review failed for ${result.domain}: ${reviewResult.error}\n`,
          );
        } else {
          console.log(`[orchestrator] reviewed ${result.domain}: ok`);
        }
      }),
    );

    if (errors.length > 0) {
      throw new Error(`[orchestrator] review failures:\n  ${errors.join('\n  ')}`);
    }
  }
}
