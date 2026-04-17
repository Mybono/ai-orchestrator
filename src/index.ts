import { resolve } from 'node:path';
import { Orchestrator } from './core/Orchestrator.js';
import type { AgentDomain } from './types/index.js';

const KNOWN_DOMAINS: readonly AgentDomain[] = ['coder', 'unit-tester', 'doc-writer', 'devops'];
const DEFAULT_CONFIG = resolve('llm-config.json');
const DEFAULT_CONTEXT_DIR = resolve('.claude/context');

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

  const orchestrator = new Orchestrator(DEFAULT_CONFIG, DEFAULT_CONTEXT_DIR);
  const results = await orchestrator.run(domains);

  console.log(`\n[orchestrator] completed ${results.length} agent(s)`);

  for (const result of results) {
    console.log(`  ${result.domain}: ${result.contextFile}`);
  }
}

main().catch((err: unknown) => {
  process.stderr.write(`[orchestrator] fatal: ${String(err)}\n`);
  process.exit(1);
});
