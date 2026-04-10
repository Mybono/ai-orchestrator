Analyze the task description and produce a routing decision before the pipeline starts.

Triage runs as **Step 0** of `/implement`. It writes `.claude/context/triage.md` so all downstream steps — planner, coder, reviewer — start with the right expertise pre-loaded.

## Step 0 — Load Project Overview

Before classifying complexity, check if `.claude/context/project_overview.md` exists:

```bash
ls .claude/context/project_overview.md 2>/dev/null
```

**If EXISTS** — read only `## Language(s)` and `## Architecture & Conventions` sections. Skip re-detecting language and project structure. Proceed directly to domain detection in Step 2.

**If MISSING** — proceed normally. Triage will detect language from indicator files as part of domain analysis.

## Step 1 — Classify Complexity

Read the task description and classify into one tier:

| Tier | Criteria | Default route |
|---|---|---|
| **nano** | Single line change, rename, import fix, constant update | `direct-edit` |
| **micro** | 1–3 files, no new abstractions, isolated change | `quick-coder` |
| **standard** | Feature, bug fix, multi-file change | `full-pipeline` or `plugin-route` |
| **complex** | Architecture change, new system, cross-cutting concern | `architect-first` |

## Step 2 — Detect Domain

Scan the task description for domain keywords. A task may match **multiple domains**.

| Domain | Keywords | Skills to load | Agents to load | Plugin command |
|---|---|---|---|---|
| `api` | api, endpoint, rest, graphql, route, openapi, swagger, http method, integration test | `skills/api-design-patterns/SKILL.md` | `agents/architect.md`, `agents/api-tester.md` | `plugins/api-architect/commands/design-api.md` |
| `docker` | docker, image, dockerfile, container, compose, registry | `skills/docker-best-practices/SKILL.md` | `agents/devops.md` | `plugins/docker-helper/commands/optimize-dockerfile.md` |
| `ci_cd` | ci/cd, github actions, workflow, k8s, kubernetes, helm, argocd, deploy, deployment | `skills/ci-cd-pipelines/SKILL.md`, `skills/kubernetes-operations/SKILL.md` | `agents/devops.md` | `plugins/k8s-helper/commands/generate-manifest.md` |
| `release` | release, version bump, semver, changelog, publish, tag, npm publish, pypi | `skills/git-advanced/SKILL.md` | `agents/devops.md` | `plugins/release-manager/commands/release.md` |
| `security` | security, auth, jwt, oauth, vulnerability, owasp, injection, xss, csrf, secrets | `skills/security-hardening/SKILL.md`, `skills/authentication-patterns/SKILL.md` | `agents/security-auditor.md`, `agents/reviewer.md` | `plugins/security-guidance/commands/security-check.md` |
| `database` | schema, sql, query, migration, erd, database, postgres, mysql, mongo, index | `skills/microservices-design/SKILL.md` | `agents/architect.md` | `plugins/database-tools/commands/design-schema.md` |
| `testing` | test, unit test, e2e, playwright, coverage, mock, fixture, spec, jest, pytest | — | `agents/unit-tester.md`, `agents/test-agent.md`, `agents/qa-orchestrator.md` | `plugins/qa-tools/commands/generate-tests.md` |
| `accessibility` | aria, a11y, wcag, screen reader, keyboard nav, focus, contrast, axe, lighthouse | — | `agents/ui-tester.md` | `plugins/accessibility/commands/fix-aria.md` |
| `bug` | bug, error, crash, exception, stack trace, fix, broken, failing, unexpected behavior | — | `agents/debugger.md` | `plugins/debugger/commands/debug.md` |
| `refactor` | refactor, simplify, extract, clean, complexity, duplication, technical debt | `skills/first-principles/SKILL.md` | `agents/architect.md` | `plugins/refactor-engine/commands/simplify.md` |
| `python` | python, pep, type hints, mypy, pydantic, fastapi, django, flask | `skills/python-code-standarts.md` | — | `plugins/python-expert/commands/refactor-py.md` |
| `ai_llm` | prompt, llm, embedding, rag, openai, anthropic, langchain, vector, claude | `skills/llm-integration/SKILL.md`, `skills/prompt-engineering/SKILL.md` | — | `plugins/ai-engineering/commands/optimize-prompt.md` |
| `docs` | readme, documentation, docs, changelog, contributing | `skills/doc-standarts.md` | `agents/doc-writer.md` | `plugins/documentation/commands/generate-readme.md` |
| `performance` | performance, slow, optimize, cache, bundle, latency, memory leak, profiling | `skills/performance-optimization/SKILL.md` | `agents/architect.md` | `plugins/database-tools/commands/optimize-query.md` |

If no domain matches → treat as `standard` complexity, no extra skills loaded.

## Step 3 — Choose Route

### Plugin-route conditions

Use `plugin-route` when **all three** are true:

1. Complexity is `standard` (not complex, not nano/micro).
2. Task matches **exactly one domain**.
3. Task intent directly maps to a specific plugin command — the task IS what the plugin does.

**Match examples:**

| Task | Domain | Plugin command | Route |
|---|---|---|---|
| "Optimize our Dockerfile" | `docker` | `optimize-dockerfile.md` | `plugin-route` |
| "Run a security audit" | `security` | `security-check.md` | `plugin-route` |
| "Design the REST API schema" | `api` | `design-api.md` | `plugin-route` |
| "Generate tests for UserService" | `testing` | `generate-tests.md` | `plugin-route` |
| "Refactor the auth module" | `refactor` | `simplify.md` | `plugin-route` |
| "Fix ARIA labels on the form" | `accessibility` | `fix-aria.md` | `plugin-route` |
| "Debug this crash / stack trace" | `bug` | `debug.md` | `plugin-route` |
| "Bump version and cut a release" | `release` | `release.md` | `plugin-route` |
| "Add JWT auth to the API" | `api` + `security` | — | `full-pipeline` (2 domains) |
| "Deploy the API to k8s with security hardening" | `ci_cd` + `security` | — | `full-pipeline` (2 domains) |
| "Add rate limiting and update the OpenAPI spec" | `api` | — | `full-pipeline` (multi-intent) |
| "Fix the bug and add tests" | `bug` + `testing` | — | `full-pipeline` (2 domains) |

### Route table

| Route | When | What runs |
|---|---|---|
| `direct-edit` | nano | Claude makes the edit directly. No agents. |
| `quick-coder` | micro | `quick-coder` agent (Ollama) → build check. |
| `plugin-route` | standard + single domain + single intent | Plugin file as plan → `coder` (Ollama) → `reviewer` (Ollama). **Planner skipped.** |
| `full-pipeline` | standard + multi-domain or multi-intent | Claude plans → `coder` (Ollama) → `reviewer` (Ollama). |
| `architect-first` | complex | Claude architect analysis → Claude plans → `coder` (Ollama) → `reviewer` (Ollama). |

> `plugin-route` skips the planning step entirely (Claude) while keeping Ollama for code generation and review.

## Step 4 — Write Triage Output

Write `.claude/context/triage.md` in this exact format:

```markdown
## Complexity
<nano | micro | standard | complex>

## Domains
<comma-separated list, or "none">

## Route
<direct-edit | quick-coder | plugin-route | full-pipeline | architect-first>

## Plugin Plan
<path to plugin command file used as plan, or "none" if not plugin-route>

## Skills
- <path to skill file>

## Agents
- <path to agent file>

## Constraints
<3–5 bullet points copied verbatim from the matched plugin command file.
Only concrete, actionable rules — not generic advice.>
```

### Example — "Optimize our Dockerfile" → plugin-route

```markdown
## Complexity
standard

## Domains
docker

## Route
plugin-route

## Plugin Plan
plugins/docker-helper/commands/optimize-dockerfile.md

## Skills
- skills/docker-best-practices/SKILL.md

## Agents
- agents/devops.md

## Constraints
- Use multi-stage builds to separate build and runtime layers.
- Never use `latest` tag — pin base image to a specific digest or version.
- Run container process as non-root user.
- Add .dockerignore to exclude node_modules, .git, build artifacts.
- Verify final image size and run smoke test after build.
```

### Example — "Add JWT auth to the REST API" → full-pipeline

```markdown
## Complexity
standard

## Domains
api, security

## Route
full-pipeline

## Plugin Plan
none

## Skills
- skills/api-design-patterns/SKILL.md
- skills/security-hardening/SKILL.md
- skills/authentication-patterns/SKILL.md

## Agents
- agents/architect.md
- agents/security-auditor.md
- agents/reviewer.md

## Constraints
- JWT tokens must be validated for signature, expiration, and issuer on every protected endpoint.
- Never store tokens in localStorage — use httpOnly cookies or Authorization header only.
- All auth endpoints must be rate-limited.
- Default to deny: every endpoint must explicitly declare its auth requirement.
- Passwords must use bcrypt, scrypt, or argon2id — never MD5 or SHA-256 alone.
```

## Rules

- Triage must complete and write `.claude/context/triage.md` before any other step runs.
- If the task is ambiguous → default to `full-pipeline`.
- `plugin-route` requires a single unambiguous plugin match — when in doubt, use `full-pipeline`.
- `## Constraints` must contain rules copied from the matched plugin file, not invented.
- Never load skills or agents outside the domain table above.
