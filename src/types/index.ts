export type AgentDomain = 'coder' | 'unit-tester' | 'doc-writer' | 'devops';

export const KNOWN_DOMAINS: readonly AgentDomain[] = [
  'coder',
  'unit-tester',
  'doc-writer',
  'devops',
];

export type Role = AgentDomain | 'reviewer' | 'triage' | 'commit' | 'pre-reviewer';

export type AgentTask = {
  readonly domain: AgentDomain;
  readonly dependencies: readonly AgentDomain[];
  readonly contextFile: string | undefined;
};

export type AgentResult = {
  readonly domain: AgentDomain;
  readonly output: string;
  readonly contextFile: string | undefined;
  readonly changedFiles: readonly string[];
  readonly status: 'done' | 'skipped' | 'failed' | 'blocked';
};

export type RunResult = { ok: true; output: string } | { ok: false; error: string };

export type OrchestratorConfig = {
  readonly configPath: string;
  readonly contextDir: string;
};

export type LlmConfig = {
  readonly models: Record<string, string>;
};

export type TriageRoute =
  | 'direct-edit'
  | 'quick-coder'
  | 'plugin-route'
  | 'full-pipeline'
  | 'architect-first';

export type TriageResult = {
  readonly domains: readonly AgentDomain[];
  readonly reasoning: string;
  readonly graphifyContext: string | undefined;
  readonly route: TriageRoute | undefined;
  readonly triggerReason: string | undefined;
};

export type ReviewOutcome =
  | { readonly passed: true }
  | { readonly passed: false; readonly failedDomains: readonly AgentDomain[] };

export type OrchestratorResult = {
  readonly agentResults: readonly AgentResult[];
  readonly reviewOutcome: ReviewOutcome;
};

export type ExoGateway = {
  readonly host: string;
  readonly port: number;
};

export type ClusterNode = {
  readonly name: string;
  readonly host: string;
  readonly port: number;
  readonly roles: Readonly<Record<string, string>>;
};

export type ClusterConfig = {
  readonly combined: boolean;
  readonly exo: { readonly model: string; readonly gateway: ExoGateway };
  readonly nodes: readonly ClusterNode[];
};
