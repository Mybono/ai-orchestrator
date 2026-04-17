import { resolve } from 'node:path';
import { Orchestrator } from './core/Orchestrator.js';
import { KNOWN_DOMAINS } from './types/index.js';
import type { AgentDomain } from './types/index.js';
const DEFAULT_CONFIG = resolve('llm-config.json');
const DEFAULT_CONTEXT_DIR = resolve('.claude/context');
const DEFAULT_PROJECT_ROOT = process.cwd();

async function main(): Promise<void> {
  const arg = process.argv[2];

  if (arg === undefined || arg.trim() === '') {
    process.stderr.write('Usage: tsx src/index.ts "coder,unit-tester,doc-writer"\n');
    process.exit(1);
  }

  const domains = arg
    .split(',')
    .map(s => s.trim())
    .filter((s): s is AgentDomain => (KNOWN_DOMAINS as readonly string[]).includes(s));

  if (domains.length === 0) {
    process.stderr.write(`[orchestrator] no valid domains in: "${arg}"\n`);
    process.stderr.write(`Valid domains: ${[...KNOWN_DOMAINS].join(', ')}\n`);
    process.exit(1);
  }

  const orchestrator = new Orchestrator(DEFAULT_CONFIG, DEFAULT_CONTEXT_DIR, DEFAULT_PROJECT_ROOT);
  const results = await orchestrator.run(domains);

  console.log(`\n[developer-agent] completed ${results.length} domain(s)`);

  for (const result of results) {
    const files = result.changedFiles.length > 0
      ? result.changedFiles.join(', ')
      : '(no files written)';
    console.log(`  ${result.domain} [${result.status}]: ${files}`);
  }
}

main().catch((err: unknown) => {
  process.stderr.write(`[orchestrator] fatal: ${String(err)}\n`);
  process.exit(1);
});
