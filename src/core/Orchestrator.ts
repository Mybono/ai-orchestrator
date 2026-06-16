import { spawnSync } from 'node:child_process';
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { AgentRunner } from '../agents/AgentRunner.js';
import { loadClusterConfig } from './ExoConfigLoader.js';
import { ExoRunner } from './ExoRunner.js';
import { DistributedRunner } from './DistributedRunner.js';
import { DependencyGraph } from './DependencyGraph.js';
import { compressDiff } from './DiffCompressor.js';
import { CODE_GEN_INSTRUCTIONS, REVIEW_INSTRUCTIONS, parseFileBlocks, writeFilesToProject } from './FileWriter.js';
import { KNOWN_ROLES } from '../types/index.js';
import type {
  AgentDomain,
  AgentResult,
  AgentTask,
  OrchestratorResult,
  ReviewOutcome,
  Role,
} from '../types/index.js';

const { coder, unit_tester, doc_writer, devops, reviewer } = KNOWN_ROLES;

const DOMAIN_DEPENDENCIES: Record<AgentDomain, readonly AgentDomain[]> = {
  [coder]:       [],
  [unit_tester]: [coder],
  [doc_writer]:  [coder],
  [devops]:      [coder, unit_tester, doc_writer],
  [reviewer]:    [],
};

const NEEDS_CHANGES_RE = /NEEDS[\s_]CHANGES/i;

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

  async run(domains: AgentDomain[]): Promise<OrchestratorResult> {
    if (domains.length === 0) {
      process.stderr.write('[developer-agent] no domains provided\n');
      return { agentResults: [], reviewOutcome: { passed: true } };
    }

    console.log(`[developer-agent] domains: ${domains.join(', ')}`);

    const tasks = this.buildTasks(domains);
    let agentResults = await this.execute(tasks);
    const reviewOutcome = await this.review(agentResults);

    if (!reviewOutcome.passed) {
      const failedDomains = reviewOutcome.failedDomains;
      process.stderr.write(
        `[developer-agent] fix round: re-running ${[...failedDomains].join(', ')}\n`,
      );

      for (const domain of failedDomains) {
        const failedResult = agentResults.find(r => r.domain === domain);
        this.appendReviewFeedback(domain, failedResult?.contextFile);
      }

      const fixTasks = this.buildTasks([...failedDomains]);
      const fixResults = await this.execute(fixTasks);

      const fixResultMap = new Map(fixResults.map(r => [r.domain, r]));
      agentResults = agentResults.map(r =>
        fixResultMap.has(r.domain) ? (fixResultMap.get(r.domain) as AgentResult) : r,
      );

      const fixReviewOutcome = await this.review(fixResults);
      return { agentResults, reviewOutcome: fixReviewOutcome };
    }

    return { agentResults, reviewOutcome };
  }

  private buildTasks(domains: AgentDomain[]): AgentTask[] {
    const activeDomainSet = new Set(domains);

    return domains.map(domain => {
      const domainContextFile = join(this.contextDir, `task_context_${domain}.md`);
      const fallbackContextFile = join(this.contextDir, 'task_context.md');

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

  private async execute(tasks: AgentTask[]): Promise<AgentResult[]> {
    const graph = new DependencyGraph(tasks);
    const levels = graph.getLevels();
    const allResults: AgentResult[] = [];
    const failedDomains = new Set<AgentDomain>();

    const instructionFile = join(this.contextDir, 'codegen_instructions.md');
    writeFileSync(instructionFile, CODE_GEN_INSTRUCTIONS, 'utf8');
    const reviewInstructionFile = join(this.contextDir, 'review_instructions.md');
    writeFileSync(reviewInstructionFile, REVIEW_INSTRUCTIONS, 'utf8');

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

          const isReviewer = agentTask.domain === KNOWN_ROLES.reviewer;
          const promptFile = isReviewer ? reviewInstructionFile : instructionFile;
          const runRole: Role =
            this.runner instanceof DistributedRunner ? (agentTask.domain as Role) : (isReviewer ? KNOWN_ROLES.reviewer : KNOWN_ROLES.coder);

          // For coder tasks: augment context with current file contents so the model
          // knows what already exists and can ADD to it rather than rewrite from scratch.
          let effectiveContextFile = agentTask.contextFile;
          if (!isReviewer && agentTask.contextFile !== undefined) {
            const augmented = this.buildAugmentedContext(agentTask.contextFile);
            if (augmented !== undefined) {
              const augPath = join(this.contextDir, `task_context_augmented_${agentTask.domain}.md`);
              writeFileSync(augPath, augmented, 'utf8');
              effectiveContextFile = augPath;
              process.stderr.write(
                `[developer-agent] ${agentTask.domain}: context augmented with current file contents\n`,
              );
            }
          }

          const result = await this.runner.run(runRole, promptFile, effectiveContextFile);

          if (!result.ok) {
            process.stderr.write(`[developer-agent] ${agentTask.domain} failed: ${result.error}\n`);
            failedDomains.add(agentTask.domain);
            return { domain: agentTask.domain, output: '', changedFiles: [], contextFile: agentTask.contextFile, status: 'failed' };
          }

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

  private getGitDiff(changedFiles: readonly string[]): string {
    if (changedFiles.length === 0) return '';
    try {
      const result = spawnSync('git', ['diff', 'HEAD', '--', ...changedFiles], {
        cwd: this.projectRoot,
        encoding: 'utf8',
      });
      return result.stdout ?? '';
    } catch (err) {
      process.stderr.write(`[developer-agent] could not fetch git diff: ${String(err)}\n`);
      return '';
    }
  }

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

        const reviewResult = await this.runner.run(KNOWN_ROLES.reviewer, reviewPromptPath, result.contextFile);

        const savedOutput = reviewResult.ok ? reviewResult.output : '';
        const reviewOutputPath = join(this.contextDir, `review_output_${result.domain}.md`);
        writeFileSync(reviewOutputPath, savedOutput, 'utf8');

        if (!reviewResult.ok) {
          failedDomains.push(result.domain);
          process.stderr.write(
            `[developer-agent] review failed for ${result.domain}: ${reviewResult.error}\n`,
          );
        } else if (NEEDS_CHANGES_RE.test(reviewResult.output)) {
          failedDomains.push(result.domain);
          process.stderr.write(
            `[developer-agent] review for ${result.domain}: NEEDS CHANGES — queued for fix round\n`,
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

  private appendReviewFeedback(domain: AgentDomain, contextFile: string | undefined): void {
    if (contextFile === undefined) return;

    const reviewOutputPath = join(this.contextDir, `review_output_${domain}.md`);
    if (!existsSync(reviewOutputPath)) {
      process.stderr.write(
        `[developer-agent] no review output found for ${domain} — skipping feedback append\n`,
      );
      return;
    }

    let reviewOutput: string;
    try {
      reviewOutput = readFileSync(reviewOutputPath, 'utf8');
    } catch (err) {
      process.stderr.write(
        `[developer-agent] could not read review output for ${domain}: ${String(err)}\n`,
      );
      return;
    }

    const feedback =
      `\n\n---\n\n## Reviewer Feedback (Fix Round)\n\n${reviewOutput}\n\n` +
      `**Address all reviewer comments in your implementation.**\n`;

    try {
      const existing = readFileSync(contextFile, 'utf8');
      writeFileSync(contextFile, existing + feedback, 'utf8');
    } catch (err) {
      process.stderr.write(
        `[developer-agent] could not append feedback to ${contextFile}: ${String(err)}\n`,
      );
    }
  }

  /**
   * Builds an augmented version of the context file that includes the current on-disk content
   * of every file listed in "## Files to Change". This prevents the coder from generating
   * stub replacements — it sees the existing code and must ADD to it.
   */
  private buildAugmentedContext(contextFile: string): string | undefined {
    let context: string;
    try {
      context = readFileSync(contextFile, 'utf8');
    } catch {
      return undefined;
    }

    const paths = this.extractFilesToChange(context);
    if (paths.length === 0) return undefined;

    const sections: string[] = [];
    for (const relPath of paths) {
      const absPath = join(this.projectRoot, relPath);
      if (!existsSync(absPath)) continue;
      let content: string;
      try {
        content = readFileSync(absPath, 'utf8');
      } catch {
        continue;
      }
      sections.push(
        `### Current content of \`${relPath}\` (${content.length} chars — MUST be preserved)\n\`\`\`\n${content}\n\`\`\``,
      );
    }

    if (sections.length === 0) return undefined;

    const header = [
      '',
      '---',
      '',
      '## CURRENT FILE CONTENTS (READ-ONLY REFERENCE)',
      '',
      'IMPORTANT: The sections below contain the EXACT current content of each file you must modify.',
      'You MUST copy each file verbatim into your %%FILE output, then ADD the new code from the plan.',
      'Do NOT remove, rewrite, or shorten any existing code. Your output must be longer than each current file.',
      '',
    ].join('\n');

    return context + header + sections.join('\n\n');
  }

  /** Extracts file paths listed under the "## Files to Change" section of a task context. */
  private extractFilesToChange(context: string): string[] {
    const sectionMatch = /##\s+Files to Change([\s\S]*?)(?=\n##|\n---|\s*$)/.exec(context);
    if (sectionMatch === null) return [];

    const section = sectionMatch[1] ?? '';
    const paths: string[] = [];
    const re = /`([a-zA-Z0-9_./-]+\.[a-zA-Z0-9]+)`/g;
    let m: RegExpExecArray | null;
    while ((m = re.exec(section)) !== null) {
      const p = m[1];
      // Only relative paths that look like source file paths (contain a slash)
      if (p !== undefined && !p.startsWith('/') && p.includes('/')) {
        paths.push(p);
      }
    }
    return [...new Set(paths)];
  }

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
