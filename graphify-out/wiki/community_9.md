# Parallel Execution Architecture

**18 nodes**

## Nodes

- **AgentRunner Class** (src/agents/AgentRunner.ts)
- **Context File Handoff Pattern (.claude/context/)** (documentation/ARCHITECTURE.md)
- **Hardcoded Domain Dependency Map (coder->unit-tester->doc-writer->devops)** (src/agents/PlannerAgent.ts)
- **Graphify Knowledge Graph Integration in Triage** (src/agents/TriageAgent.ts)
- **Multi-Layer Smart Pipeline (Triage->Plan->Code->Gate->Fix->Finalize)** (documentation/ARCHITECTURE.md)
- **Plugin-Route vs Full-Pipeline Routing Strategy** (documentation/ARCHITECTURE.md)
- **Triage Domain Auto-Routing** (documentation/ARCHITECTURE.md)
- **DependencyGraph Class (Kahn's Algorithm)** (src/core/DependencyGraph.ts)
- **Orchestrator Entry Point (src/index.ts)** (src/index.ts)
- **Orchestrator Class** (src/core/Orchestrator.ts)
- **PlannerAgent Class** (src/agents/PlannerAgent.ts)
- **Rationale: Orchestrator reads only Verdict line to keep context window small** (documentation/ARCHITECTURE.md)
- **TriageAgent Class** (src/agents/TriageAgent.ts)
- **AgentDomain Type** (src/types/index.ts)
- **AgentResult Type** (src/types/index.ts)
- **AgentTask Type** (src/types/index.ts)
- **RunResult Type** (src/types/index.ts)
- **TriageResult Type** (src/types/index.ts)

## Connections to other communities

- LLM Roles & Analysis Scripts: 1 edges
- TypeScript Types & Config: 1 edges
