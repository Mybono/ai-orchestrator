import { execSync } from 'node:child_process';
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { AgentRunner } from '../agents/AgentRunner.js';
import { loadClusterConfig } from './ExoConfigLoader.js';
import { ExoRunner } from './ExoRunner.js';
import { DistributedRunner } from './DistributedRunner.js';
import { DependencyGraph } from './DependencyGraph.js';
import { compressDiff } from './DiffCompressor.js';
import { CODE_GEN_INSTRUCTIONS, parseFileBlocks, writeFilesToProject } from './FileWriter.js';
import type {
  AgentDomain,
  AgentResult,
  AgentTask,
  OrchestratorResult,
  ReviewOutcome,
  Role,
} from '../types/index.js';

const DOMAIN_DEPENDENCIES: Record<AgentDomain, readonly AgentDomain[]> = {
  coder: [],
  'unit-tester': ['coder'],
  'doc-writer': ['coder'],
  devops: ['coder', 'unit-tester', 'doc-writer'],
};

export class Orchestrator {
  private readonly runner: AgentRunner | ExoRunner | DistributedRunner;
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

    const clusterConfig = loadClusterConfig(this.projectRoot);
    if (clusterConfig !== null) {
      if (clusterConfig.combined) {
        process.stderr.write(
          `[orchestrator] Exo backend active (combined) — gateway: ${clusterConfig.exo.gateway.host}:${clusterConfig.exo.gateway.port}, model: ${clusterConfig.exo.model}\n`,
        );
        this.runner = new ExoRunner(clusterConfig.exo, this.projectRoot);
      } else {
        process.stderr.write(
          `[orchestrator] distributed backend active — ${clusterConfig.nodes.length} node(s)\n`,
        );
        this.runner = new DistributedRunner(clusterConfig, this.projectRoot);
      }
    } else {
      this.runner = new AgentRunner();
    }
  }

  /**
   * Reads pre-written task_context_<domain>.md files from contextDir,
   * builds the dependency graph, executes in topological order,
   * writes generated files directly to the project, then reviews.
   */
  async run(domains: AgentDomain[]): Promise<OrchestratorResult> {
    if (domains.length === 0) {
      process.stderr.write('[developer-agent] no domains provided\n');
      return { agentResults: [], reviewOutcome: { passed: true } };
    }

    console.log(`[developer-agent] domains: ${domains.join(', ')}`);

    const tasks = this.buildTasks(domains);
    const agentResults = await this.execute(tasks);
    const reviewOutcome = await this.review(agentResults);

    return { agentResults, reviewOutcome };
  }

  private buildTasks(domains: AgentDomain[]): AgentTask[] {
    const activeDomainSet = new Set(domains);

    return domains.map(domain => {
      const domainContextFile = join(this.contextDir, `task_context_${domain}.md`);
      const fallbackContextFile = join(this.contextDir, 'task_context.md');

      // Prune dependency list to only include domains in the requested set.
      // This makes isolation explicit: DependencyGraph never sees edges to absent nodes.
      const prunedDeps = DOMAIN_DEPENDENCIES[domain].filter(dep => activeDomainSet.has(dep));

      if (existsSync(domainContextFile)) {
        return { domain, dependencies: prunedDeps, contextFile: domainContextFile };
      }

      if (existsSync(fallbackContextFile)) {
        process.stderr.write(
          `[developer-agent] task_context_${domain}.md not found — falling back to task_context.md\n`,
        );
        return { domain, dependencies: prunedDeps, contextFile: fallbackContextFile };
      }

      process.stderr.write(
        `[developer-agent] warning: no context file for domain "${domain}" — skipping\n`,
      );
      return { domain, dependencies: prunedDeps, contextFile: undefined };
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
          // DistributedRunner routes by role name — pass the domain so node lookup works.
          // AgentRunner and ExoRunner always use 'coder' (role maps to model in llm-config).
          const runRole: Role =
            this.runner instanceof DistributedRunner ? (agentTask.domain as Role) : 'coder';
          const result = await this.runner.run(runRole, instructionFile, agentTask.contextFile);

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
   * Fetches the git diff for the given changed files relative to HEAD.
   * Returns an empty string if git is unavailable, the list is empty,
   * or any other error occurs.
   */
  private getGitDiff(changedFiles: readonly string[]): string {
    if (changedFiles.length === 0) return '';
    try {
      const fileArgs = changedFiles.map(f => `"${f}"`).join(' ');
      return execSync(`git diff HEAD -- ${fileArgs}`, {
        cwd: this.projectRoot,
        encoding: 'utf8',
        stdio: ['pipe', 'pipe', 'pipe'],
      });
    } catch (err) {
      process.stderr.write(`[developer-agent] could not fetch git diff: ${String(err)}\n`);
      return '';
    }
  }

  /**
   * Runs reviewer for each completed domain.
   * Returns ReviewOutcome instead of throwing — the caller decides how to
   * handle review failures separately from build failures or internal errors.
   */
  private async review(results: AgentResult[]): Promise<ReviewOutcome> {
    const failedDomains: AgentDomain[] = [];

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

        // Fetch and compress the git diff for the changed files
        const rawDiff = this.getGitDiff(result.changedFiles);
        let reviewPromptPath = outputPath;

        if (rawDiff.length > 0) {
          const { compressed, ratio } = compressDiff(rawDiff);
          console.log(
            `[developer-agent] diff compressed for ${result.domain}: ratio=${ratio.toFixed(2)}`,
          );
          const summary = readFileSync(outputPath, 'utf8');
          const diffSection = `\n\n## Git Diff (compressed)\n\`\`\`diff\n${compressed}\n\`\`\`\n`;
          reviewPromptPath = join(this.contextDir, `review_prompt_${result.domain}.md`);
          writeFileSync(reviewPromptPath, summary + diffSection, 'utf8');
        }

        const reviewResult = await this.runner.run('reviewer', reviewPromptPath);
        if (!reviewResult.ok) {
          failedDomains.push(result.domain);
          process.stderr.write(
            `[developer-agent] review failed for ${result.domain}: ${reviewResult.error}\n`,
          );
        } else {
          console.log(`[developer-agent] reviewed ${result.domain}: ok`);
        }
      }),
    );

    return failedDomains.length > 0
      ? { passed: false, failedDomains }
      : { passed: true };
  }

  /**
   * Detects conflicting verdicts between two review outputs and logs to conflict_log.md.
   * Returns true if a conflict was found.
   */
  detectConflict(verdictA: string, agentA: string, verdictB: string, agentB: string): boolean {
    const CONFLICT_PAIRS: ReadonlyArray<readonly [string, string]> = [
      ['BLOCKED', 'APPROVED'],
      ['BLOCKED', 'DONE'],
      ['NEEDS CHANGES', 'APPROVED'],
    ];

    const upper = (v: string): string => v.toUpperCase().trim();
    const uA = upper(verdictA);
    const uB = upper(verdictB);

    const isConflict = CONFLICT_PAIRS.some(
      ([x, y]) => (uA === x && uB === y) || (uA === y && uB === x),
    );

    if (isConflict) {
      const ts = new Date().toISOString();
      const entry = [
        `\n## Conflict [${ts}]`,
        `- Agent A: ${agentA} — ${verdictA}`,
        `- Agent B: ${agentB} — ${verdictB}`,
        `- Resolution round result: pending`,
        `- Final verdict: escalated to user`,
      ].join('\n');

      const logPath = join(this.contextDir, 'conflict_log.md');
      const existing = existsSync(logPath) ? readFileSync(logPath, 'utf8') : '# Conflict Log\n';
      writeFileSync(logPath, existing + entry + '\n', 'utf8');

      process.stderr.write(
        `[error-coordinator] conflict detected: ${agentA}=${verdictA} vs ${agentB}=${verdictB}\n`,
      );
    }

    return isConflict;
  }
}
