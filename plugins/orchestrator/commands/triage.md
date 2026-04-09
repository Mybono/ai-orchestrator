Analyze the task description and produce a routing decision before the pipeline starts.

Triage runs as **Step 0** of `/implement`. It writes `.claude/context/triage.md` so all downstream steps — planner, coder, reviewer — start with the right expertise pre-loaded.

## Step 1 — Classify Complexity

Read the task description and classify into one tier:

| Tier | Criteria | Pipeline route |
|---|---|---|
| **nano** | Single line change, rename, import fix, constant update | Direct edit — skip pipeline entirely |
| **micro** | 1–3 files, no new abstractions, isolated change | `quick-coder` → build check only |
| **standard** | Feature, bug fix, multi-file change | Full pipeline |
| **complex** | Architecture change, new system, cross-cutting concern | `architect` pre-step → full pipeline |

## Step 2 — Detect Domain

Scan the task description for domain keywords. A task may match **multiple domains**.

| Domain | Keywords | Skills to load | Agents to load | Plugin reference |
|---|---|---|---|---|
| `api` | api, endpoint, rest, graphql, route, openapi, swagger, http method | `skills/api-design-patterns/SKILL.md` | `agents/architect.md` | `plugins/api-architect/commands/design-api.md` |
| `docker` | docker, image, dockerfile, container, compose, registry | `skills/docker-best-practices/SKILL.md` | `agents/devops.md` | `plugins/docker-helper/commands/optimize-dockerfile.md` |
| `ci_cd` | ci/cd, pipeline, deploy, release, github actions, k8s, kubernetes, helm, argocd | `skills/ci-cd-pipelines/SKILL.md`, `skills/kubernetes-operations/SKILL.md` | `agents/devops.md` | `plugins/k8s-helper/commands/generate-manifest.md`, `plugins/release-manager/commands/release.md` |
| `security` | security, auth, jwt, oauth, vulnerability, owasp, injection, xss, csrf, secrets | `skills/security-hardening/SKILL.md`, `skills/authentication-patterns/SKILL.md` | `agents/security-auditor.md`, `agents/reviewer.md` | `plugins/security-guidance/commands/security-check.md` |
| `database` | schema, sql, query, migration, erd, database, postgres, mysql, mongo, index | `skills/microservices-design/SKILL.md` | `agents/architect.md` | `plugins/database-tools/commands/design-schema.md` |
| `testing` | test, unit test, e2e, playwright, coverage, mock, fixture, spec | — | `agents/unit-tester.md`, `agents/qa-orchestrator.md` | `plugins/qa-tools/commands/generate-tests.md` |
| `refactor` | refactor, simplify, extract, clean, complexity, duplication, technical debt | `skills/first-principles/SKILL.md` | `agents/architect.md` | `plugins/refactor-engine/commands/simplify.md` |
| `python` | python, pep, type hints, mypy, pydantic, fastapi, django, flask | `skills/python-code-standarts.md` | — | `plugins/python-expert/commands/refactor-py.md` |
| `ai_llm` | prompt, llm, embedding, rag, ai, openai, anthropic, langchain, vector | `skills/llm-integration/SKILL.md`, `skills/prompt-engineering/SKILL.md` | — | `plugins/ai-engineering/commands/optimize-prompt.md` |
| `docs` | readme, documentation, docs, changelog, contributing | `skills/doc-standarts.md` | `agents/doc-writer.md` | `plugins/documentation/commands/generate-readme.md` |
| `performance` | performance, slow, optimize, cache, bundle, latency, memory leak, profil | `skills/performance-optimization/SKILL.md` | `agents/architect.md` | `plugins/database-tools/commands/optimize-query.md` |

If no domain matches → treat as `standard` complexity, no extra skills loaded.

## Step 3 — Write Triage Output

Write `.claude/context/triage.md` in this exact format:

```markdown
## Complexity
<tier: nano | micro | standard | complex>

## Domains
<comma-separated list, e.g.: api, security>

## Route
<one of: direct-edit | quick-coder | full-pipeline | architect-first>

## Skills
- <path to skill file 1>
- <path to skill file 2>

## Agents
- <path to agent file 1>
- <path to agent file 2>

## Plugin References
- <path to plugin command 1>
- <path to plugin command 2>

## Constraints
<2–5 bullet points extracted from the matched plugin commands that the coder must follow.
Copy the most critical rules from the matched plugin files — not generic advice.>
```

### Example output for "Add JWT authentication to the REST API":

```markdown
## Complexity
standard

## Domains
api, security

## Route
full-pipeline

## Skills
- skills/api-design-patterns/SKILL.md
- skills/security-hardening/SKILL.md
- skills/authentication-patterns/SKILL.md

## Agents
- agents/architect.md
- agents/security-auditor.md
- agents/reviewer.md

## Plugin References
- plugins/api-architect/commands/design-api.md
- plugins/security-guidance/commands/security-check.md

## Constraints
- JWT tokens must be validated for signature, expiration, and issuer on every protected endpoint.
- Never store tokens in localStorage — use httpOnly cookies or Authorization header only.
- All auth endpoints must be rate-limited to prevent brute force.
- Passwords must use bcrypt, scrypt, or argon2id — never MD5 or SHA-256 alone.
- Default to deny: every endpoint must explicitly declare its auth requirement.
```

## Step 4 — Route Decision

Based on `## Route` in triage output:

| Route | Action |
|---|---|
| `direct-edit` | Make the edit immediately. Do not proceed to `/implement` pipeline. |
| `quick-coder` | Spawn `quick-coder` agent only. Skip planner, reviewer, fix loop. |
| `full-pipeline` | Proceed to Step 1 of `implement.md` with triage context loaded. |
| `architect-first` | Spawn `architect` agent first. Wait for approval. Then proceed to Step 1. |

## Rules

- Triage must complete and write `.claude/context/triage.md` before any other step runs.
- If the task description is ambiguous, default to `standard` / `full-pipeline`.
- Never load skills or agents not listed in the domain table above.
- The `## Constraints` section must contain concrete rules copied from matched plugins — not invented ones.
