[README](../README.md) · [Architecture](ARCHITECTURE.md) · [Agents](AGENTS.md) · [Skills & Commands](SKILLS.md) · [Plugins](PLUGINS.md) · **CLAUDE**

---

# AI Orchestrator — Professional Guide

This file is read by Claude Code when working in this repo. It covers the orchestration pipeline, LLM roles, slash commands, and trigger rules. The project is structured as a collection of **Modular Claude Code Plugins** located in the [plugins/](../plugins/) directory. For the full plugin list with descriptions and trigger keywords, see [Plugins](PLUGINS.md).

## Orchestrator Roles

Roles are defined in [llm-config.json](../llm-config.json). Each role corresponds to a specialized agent instruction.

| Role | Agent / Instruction | Responsibility |
|:---|:---|:---|
| **coder** | [agents/coder.md](../agents/coder.md) | Main code generation & implementation |
| **reviewer** | [agents/reviewer.md](../agents/reviewer.md) | Code quality, standards & documentation |
| **commit** | [agents/commit.md](../agents/commit.md) | Stage changes, PRs & commit messages |
| **debugger** | [agents/debugger.md](../agents/debugger.md) | Root Cause Analysis (5-Whys) & bug fixing |
| **architect** | [agents/architect.md](../agents/architect.md) | System design, refactoring & planning |
| **devops** | [agents/devops.md](../agents/devops.md) | CI/CD, Infrastructure (AWS/K8s) & MCP |
| **planner**| [agents/planner.md](../agents/planner.md) | Context gathering & implementation planning |

---

## Coding Pipeline

For non-trivial tasks, use the `/implement` command:

```text
                                       ┌─ reviewer (file A) ─┐
planner ──► coder ──► build check ──┤─ reviewer (file B) ─├──► approved / fix loop
                                       └─ reviewer (file C) ─┘
```

1. **Planner**: Detects language, reads standards, and writes `task_context.md`.
2. **Coder**: Orchestrates the implementation via local models.
3. **Build Check**: Runs `tsc`, `py_compile`, or equivalent to catch syntax errors.
4. **Reviewer**: Performs parallel review of every changed file against standards.

---

## Skill Registry

Skills define specialized standards and expert knowledge.

### Core Languages & Standards

Detected automatically via indicator files in the project root.

| Indicator | Language | Standard File |
|:---|:---|:---|
| `tsconfig.json` | TypeScript | [ts-code-standarts.md](../skills/ts-code-standarts.md) |
| `pyproject.toml` | Python | [python-code-standarts.md](../skills/python-code-standarts.md) |
| `pubspec.yaml` | Flutter/Dart| [flutter-code-standarts.md](../skills/flutter-code-standarts.md) |
| `Package.swift` | Swift | [swift-code-standarts.md](../skills/swift-code-standarts.md) |
| `CMakeLists.txt`| C++ | [c-code-standarts.md](../skills/c-code-standarts.md) |
| `*.sh` | Bash/Shell | [bash-code-standarts.md](../skills/bash-code-standarts.md) |
| — | Documentation | [doc-standarts.md](../skills/doc-standarts.md) |

### Specialized Expertise

Loaded manually or via triggers for specific task domains.

| Area | Skill File |
|:---|:---|
| **Architecture**| [microservices-design](../skills/microservices-design/SKILL.md) · [first-principles](../skills/first-principles/SKILL.md) · [api-design](../skills/api-design-patterns/SKILL.md) |
| **Operations** | [kubernetes-ops](../skills/kubernetes-operations/SKILL.md) · [docker-best-practices](../skills/docker-best-practices/SKILL.md) · [aws-cloud](../skills/aws-cloud-patterns/SKILL.md) · [ci-cd](../skills/ci-cd-pipelines/SKILL.md) |
| **Real-time** | [websocket-realtime](../skills/websocket-realtime/SKILL.md) |
| **Security** | [security-hardening](../skills/security-hardening/SKILL.md) · [authentication-patterns](../skills/authentication-patterns/SKILL.md) |
| **AI / LLM** | [llm-integration](../skills/llm-integration/SKILL.md) · [prompt-engineering](../skills/prompt-engineering/SKILL.md) |
| **Expertise** | [root-cause-analysis](../skills/root-cause-analysis/SKILL.md) · [git-advanced](../skills/git-advanced/SKILL.md) · [performance](../skills/performance-optimization/SKILL.md) |

---

## Operational Rules

### Slash Commands

| Command | Usage |
|:---|:---|
| `/implement` | Full pipeline: Plan → Code → Build → Review |
| `/review` | Audit current changes against language standards |
| `/commit` | Generate commit message (local LLM) and stage changes |
| `/commit-push` | Local AI commit + Git push to remote |
| `/debug` | Systematic RCA and minimal fix proposal |
| `/stats` | View token savings (day/week/month) |

### Trigger Rules

BLOCKING: Invoke the matching agent/skill before responding.

- **High Level**: "refactor", "simplify", "approach?", "microservices", "API", "OpenAPI", "endpoints" → [architect](../agents/architect.md), [api-architect](../plugins/api-architect/), [refactor-engine](../plugins/refactor-engine/)
- **Infrastructure**: "setup CI/CD", "deploy", "k8s", "docker", "release", "version bump" → [devops](../agents/devops.md), [docker-helper](../plugins/docker-helper/), [k8s-helper](../plugins/k8s-helper/), [release-manager](../plugins/release-manager/)
- **Database**: "schema", "SQL", "slow query", "ERD" → [architect](../agents/architect.md), [database-tools](../plugins/database-tools/)
- **AI/Prompts**: "prompt", "analyze AI", "optimize instruction" → [ai-engineering](../plugins/ai-engineering/)
- **Specialized**:
  - Python: "Python idioms", "PEP 8", "type hints" → [python-expert](../plugins/python-expert/)
  - Accessibility: "ARIA", "screen reader", "a11y" → [ui-tester](../agents/ui-tester.md), [accessibility](../plugins/accessibility/)
- **Troubleshoot**: "error log", "why?", "fix this", "pod failed", "crash" → [debugger](../agents/debugger.md), [k8s-helper](../plugins/k8s-helper/)
- **Git/PR**: "commit", "push", "open pr" → [commit](../agents/commit.md), [committer](../plugins/committer/)
- **Security Check**: "audit", "vulnerability", "CVE", "auth check", "security" → [reviewer](../agents/reviewer.md), [security-guidance](../plugins/security-guidance/)
- **Docs**: "update readme", "write docs", "generate readme" → [doc-writer](../agents/doc-writer.md), [documentation](../plugins/documentation/)
- **Testing**:
  - Unit: "logic", "unit test", "mock" → [unit-tester](../agents/unit-tester.md), [qa-tools](../plugins/qa-tools/)
  - API: "integration", "api test", "schema", "seed" → [api-tester](../agents/api-tester.md), [qa-tools](../plugins/qa-tools/)
  - UI: "e2e", "ui test", "playwright", "browser" → [ui-tester](../agents/ui-tester.md)
  - Strategy: "analyze failures", "fix comments", "qa report" → [qa-orchestrator](../agents/qa-orchestrator.md), [qa-tools](../plugins/qa-tools/)

---

## Core Constraints

- **No direct edits**: Never edit core `.sh` scripts directly; use the `coder` agent.
- **Zero dependencies**: Never add Python/Node dependencies to the core orchestrator.
- **JSON handling**: ALWAYS use `jq` for JSON processing in shell scripts.
- **Separation**: Never use `doc-writer` for code or `coder` for markdown.

---

[README](../README.md) · [Architecture](ARCHITECTURE.md) · [Agents](AGENTS.md) · [Skills & Commands](SKILLS.md) · [Plugins](PLUGINS.md) · **CLAUDE**
