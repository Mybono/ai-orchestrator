# Skills Registry

This document serves as a comprehensive index of all specialized skills available to the AI Orchestrator. Skills define coding standards, architectural patterns, and operational expertise.

## How Skills Work

1. **Auto-detection**: For programming languages, skills are loaded automatically based on indicator files in the project root.
2. **Contextual Loading**: For specialized tasks (e.g., "deploy", "optimize"), agents load the relevant skill manually or via trigger rules defined in [CLAUDE.md](CLAUDE.md).
3. **Task Context**: The planner reads the required skill and embeds its core rules into the `task_context.md`.

---

## Programming Languages

### Legacy standards (auto-detected)

Detected automatically via indicator files in the project root. The planner reads the matching file and embeds it into `task_context.md`.

| Indicator | Language | Standard File |
|:---|:---|:---|
| `tsconfig.json` | TypeScript | [ts-code-standarts.md](../skills/ts-code-standarts.md) |
| `pyproject.toml` | Python | [python-code-standarts.md](../skills/python-code-standarts.md) |
| `pubspec.yaml` | Flutter/Dart | [flutter-code-standarts.md](../skills/flutter-code-standarts.md) |
| `Package.swift` | Swift | [swift-code-standarts.md](../skills/swift-code-standarts.md) |
| `CMakeLists.txt` | C++ | [c-code-standarts.md](../skills/c-code-standarts.md) |
| `*.sh` | Bash/Shell | [bash-code-standarts.md](../skills/bash-code-standarts.md) |

### Active skills (trigger-based)

These skills use the `SKILL.md` format with a YAML front matter block that includes a `description` field and optional `allowed-tools`. They are loaded on demand when a matching trigger keyword appears in the user's request — not by file detection.

| Skill | Trigger conditions | Path |
|:---|:---|:---|
| **Bash scripting** | "make a script", "shell script", "bash error", cron jobs, `.sh` files, CI entrypoints | [bash/SKILL.md](../skills/bash/SKILL.md) |
| **Python mastery** | "Python script", "PEP 8", "type hints", `pyproject.toml`, `pytest`, `.py` files, tracebacks | [python/SKILL.md](../skills/python/SKILL.md) |
| **TypeScript mastery** | TypeScript errors, generics, `tsconfig`, Zod, type narrowing, JS-to-TS migration | [typescript/SKILL.md](../skills/typescript/SKILL.md) |
| **Code review** | "PR review", "code review", "review changes", "review standards", architecture reviews | [code-review/SKILL.md](../skills/code-review/SKILL.md) |

---

## Engineering & Architecture

Principles for designing robust, scalable, and maintainable systems.

| Skill | Description | Path |
|:---|:---|:---|
| **First Principles** | Reasoning from fundamental truths rather than analogies. | [first-principles](../skills/first-principles/SKILL.md) |
| **Microservices** | Distributed system design, saga patterns, and service boundaries. | [microservices-design](../skills/microservices-design/SKILL.md) |
| **API Design** | RESTful standards, resource naming, and OpenAPI specifications. | [api-design-patterns](../skills/api-design-patterns/SKILL.md) |
| **Auth Patterns** | Secure implementation of JWT, OAuth2, and session management. | [authentication-patterns](../skills/authentication-patterns/SKILL.md) |
| **WebSockets** | Real-time communication patterns (WS, Socket.io, SSE). | [websocket-realtime](../skills/websocket-realtime/SKILL.md) |

---

## DevOps & Infrastructure

Expertise in cloud environments, containerization, and automation.

| Skill | Description | Path |
|:---|:---|:---|
| **K8s Operations** | Cluster management, Helm charts, and manifest optimization. | [kubernetes-operations](../skills/kubernetes-operations/SKILL.md) |
| **Docker Best Practices**| Multi-stage builds, image security, and optimization. | [docker-best-practices](../skills/docker-best-practices/SKILL.md) |
| **AWS Cloud** | Cloud-native patterns, IAM, networking, and serverless. | [aws-cloud-patterns](../skills/aws-cloud-patterns/SKILL.md) |
| **CI/CD Pipelines** | Automation workflows (GH Actions), caching, and strategies. | [ci-cd-pipelines](../skills/ci-cd-pipelines/SKILL.md) |
| **DevOps Automation** | Infrastructure as Code and system automation methodology. | [devops-automation](../skills/devops-automation/SKILL.md) |
| **MCP Development** | Model Context Protocol server design and transport. | [mcp-development](../skills/mcp-development/SKILL.md) |

---

## AI & Local Models

Mastery over LLM interactions and integration patterns.

| Skill | Description | Path |
|:---|:---|:---|
| **Prompt Engineering** | System prompts, Chain-of-Thought, and few-shot learning. | [prompt-engineering](../skills/prompt-engineering/SKILL.md) |
| **LLM Integration** | RAG pipelines, streaming, and tool-use orchestration. | [llm-integration](../skills/llm-integration/SKILL.md) |
| **Humanizer** | Removes robotic patterns and ensures natural tone. | [humanizer](../skills/humanizer.md) |

---

## Methodology & Utilities

General-purpose expertise for debugging, Git, and performance.

| Skill | Description | Path |
|:---|:---|:---|
| **Root Cause Analysis**| Systematic 5-Whys methodology for deep debugging. | [root-cause-analysis](../skills/root-cause-analysis/SKILL.md) |
| **Git Advanced** | Worktrees, bisect, recovery, and rebase strategies. | [git-advanced](../skills/git-advanced/SKILL.md) |
| **Performance** | Web vitals, bundle analysis, and caching strategies. | [performance-optimization](../skills/performance-optimization/SKILL.md) |
| **Code Review** | Methodology for rigorous and helpful peer reviews. | [code-review](../skills/code-review/SKILL.md) |
| **Doc Standards** | Documentation quality and technical writing principles. | [doc-standarts](../skills/doc-standarts.md) |

---

[README](../README.md) · [Architecture](ARCHITECTURE.md) · [Agents](AGENTS.md) · [CLAUDE](CLAUDE.md) · [Plugins](PLUGINS.md)
