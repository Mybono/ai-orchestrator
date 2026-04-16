export type AgentDomain = 'coder' | 'unit-tester' | 'doc-writer' | 'devops';

export type AgentTask = {
  readonly domain: AgentDomain;
  readonly dependencies: readonly AgentDomain[];
  readonly contextFile: string;
};

export type AgentResult = {
  readonly domain: AgentDomain;
  readonly output: string;
  readonly contextFile: string;
};

export type RunResult = { ok: true; output: string } | { ok: false; error: string };

export type OrchestratorConfig = {
  readonly configPath: string;
  readonly contextDir: string;
};

export type LlmConfig = {
  readonly models: Record<string, string>;
};

export type TriageResult = {
  readonly domains: readonly AgentDomain[];
  readonly reasoning: string;
  readonly graphifyContext: string | undefined;
};
