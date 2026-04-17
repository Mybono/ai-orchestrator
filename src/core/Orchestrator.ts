import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { AgentRunner } from '../agents/AgentRunner.js';
import { DependencyGraph } from './DependencyGraph.js';
import { CODE_GEN_INSTRUCTIONS, parseFileBlocks, writeFilesToProject } from './FileWriter.js';
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
  private readonly projectRoot: string;

  constructor(configPath: string, contextDir: string, projectRoot: string) {
    const resolvedConfig = resolve(configPath);
    this.contextDir = resolve(contextDir);
    this.projectRoot = resolve(projectRoot);

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
   * builds the dependency graph, executes in topological order,
   * writes generated files directly to the project, then reviews.
   */
  async run(domains: AgentDomain[]): Promise<AgentResult[]> {
    if (domains.length === 0) {
      process.stderr.write('[developer-agent] no domains provided\n');
      return [];
    }

    console.log(`[developer-agent] domains: ${domains.join(', ')}`);

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
        return { domain, dependencies: DOMAIN_DEPENDENCIES[domain], contextFile: domainContextFile };
      }

      if (existsSync(fallbackContextFile)) {
        process.stderr.write(
          `[developer-agent] task_context_${domain}.md not found — falling back to task_context.md\n`,
        );
        return { domain, dependencies: DOMAIN_DEPENDENCIES[domain], contextFile: fallbackContextFile };
      }

      process.stderr.write(
        `[developer-agent] warning: no context file for domain "${domain}" — skipping\n`,
      );
      return { domain, dependencies: DOMAIN_DEPENDENCIES[domain], contextFile: undefined };
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

    // Write the static code-gen instructions file once
    const instructionFile = join(this.contextDir, 'codegen_instructions.md');
    writeFileSync(instructionFile, CODE_GEN_INSTRUCTIONS, 'utf8');

    for (const level of levels) {
      console.log(`[developer-agent] executing: ${level.map(t => t.domain).join(', ')}`);

      const levelResults = await Promise.all(
        level.map(async (agentTask): Promise<AgentResult> => {
          const blockedBy = agentTask.dependencies.find(dep => failedDomains.has(dep));
          if (blockedBy !== undefined) {
            process.stderr.write(
              `[developer-agent] blocking ${agentTask.domain}: dependency "${blockedBy}" failed\n`,
            );
            failedDomains.add(agentTask.domain);
            return { domain: agentTask.domain, output: '', changedFiles: [], contextFile: agentTask.contextFile, status: 'blocked' };
          }

          if (agentTask.contextFile === undefined) {
            process.stderr.write(
              `[developer-agent] skipping ${agentTask.domain}: no context file\n`,
            );
            failedDomains.add(agentTask.domain);
            return { domain: agentTask.domain, output: '', changedFiles: [], contextFile: undefined, status: 'skipped' };
          }

          // instructionFile = prompt (format instructions)
          // contextFile     = task plan (fed as --context-file)
          const result = await this.runner.run('coder', instructionFile, agentTask.contextFile);

          if (!result.ok) {
            process.stderr.write(`[developer-agent] ${agentTask.domain} failed: ${result.error}\n`);
            failedDomains.add(agentTask.domain);
            return { domain: agentTask.domain, output: '', changedFiles: [], contextFile: agentTask.contextFile, status: 'failed' };
          }

          // Parse output and write files directly to the project
          const parsed = parseFileBlocks(result.output);

          if (parsed.length === 0) {
            process.stderr.write(
              `[developer-agent] ${agentTask.domain}: no %%FILE blocks found in output — saving raw output for inspection\n`,
            );
            this.writeRawOutput(agentTask.domain, result.output);
            failedDomains.add(agentTask.domain);
            return { domain: agentTask.domain, output: result.output, changedFiles: [], contextFile: agentTask.contextFile, status: 'failed' };
          }

          let changedFiles: string[];
          try {
            changedFiles = writeFilesToProject(parsed, this.projectRoot);
          } catch (err) {
            process.stderr.write(`[developer-agent] ${agentTask.domain} file write error: ${String(err)}\n`);
            failedDomains.add(agentTask.domain);
            return { domain: agentTask.domain, output: result.output, changedFiles: [], contextFile: agentTask.contextFile, status: 'failed' };
          }

          this.writeDeveloperOutput(agentTask.domain, changedFiles);
          console.log(`[developer-agent] ${agentTask.domain}: wrote ${changedFiles.length} file(s)`);

          return { domain: agentTask.domain, output: result.output, changedFiles, contextFile: agentTask.contextFile, status: 'done' };
        }),
      );

      allResults.push(...levelResults);
    }

    return allResults;
  }

  private writeDeveloperOutput(domain: AgentDomain, changedFiles: string[]): void {
    const outputPath = join(this.contextDir, `developer_output_${domain}.md`);
    const fileList = changedFiles.map(f => `- ${f}`).join('\n');
    const content = `## Domain\n${domain}\n\n## Changed Files\n${fileList}\n\n## Verdict\nDONE\n\n## Notes\n${changedFiles.length} file(s) written directly to project\n`;
    writeFileSync(outputPath, content, 'utf8');
    console.log(`[developer-agent] wrote summary: ${outputPath}`);
  }

  private writeRawOutput(domain: AgentDomain, output: string): void {
    const rawPath = join(this.contextDir, `developer_output_${domain}_raw.md`);
    writeFileSync(rawPath, output, 'utf8');
    process.stderr.write(`[developer-agent] raw output saved to: ${rawPath}\n`);
  }

  /**
   * Runs reviewer role for each completed domain's output summary.
   */
  private async review(results: AgentResult[]): Promise<void> {
    const errors: string[] = [];

    await Promise.all(
      results.map(async result => {
        if (result.status !== 'done') {
          process.stderr.write(
            `[developer-agent] review skipped for ${result.domain}: status=${result.status}\n`,
          );
          return;
        }

        const outputPath = join(this.contextDir, `developer_output_${result.domain}.md`);
        if (!existsSync(outputPath)) {
          process.stderr.write(
            `[developer-agent] review skipped for ${result.domain}: output file not found\n`,
          );
          return;
        }

        const reviewResult = await this.runner.run('reviewer', outputPath);
        if (!reviewResult.ok) {
          errors.push(`${result.domain}: ${reviewResult.error}`);
          process.stderr.write(
            `[developer-agent] review failed for ${result.domain}: ${reviewResult.error}\n`,
          );
        } else {
          console.log(`[developer-agent] reviewed ${result.domain}: ok`);
        }
      }),
    );

    if (errors.length > 0) {
      throw new Error(`[developer-agent] review failures:\n  ${errors.join('\n  ')}`);
    }
  }
}
