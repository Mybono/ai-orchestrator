export const KNOWN_ROLES = {
  coder:        'coder',
  unit_tester:  'unit-tester',
  doc_writer:   'doc-writer',
  devops:       'devops',
  reviewer:    'reviewer',
  triage:       'triage',
  commit:       'commit',
  pre_reviewer: 'pre-reviewer',
  planner:      'planner',
} as const;

// All role string values derived from the single source of truth above
export type Role = (typeof KNOWN_ROLES)[keyof typeof KNOWN_ROLES];

// Subset of keys that are pipeline domains (vs. internal roles like triage/commit)
const DOMAIN_KEYS = ['coder', 'unit_tester', 'doc_writer', 'devops', 'reviewer'] as const;
type DomainKey = (typeof DOMAIN_KEYS)[number];

export type AgentDomain = (typeof KNOWN_ROLES)[DomainKey];
export const KNOWN_DOMAINS = DOMAIN_KEYS.map(k => KNOWN_ROLES[k]) as readonly AgentDomain[];

export type AgentTask = {
  readonly domain: AgentDomain;
  readonly dependencies: readonly AgentDomain[];
  readonly contextFile: string | undefined;
};

export const status = {
  done: 'done',
  skipped: 'skipped',
  failed: 'failed',
  blocked: 'blocked',
} as const;
export type Status = (typeof status)[keyof typeof status];

export type AgentResult = {
  readonly domain: AgentDomain;
  readonly output: string;
  readonly contextFile: string | undefined;
  readonly changedFiles: readonly string[];
  readonly status: Status;
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

export type GoalStatus = 'pending' | 'running' | 'done' | 'failed';

export type Goal = {
  readonly id: string;
  readonly description: string;
  readonly domains?: readonly AgentDomain[];
  readonly projectRoot: string;
  status: GoalStatus;
  readonly createdAt: string;
  startedAt?: string;
  completedAt?: string;
  result?: string;
  error?: string;
  readonly parentId?: string;
  readonly dependsOn?: readonly string[];
};
