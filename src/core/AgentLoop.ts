import { existsSync, mkdirSync, readFileSync } from 'node:fs';
import { homedir } from 'node:os';
import { join, resolve } from 'node:path';
import { GoalQueue } from './GoalQueue.js';
import { Orchestrator } from './Orchestrator.js';
import { runBuildCheck } from './BuildChecker.js';
import { PlannerSession } from './PlannerSession.js';
import { TriageAgent } from '../agents/TriageAgent.js';
import { AgentRunner } from '../agents/AgentRunner.js';
import { KNOWN_DOMAINS } from '../types/index.js';
import type { AgentDomain, Goal } from '../types/index.js';

const DEFAULT_POLL_MS = 10_000;
const DEFAULT_CONFIG = 'llm-config.json';

function sleep(ms: number): Promise<void> {
  return new Promise(r => setTimeout(r, ms));
}

export class AgentLoop {
  private readonly queue: GoalQueue;
  private readonly runner: AgentRunner;
  private readonly projectRoot: string;
  private readonly contextDir: string;
  private readonly agentsDir: string;
  private readonly pollMs: number;
  private active = false;

  constructor(projectRoot: string, pollMs = DEFAULT_POLL_MS) {
    this.projectRoot = resolve(projectRoot);
    this.contextDir = join(this.projectRoot, '.claude/context');
    this.agentsDir = join(this.projectRoot, 'agents');
    this.pollMs = pollMs;
    this.queue = new GoalQueue(this.projectRoot);
    this.runner = new AgentRunner();
    mkdirSync(this.contextDir, { recursive: true });
  }

  start(): void {
    const stale = this.queue.resetStale();
    if (stale > 0) {
      process.stderr.write(`[agent-loop] reset ${stale} stale goal(s) to pending\n`);
    }

    this.active = true;
    process.on('SIGINT', () => { this.active = false; });
    process.on('SIGTERM', () => { this.active = false; });

    process.stderr.write(
      `[agent-loop] started — polling every ${this.pollMs / 1000}s (Ctrl+C to stop)\n`,
    );

    void this.loop();
  }

  private async loop(): Promise<void> {
    while (this.active) {
      const goal = this.queue.nextReady();
      if (goal !== null) {
        const claimed = this.queue.claim(goal.id);
        if (claimed !== undefined) {
          await this.processGoal(claimed);
        }
      } else {
        process.stderr.write('[agent-loop] no ready goals — waiting\n');
        await sleep(this.pollMs);
      }
    }
    process.stderr.write('[agent-loop] stopped\n');
  }

  private async processGoal(goal: Goal): Promise<void> {
    process.stderr.write(`[agent-loop] goal ${goal.id.slice(0, 8)}: ${goal.description}\n`);

    try {
      // Step 1: triage — determine which domains this task touches
      const domains = await this.resolveDomains(goal);
      if (domains.length === 0) {
        this.queue.fail(goal.id, 'triage returned no valid domains');
        return;
      }
      process.stderr.write(`[agent-loop] domains: ${domains.join(', ')}\n`);

      // Step 2: planner — build rich task_context.md (same as /implement flow)
      const planOk = await this.runPlanner(goal.description, domains);
      if (!planOk) {
        this.queue.fail(goal.id, 'planner failed to produce task_context.md');
        return;
      }

      // Step 3: build check before code generation
      const buildResult = await runBuildCheck(this.projectRoot);
      if (!buildResult.passed) {
        this.queue.fail(goal.id, `build check failed:\n${buildResult.stderr}`);
        return;
      }

      // Step 4: coder + reviewer (standard orchestrator pipeline)
      const configPath = join(this.projectRoot, DEFAULT_CONFIG);
      const orchestrator = new Orchestrator(configPath, this.contextDir, this.projectRoot);
      const { agentResults, reviewOutcome } = await orchestrator.run(domains);

      const summary = agentResults
        .map(r => `${r.domain}[${r.status}]: ${r.changedFiles.join(', ') || '(no files)'}`)
        .join('\n');

      if (reviewOutcome.passed) {
        this.queue.complete(goal.id, summary);
        process.stderr.write(`[agent-loop] goal ${goal.id.slice(0, 8)} — done\n`);
      } else {
        const failed = reviewOutcome.failedDomains.join(', ');
        this.queue.fail(goal.id, `review failed for: ${failed}\n${summary}`);
        process.stderr.write(`[agent-loop] goal ${goal.id.slice(0, 8)} — review failed\n`);
      }
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      this.queue.fail(goal.id, msg);
      process.stderr.write(`[agent-loop] goal ${goal.id.slice(0, 8)} error: ${msg}\n`);
    }
  }

  /**
   * Runs the planner as a real agent loop with tool access.
   * The planner reads files, greps the codebase, and calls write_task_context when done.
   * This replicates the /implement flow planner step.
   */
  private async runPlanner(description: string, domains: AgentDomain[]): Promise<boolean> {
    process.stderr.write('[agent-loop] running planner (tool-access mode)\n');

    const systemPrompt = this.readPlannerSystemPrompt();
    if (systemPrompt === null) {
      process.stderr.write('[agent-loop] planner system prompt not found (agents/planner.md)\n');
      return false;
    }

    const userMessage = [
      '## Task',
      description,
      '',
      '## Target Domains',
      domains.map(d => `- ${d}`).join('\n'),
      '',
      'Read the codebase, understand the task, then call write_task_context with the completed task_context.md.',
    ].join('\n');

    const session = new PlannerSession(this.projectRoot, this.contextDir, systemPrompt);
    const result = await session.run(userMessage);

    if (!result.ok) {
      process.stderr.write(`[agent-loop] planner failed: ${result.error}\n`);
      return false;
    }

    process.stderr.write('[agent-loop] planner wrote task_context.md\n');
    return true;
  }

  private readPlannerSystemPrompt(): string | null {
    const paths = [
      join(this.agentsDir, 'planner.md'),
      join(homedir(), '.claude', 'agents', 'planner.md'),
    ];
    for (const p of paths) {
      if (!existsSync(p)) continue;
      try { return readFileSync(p, 'utf8'); } catch { /* try next */ }
    }
    return null;
  }

  private async resolveDomains(goal: Goal): Promise<AgentDomain[]> {
    if (goal.domains !== undefined && goal.domains.length > 0) {
      return goal.domains.filter(
        (d): d is AgentDomain => (KNOWN_DOMAINS as readonly string[]).includes(d),
      );
    }

    const agent = new TriageAgent(this.runner, this.contextDir, this.projectRoot);
    const result = await agent.analyze(goal.description);
    return [...result.domains];
  }
}


