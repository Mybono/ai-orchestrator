import type { AgentDomain, AgentTask } from '../types/index.js';

export class DependencyGraph {
  private readonly tasks: Map<AgentDomain, AgentTask> = new Map();

  constructor(tasks: AgentTask[]) {
    for (const task of tasks) {
      if (this.tasks.has(task.domain)) {
        throw new Error(`DependencyGraph: duplicate domain: "${task.domain}"`);
      }
      this.tasks.set(task.domain, task);
    }
  }

  /**
   * Kahn's algorithm topological sort.
   * Returns tasks grouped into parallel execution levels.
   * Level 0 has no dependencies. Level N depends on N-1.
   * Throws if a cycle is detected.
   */
  getLevels(): AgentTask[][] {
    const allTasks = Array.from(this.tasks.values());

    // domain -> count of unsatisfied dependencies
    const inDegree = new Map<AgentDomain, number>();
    // domain -> list of domains that depend on it
    const dependents = new Map<AgentDomain, AgentDomain[]>();

    for (const task of allTasks) {
      if (!inDegree.has(task.domain)) {
        inDegree.set(task.domain, 0);
      }
      if (!dependents.has(task.domain)) {
        dependents.set(task.domain, []);
      }
      for (const dep of task.dependencies) {
        inDegree.set(task.domain, (inDegree.get(task.domain) ?? 0) + 1);
        if (!dependents.has(dep)) {
          dependents.set(dep, []);
        }
        dependents.get(dep)!.push(task.domain);
      }
    }

    const levels: AgentTask[][] = [];
    let current = allTasks.filter(t => (inDegree.get(t.domain) ?? 0) === 0);

    while (current.length > 0) {
      levels.push(current);
      const next: AgentTask[] = [];

      for (const task of current) {
        for (const dependentDomain of dependents.get(task.domain) ?? []) {
          const remaining = (inDegree.get(dependentDomain) ?? 0) - 1;
          inDegree.set(dependentDomain, remaining);
          if (remaining === 0) {
            const found = this.tasks.get(dependentDomain);
            if (found !== undefined) {
              next.push(found);
            }
          }
        }
      }

      current = next;
    }

    const processed = levels.flat().length;
    if (processed < allTasks.length) {
      const unresolved = allTasks.filter(t => !levels.flat().includes(t)).map(t => t.domain);
      const missingDeps = unresolved.flatMap(domain => {
        const task = this.tasks.get(domain);

        return (task?.dependencies ?? [])
          .filter(dep => !this.tasks.has(dep))
          .map(dep => `"${dep}" required by "${domain}"`);
      });
      if (missingDeps.length > 0) {
        throw new Error(
          `DependencyGraph: missing dependencies in graph: ${missingDeps.join(', ')}`,
        );
      }
      throw new Error(`DependencyGraph: cycle detected among: ${unresolved.join(', ')}`);
    }

    return levels;
  }
}
