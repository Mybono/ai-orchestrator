[README](../README.md) · [Architecture](ARCHITECTURE.md) · [Agents](AGENTS.md) · [Skills & Commands](SKILLS.md) · [CLAUDE](CLAUDE.md) · **Plugins**

---

# Plugins

Plugins extend the orchestrator with domain-specific commands. Each plugin lives in `plugins/<name>/` and contains a `commands/` subdirectory with markdown command files that Claude can invoke directly.

| Plugin | Description | Trigger keywords | Paired agent |
|:---|:---|:---|:---|
| `accessibility` | Fix ARIA attributes and test screen reader compliance. | "ARIA", "screen reader", "a11y" | [ui-tester](../agents/ui-tester.md) |
| `ai-engineering` | Analyze and optimize AI prompts and instruction sets. | "prompt", "analyze AI", "optimize instruction" | (standalone) |
| `api-architect` | Design REST APIs and generate OpenAPI specs. | "API", "OpenAPI", "endpoints" | [architect](../agents/architect.md) |
| `committer` | Stage changes and generate commit messages or PRs via `gh`. | "commit", "push", "open pr" | [commit](../agents/commit.md) |
| `database-tools` | Design schemas, optimize queries, and generate ERDs. | "schema", "SQL", "slow query", "ERD" | [architect](../agents/architect.md) |
| `debugger` | Trace root cause using 5-Whys analysis. | "error log", "why?", "fix this", "crash" | [debugger](../agents/debugger.md) |
| `docker-helper` | Build Docker images and optimize Dockerfiles. | "docker", "deploy" | [devops](../agents/devops.md) |
| `documentation` | Generate README and other documentation files. | "update readme", "write docs", "generate readme" | [doc-writer](../agents/doc-writer.md) |
| `k8s-helper` | Debug pods and generate Kubernetes manifests. | "k8s", "pod failed", "deploy" | [devops](../agents/devops.md) |
| `orchestrator` | Run the full implement pipeline and view token savings. | "/implement", "/stats" | planner · coder · reviewer |
| `python-expert` | Refactor Python code and add type hints. | "Python idioms", "PEP 8", "type hints" | [coder](../agents/coder.md) |
| `qa-tools` | Generate tests, analyze failures, fix PR comments, seed databases. | "unit test", "api test", "analyze failures", "fix comments" | [unit-tester](../agents/unit-tester.md) · [api-tester](../agents/api-tester.md) · [qa-orchestrator](../agents/qa-orchestrator.md) |
| `refactor-engine` | Extract functions and simplify complex code. | "refactor", "simplify" | [architect](../agents/architect.md) |
| `release-manager` | Bump version, cut releases, and update changelogs. | "release", "version bump" | [devops](../agents/devops.md) |
| `reviewer` | Review code changes against language standards. | "review", "audit" | [reviewer](../agents/reviewer.md) |
| `security-guidance` | Run security audits and fix vulnerabilities. | "audit", "vulnerability", "CVE", "auth check", "security" | [reviewer](../agents/reviewer.md) |

---

[README](../README.md) · [Architecture](ARCHITECTURE.md) · [Agents](AGENTS.md) · [Skills & Commands](SKILLS.md) · [CLAUDE](CLAUDE.md) · **Plugins**
