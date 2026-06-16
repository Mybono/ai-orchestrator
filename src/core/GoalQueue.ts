import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { randomUUID } from 'node:crypto';
import type { AgentDomain, Goal, GoalStatus } from '../types/index.js';

type Result = { ok: boolean; error?: string };

export class GoalQueue {
  private readonly queueFile: string;

  constructor(projectRoot: string) {
    const dir = join(projectRoot, '.claude');
    mkdirSync(dir, { recursive: true });
    this.queueFile = join(dir, 'goals.json');
  }

  push(description: string, domains?: readonly AgentDomain[]): Goal {
    const goals = this.readAll();
    const base = {
      id: randomUUID(),
      description,
      projectRoot: process.cwd(),
      status: 'pending' as GoalStatus,
      createdAt: new Date().toISOString(),
    };
    const goal: Goal = domains !== undefined ? { ...base, domains } : base;
    goals.push(goal);
    this.writeAll(goals);
    return goal;
  }

  list(): Goal[] {
    return this.readAll();
  }

  nextPending(): Goal | undefined {
    return this.readAll().find(g => g.status === 'pending');
  }

  /** Mark a pending goal as running. Returns the updated goal or undefined if not claimable. */
  claim(id: string): Goal | undefined {
    const goals = this.readAll();
    const goal = goals.find(g => g.id === id);
    if (goal === undefined || goal.status !== 'pending') return undefined;
    goal.status = 'running';
    goal.startedAt = new Date().toISOString();
    this.writeAll(goals);
    return goal;
  }

  complete(id: string, result: string): void {
    this.patch(id, { status: 'done', completedAt: new Date().toISOString(), result });
  }

  fail(id: string, error: string): void {
    this.patch(id, { status: 'failed', completedAt: new Date().toISOString(), error });
  }

  /** Reset any goals stuck in 'running' (e.g. from a crashed process) back to 'pending'. */
  resetStale(): number {
    const goals = this.readAll();
    let count = 0;
    for (const goal of goals) {
      if (goal.status === 'running') {
        goal.status = 'pending';
        count++;
      }
    }
    if (count > 0) this.writeAll(goals);
    return count;
  }

  pushMany(goals: readonly Goal[]): Result {
    for (const g of goals) {
      const res = this.push(g.description, g.domains);
      if (!res.ok) return { ok: false, error: `failed to push goal ${g.id}: ${res.error}` };
    }
    return { ok: true };
  }

  nextReady(): Goal | null {
    const goals = this.readAll();
    for (const goal of goals) {
      if (goal.status !== 'pending') continue;
      if (goal.dependsOn && goal.dependsOn.some(dep => !this.isCompleted(dep, goals))) {
        continue;
      }
      return goal;
    }
    return null;
  }

  private patch(id: string, patch: Partial<Goal>): void {
    const goals = this.readAll();
    const idx = goals.findIndex(g => g.id === id);
    const goal = goals[idx];
    if (goal === undefined) return;
    Object.assign(goal, patch);
    this.writeAll(goals);
  }

  private readAll(): Goal[] {
    if (!existsSync(this.queueFile)) return [];
    try {
      const raw = readFileSync(this.queueFile, 'utf8');
      const parsed: unknown = JSON.parse(raw);
      return Array.isArray(parsed) ? (parsed as Goal[]) : [];
    } catch {
      return [];
    }
  }

  private writeAll(goals: Goal[]): void {
    writeFileSync(this.queueFile, JSON.stringify(goals, null, 2) + '\n', 'utf8');
  }

  private isCompleted(id: string, goals: Goal[]): boolean {
    const goal = goals.find(g => g.id === id);
    return goal !== undefined && goal.status === 'done';
  }
}
