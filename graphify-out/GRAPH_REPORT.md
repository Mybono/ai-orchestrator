# Graph Report - .  (2026-04-17)

## Corpus Check

- 9 files · ~104,803 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary

- 324 nodes · 423 edges · 52 communities detected
- Extraction: 85% EXTRACTED · 15% INFERRED · 0% AMBIGUOUS · INFERRED: 64 edges (avg confidence: 0.81)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)

- [[_COMMUNITY_Community 0|Community 0]]
- [[_COMMUNITY_Community 1|Community 1]]
- [[_COMMUNITY_Community 2|Community 2]]
- [[_COMMUNITY_Community 3|Community 3]]
- [[_COMMUNITY_Community 4|Community 4]]
- [[_COMMUNITY_Community 5|Community 5]]
- [[_COMMUNITY_Community 6|Community 6]]
- [[_COMMUNITY_Community 7|Community 7]]
- [[_COMMUNITY_Community 8|Community 8]]
- [[_COMMUNITY_Community 9|Community 9]]
- [[_COMMUNITY_Community 10|Community 10]]
- [[_COMMUNITY_Community 11|Community 11]]
- [[_COMMUNITY_Community 12|Community 12]]
- [[_COMMUNITY_Community 13|Community 13]]
- [[_COMMUNITY_Community 14|Community 14]]
- [[_COMMUNITY_Community 15|Community 15]]
- [[_COMMUNITY_Community 16|Community 16]]
- [[_COMMUNITY_Community 17|Community 17]]
- [[_COMMUNITY_Community 18|Community 18]]
- [[_COMMUNITY_Community 19|Community 19]]
- [[_COMMUNITY_Community 20|Community 20]]
- [[_COMMUNITY_Community 21|Community 21]]
- [[_COMMUNITY_Community 22|Community 22]]
- [[_COMMUNITY_Community 23|Community 23]]
- [[_COMMUNITY_Community 24|Community 24]]
- [[_COMMUNITY_Community 25|Community 25]]
- [[_COMMUNITY_Community 26|Community 26]]
- [[_COMMUNITY_Community 27|Community 27]]
- [[_COMMUNITY_Community 28|Community 28]]
- [[_COMMUNITY_Community 29|Community 29]]
- [[_COMMUNITY_Community 30|Community 30]]
- [[_COMMUNITY_Community 31|Community 31]]
- [[_COMMUNITY_Community 32|Community 32]]
- [[_COMMUNITY_Community 33|Community 33]]
- [[_COMMUNITY_Community 34|Community 34]]
- [[_COMMUNITY_Community 35|Community 35]]
- [[_COMMUNITY_Community 36|Community 36]]
- [[_COMMUNITY_Community 37|Community 37]]
- [[_COMMUNITY_Community 38|Community 38]]
- [[_COMMUNITY_Community 39|Community 39]]
- [[_COMMUNITY_Community 40|Community 40]]
- [[_COMMUNITY_Community 41|Community 41]]
- [[_COMMUNITY_Community 42|Community 42]]
- [[_COMMUNITY_Community 43|Community 43]]
- [[_COMMUNITY_Community 44|Community 44]]
- [[_COMMUNITY_Community 45|Community 45]]
- [[_COMMUNITY_Community 46|Community 46]]
- [[_COMMUNITY_Community 47|Community 47]]
- [[_COMMUNITY_Community 48|Community 48]]
- [[_COMMUNITY_Community 49|Community 49]]
- [[_COMMUNITY_Community 50|Community 50]]
- [[_COMMUNITY_Community 51|Community 51]]

## God Nodes (most connected - your core abstractions)

1. `Skill: Security Hardening (OWASP)` - 18 edges
2. `Documentation CLAUDE.md (Orchestrator Guide)` - 18 edges
3. `AI Orchestrator Professional Guide` - 12 edges
4. `Architect Agent` - 12 edges
5. `Reviewer Agent` - 11 edges
6. `Implement Command` - 11 edges
7. `Git Advanced Skill` - 11 edges
8. `Skill: Root Cause Analysis (5-Whys)` - 10 edges
9. `Coder Agent` - 10 edges
10. `LLM Integration Skill` - 10 edges

## Surprising Connections (you probably didn't know these)

- `Skill: Root Cause Analysis (5-Whys)` --conceptually_related_to--> `Git Bisect (Binary Search for Bugs)`  [INFERRED]
  documentation/SKILLS.md → skills/git-advanced/SKILL.md
- `Skill: Security Hardening (OWASP)` --conceptually_related_to--> `Code Review Excellence Skill`  [INFERRED]
  documentation/SKILLS.md → skills/code-review/SKILL.md
- `Skill: Security Hardening (OWASP)` --conceptually_related_to--> `Python Mastery Skill`  [INFERRED]
  documentation/SKILLS.md → skills/python/SKILL.md
- `graphify-out/ Knowledge Graph Output Directory` --references--> `project_overview.md Overview File`  [EXTRACTED]
  src/agents/TriageAgent.ts → agents/planner.md
- `graphify-out/ Knowledge Graph Output Directory` --references--> `task_context.md Context File`  [EXTRACTED]
  src/agents/TriageAgent.ts → agents/planner.md

## Hyperedges (group relationships)

- **TypeScript Orchestration Core Classes** — orchestrator_class, dependency_graph_class, agent_runner_class, planner_agent_class, triage_agent_class [EXTRACTED 1.00]
- **Shared Type System** — types_agent_domain, types_agent_task, types_agent_result, types_triage_result, types_run_result, types_llm_config [EXTRACTED 1.00]
- **CI Integration Scripts (Bitbucket)** — bitbucket_review_script, ci_debugger_script, concept_self_healing_ci [EXTRACTED 1.00]
- **Local Model Routing Layer** — call_ollama_sh, llm_config_json, model_qwen25_coder_14b, model_qwen25_coder_7b, model_llama31_8b, model_mxbai_embed_large [EXTRACTED 1.00]
- **Design Rationale Cluster** — rationale_pure_bash, rationale_local_llm_delegation, rationale_specialist_model_advantage, rationale_context_verdict_only [INFERRED 0.80]
- **Implement Pipeline: Planner -> Coder -> Reviewer** — implement_command, planner_agent, coder_agent, reviewer_agent, coding_pipeline [EXTRACTED 1.00]
- **Agents Using Ollama via call_ollama.sh** — coder_agent, reviewer_agent, commit_agent, debugger_agent, doc_writer_agent, devops_agent, call_ollama_sh [EXTRACTED 1.00]
- **Architect Agent Skill Bundle** — architect_agent, skill_first_principles, skill_microservices_design, skill_websocket_realtime, skill_security_hardening, skill_api_design_patterns, skill_authentication_patterns, skill_performance_optimization, skill_llm_integration, skill_prompt_engineering [EXTRACTED 1.00]
- **DevOps Agent Skill Bundle** — devops_agent, skill_ci_cd_pipelines, skill_aws_cloud_patterns, skill_kubernetes_operations, skill_docker_best_practices, skill_security_hardening, skill_microservices_design [EXTRACTED 1.00]
- **Agents Following Humanizer Skill** — coder_agent, reviewer_agent, commit_agent, doc_writer_agent, planner_agent, skill_humanizer [EXTRACTED 1.00]
- **QA Testing Agents Cluster** — api_tester_agent, qa_orchestrator_agent, plugin_qa_tools [EXTRACTED 1.00]
- **Error Recovery and Resilience Cluster** — error_coordinator_agent, debugger_agent, circuit_breaker_pattern, exponential_backoff_pattern [EXTRACTED 1.00]
- **Context and Performance Management Cluster** — context_manager_agent, performance_monitor_agent, context_budget_strategy, progressive_loading_strategy [INFERRED 0.80]
- **Triage TS Domain Routing** — triage_ts_agent, triage_ts_domain_coder, triage_ts_domain_unit_tester, triage_ts_domain_doc_writer, triage_ts_domain_devops [EXTRACTED 1.00]
- **Testing Agent Cluster** — agent_test-agent, agent_ui-tester, agent_unit-tester [INFERRED 0.85]
- **Implement Pipeline Steps** — cmd_implement, agent_planner, agent_coder, agent_reviewer, agent_quick-coder, agent_error-coordinator, context_task_context, context_triage, context_coder_output [EXTRACTED 1.00]
- **DevOps Plugin Cluster** — plugin_docker-helper, plugin_k8s-helper, agent_devops, skill_docker-best-practices, skill_kubernetes-operations [INFERRED 0.85]
- **Security Guidance Cluster** — plugin_security-guidance, cmd_fix-vulnerability, skill_security-hardening, agent_reviewer [INFERRED 0.85]
- **Ollama-Calling Agents** — agent_test-agent, agent_quick-coder, script_call_ollama [EXTRACTED 1.00]

## Communities

### Community 0 - "Community 0"

Cohesion: 0.11
Nodes (32): Agents Documentation, AI Orchestrator Professional Guide, Coder Agent, coder_output.md Output File, Coding Pipeline (Plan-Code-Build-Review), Commit Agent, Context Budget Strategy, Context Manager Agent (+24 more)

### Community 1 - "Community 1"

Cohesion: 0.08
Nodes (26): Debugger Agent, QA Orchestrator Agent, Unit Tester Agent, IDE Agent Orchestration Rules, API Tester Agent, Circuit Breaker Pattern, 5-Whys Methodology, 5-Whys Root Cause Analysis (+18 more)

### Community 2 - "Community 2"

Cohesion: 0.12
Nodes (24): Coder Agent, Context Manager Agent, Error Coordinator Agent, Performance Monitor Agent, Planner Agent, Quick Coder Agent, Reviewer Agent, Security Auditor Agent (+16 more)

### Community 3 - "Community 3"

Cohesion: 0.15
Nodes (23): DevOps Agent, Debug Pod Command, Optimize Dockerfile Command, Smart Commit Command, Commit and Push Command, Committer Plugin, CHANGELOG.md File, Conventional Commits (+15 more)

### Community 4 - "Community 4"

Cohesion: 0.11
Nodes (23): Architect Agent, architect_review.md Review File, Authentication Middleware, Content Security Policy, CSRF Protection, Dependency Auditing (npm audit, pip-audit), Input Validation (Zod/Security), JWT Access & Refresh Token Pattern (+15 more)

### Community 5 - "Community 5"

Cohesion: 0.1
Nodes (21): Code Review Process (4-Phase), FastAPI Framework, MCP Prompt Templates, MCP Server Resources, MCP Server Tool Design, MCP Transport (Stdio/SSE), Model Context Protocol (MCP) SDK, Python Async/Await Patterns (+13 more)

### Community 6 - "Community 6"

Cohesion: 0.13
Nodes (20): API Tester Agent, Architect Agent, Design API Command, HTTP Caching Headers Strategy, Code Splitting & Bundle Analysis, Core Web Vitals (LCP, INP, CLS), Image Optimization (WebP/AVIF, Lazy Loading), Virtual Lists for Large Data (+12 more)

### Community 7 - "Community 7"

Cohesion: 0.17
Nodes (3): AgentRunner, PlannerAgent, TriageAgent

### Community 8 - "Community 8"

Cohesion: 0.15
Nodes (16): Doc Writer Agent, Mypy Type Checker, PEP 8 Python Style Guide, RAII Memory Management Principle, Generate README Command, Documentation Plugin, Python Expert Plugin, Refactor Python Command (+8 more)

### Community 9 - "Community 9"

Cohesion: 0.18
Nodes (3): DependencyGraph, main(), Orchestrator

### Community 10 - "Community 10"

Cohesion: 0.2
Nodes (14): Analyze Prompt Command, Optimize Prompt Command, AI Engineering Plugin, Chain-of-Thought Prompting, Document Chunking for RAG, Few-Shot Prompting, LLM API Client Pattern (Anthropic), LLM Model Selection & Cost Optimization (+6 more)

### Community 11 - "Community 11"

Cohesion: 0.2
Nodes (14): ArgoCD GitOps Pattern, Bash CI/CD Scripts (GitHub Actions / GitLab), Bash Error Handling Patterns, Bash Safety Header (set -euo pipefail), Docker Multi-Stage Builds, GitHub Actions Workflow, GitLab CI Pipeline, GitOps Principles (+6 more)

### Community 12 - "Community 12"

Cohesion: 0.15
Nodes (13): Pattern: API Gateway, Pattern: Cursor-Based Pagination, Pattern: Docker Compose Service Orchestration, Pattern: Event-Driven Communication, Pattern: Helm Chart Structure, Pattern: HorizontalPodAutoscaler, Pattern: Docker Multi-Stage Build, Pattern: OpenAPI Spec-First Design (+5 more)

### Community 13 - "Community 13"

Cohesion: 0.46
Nodes (7): analyzeVulnerability(), getFixedCode(), hasTestFile(), runBitbucketReview(), runSecurityAuditInternal(), runTestCheckerInternal(), shouldHaveTest()

### Community 14 - "Community 14"

Cohesion: 0.7
Nodes (4): getSmartLog(), postToBitbucket(), postToGitHub(), runCiDebugger()

### Community 15 - "Community 15"

Cohesion: 0.4
Nodes (5): Agent Role: reviewer, Model Benchmarks Document, Model: qwen2.5-coder:7b (reviewer/commit/quick-coder roles), Plugin: security-guidance, Rationale: Specialist coder models outperform general models for diff review

### Community 16 - "Community 16"

Cohesion: 0.6
Nodes (5): AWS CDK Infrastructure as Code, AWS Lambda, DynamoDB Single-Table Design, S3 Event Processing, AWS Cloud Patterns Skill

### Community 17 - "Community 17"

Cohesion: 0.5
Nodes (5): UI Tester Agent, WCAG 2.1 Accessibility Standard, Accessibility Plugin, Fix ARIA Command, Test Screen Reader Command

### Community 18 - "Community 18"

Cohesion: 1.0
Nodes (2): Plugin-Route vs Full-Pipeline Routing Strategy, Triage Domain Auto-Routing

### Community 19 - "Community 19"

Cohesion: 1.0
Nodes (2): Agent Role: coder, Model: Qwen2.5-Coder-14B (coder role)

### Community 20 - "Community 20"

Cohesion: 1.0
Nodes (2): Agent Role: triage, Model: llama3.1:8b (triage role)

### Community 21 - "Community 21"

Cohesion: 1.0
Nodes (2): Context File Handoff Pattern (.claude/context/), Rationale: Orchestrator reads only Verdict line to keep context window small

### Community 22 - "Community 22"

Cohesion: 1.0
Nodes (0):

### Community 23 - "Community 23"

Cohesion: 1.0
Nodes (1): Multi-Layer Smart Pipeline (Triage->Plan->Code->Gate->Fix->Finalize)

### Community 24 - "Community 24"

Cohesion: 1.0
Nodes (1): Self-Healing CI (AI Debugger on failure)

### Community 25 - "Community 25"

Cohesion: 1.0
Nodes (1): Agent Role: debugger

### Community 26 - "Community 26"

Cohesion: 1.0
Nodes (1): Agent Role: devops

### Community 27 - "Community 27"

Cohesion: 1.0
Nodes (1): Agent Role: planner

### Community 28 - "Community 28"

Cohesion: 1.0
Nodes (1): Plugin: release-manager

### Community 29 - "Community 29"

Cohesion: 1.0
Nodes (1): Plugin: reviewer

### Community 30 - "Community 30"

Cohesion: 1.0
Nodes (1): Model: mxbai-embed-large (embedding role)

### Community 31 - "Community 31"

Cohesion: 1.0
Nodes (1): Symlink-based Installation (~/.claude/)

### Community 32 - "Community 32"

Cohesion: 1.0
Nodes (1): Rationale: Pure Bash for portability and zero dependencies

### Community 33 - "Community 33"

Cohesion: 1.0
Nodes (1): Bitbucket Pipelines Integration Guide

### Community 34 - "Community 34"

Cohesion: 1.0
Nodes (1): Project README

### Community 35 - "Community 35"

Cohesion: 1.0
Nodes (1): Project Changelog

### Community 36 - "Community 36"

Cohesion: 1.0
Nodes (1): Contributing Guide

### Community 37 - "Community 37"

Cohesion: 1.0
Nodes (1): Security Policy

### Community 38 - "Community 38"

Cohesion: 1.0
Nodes (1): Architecture Documentation

### Community 39 - "Community 39"

Cohesion: 1.0
Nodes (1): Skills Registry Documentation

### Community 40 - "Community 40"

Cohesion: 1.0
Nodes (1): Plugins Documentation

### Community 41 - "Community 41"

Cohesion: 1.0
Nodes (1): Ollama Local LLM API

### Community 42 - "Community 42"

Cohesion: 1.0
Nodes (1): LLM Config (llm-config.json)

### Community 43 - "Community 43"

Cohesion: 1.0
Nodes (1): Token Stats File (token_stats.json)

### Community 44 - "Community 44"

Cohesion: 1.0
Nodes (1): git-cliff Changelog Tool

### Community 45 - "Community 45"

Cohesion: 1.0
Nodes (1): GitHub CLI (gh)

### Community 46 - "Community 46"

Cohesion: 1.0
Nodes (1): ShellCheck Static Analysis Tool

### Community 47 - "Community 47"

Cohesion: 1.0
Nodes (1): Project Overview Context File

### Community 48 - "Community 48"

Cohesion: 1.0
Nodes (1): Analysis Delta Report

### Community 49 - "Community 49"

Cohesion: 1.0
Nodes (1): VERSION (1.0.15)

### Community 50 - "Community 50"

Cohesion: 1.0
Nodes (1): GitHub Repo: Mybono/ai-orchestrator

### Community 51 - "Community 51"

Cohesion: 1.0
Nodes (1): Conventional Commits standard

## Ambiguous Edges - Review These

- `Skill: TypeScript Mastery` → `Plugin: api-architect`  [AMBIGUOUS]
  documentation/PLUGINS.md · relation: conceptually_related_to

## Knowledge Gaps

- **124 isolated node(s):** `Multi-Layer Smart Pipeline (Triage->Plan->Code->Gate->Fix->Finalize)`, `Plugin-Route vs Full-Pipeline Routing Strategy`, `Context File Handoff Pattern (.claude/context/)`, `Triage Domain Auto-Routing`, `Self-Healing CI (AI Debugger on failure)` (+119 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **Thin community `Community 18`** (2 nodes): `Plugin-Route vs Full-Pipeline Routing Strategy`, `Triage Domain Auto-Routing`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 19`** (2 nodes): `Agent Role: coder`, `Model: Qwen2.5-Coder-14B (coder role)`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 20`** (2 nodes): `Agent Role: triage`, `Model: llama3.1:8b (triage role)`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 21`** (2 nodes): `Context File Handoff Pattern (.claude/context/)`, `Rationale: Orchestrator reads only Verdict line to keep context window small`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 22`** (1 nodes): `index.ts`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 23`** (1 nodes): `Multi-Layer Smart Pipeline (Triage->Plan->Code->Gate->Fix->Finalize)`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 24`** (1 nodes): `Self-Healing CI (AI Debugger on failure)`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 25`** (1 nodes): `Agent Role: debugger`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 26`** (1 nodes): `Agent Role: devops`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 27`** (1 nodes): `Agent Role: planner`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 28`** (1 nodes): `Plugin: release-manager`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 29`** (1 nodes): `Plugin: reviewer`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 30`** (1 nodes): `Model: mxbai-embed-large (embedding role)`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 31`** (1 nodes): `Symlink-based Installation (~/.claude/)`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 32`** (1 nodes): `Rationale: Pure Bash for portability and zero dependencies`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 33`** (1 nodes): `Bitbucket Pipelines Integration Guide`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 34`** (1 nodes): `Project README`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 35`** (1 nodes): `Project Changelog`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 36`** (1 nodes): `Contributing Guide`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 37`** (1 nodes): `Security Policy`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 38`** (1 nodes): `Architecture Documentation`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 39`** (1 nodes): `Skills Registry Documentation`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 40`** (1 nodes): `Plugins Documentation`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 41`** (1 nodes): `Ollama Local LLM API`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 42`** (1 nodes): `LLM Config (llm-config.json)`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 43`** (1 nodes): `Token Stats File (token_stats.json)`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 44`** (1 nodes): `git-cliff Changelog Tool`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 45`** (1 nodes): `GitHub CLI (gh)`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 46`** (1 nodes): `ShellCheck Static Analysis Tool`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 47`** (1 nodes): `Project Overview Context File`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 48`** (1 nodes): `Analysis Delta Report`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 49`** (1 nodes): `VERSION (1.0.15)`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 50`** (1 nodes): `GitHub Repo: Mybono/ai-orchestrator`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.
- **Thin community `Community 51`** (1 nodes): `Conventional Commits standard`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.

## Suggested Questions

_Questions this graph is uniquely positioned to answer:_

- **What is the exact relationship between `Skill: TypeScript Mastery` and `Plugin: api-architect`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._
- **Why does `Documentation CLAUDE.md (Orchestrator Guide)` connect `Community 2` to `Community 1`, `Community 3`, `Community 4`, `Community 6`, `Community 10`, `Community 11`, `Community 16`?**
  _High betweenness centrality (0.195) - this node is a cross-community bridge._
- **Why does `Architect Agent` connect `Community 4` to `Community 0`, `Community 10`, `Community 6`?**
  _High betweenness centrality (0.118) - this node is a cross-community bridge._
- **Why does `Skill: Security Hardening (OWASP)` connect `Community 4` to `Community 0`, `Community 1`, `Community 2`, `Community 5`?**
  _High betweenness centrality (0.115) - this node is a cross-community bridge._
- **Are the 5 inferred relationships involving `Skill: Security Hardening (OWASP)` (e.g. with `Authentication Patterns Skill` and `Code Review Excellence Skill`) actually correct?**
  _`Skill: Security Hardening (OWASP)` has 5 INFERRED edges - model-reasoned connections that need verification._
- **Are the 2 inferred relationships involving `Reviewer Agent` (e.g. with `task_context.md Context File` and `coder_output.md Output File`) actually correct?**
  _`Reviewer Agent` has 2 INFERRED edges - model-reasoned connections that need verification._
- **What connects `Multi-Layer Smart Pipeline (Triage->Plan->Code->Gate->Fix->Finalize)`, `Plugin-Route vs Full-Pipeline Routing Strategy`, `Context File Handoff Pattern (.claude/context/)` to the rest of the system?**
  _124 weakly-connected nodes found - possible documentation gaps or missing edges._
