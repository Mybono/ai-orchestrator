# Graph Report - .  (2026-04-16)

## Corpus Check
- 9 files · ~99,818 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 46 nodes · 64 edges · 7 communities detected
- Extraction: 92% EXTRACTED · 8% INFERRED · 0% AMBIGUOUS · INFERRED: 5 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- [[_COMMUNITY_Community 0|Community 0]]
- [[_COMMUNITY_Community 1|Community 1]]
- [[_COMMUNITY_Community 2|Community 2]]
- [[_COMMUNITY_Community 3|Community 3]]
- [[_COMMUNITY_Community 4|Community 4]]
- [[_COMMUNITY_Community 5|Community 5]]
- [[_COMMUNITY_Community 6|Community 6]]

## God Nodes (most connected - your core abstractions)
1. `TriageAgent` - 8 edges
2. `Orchestrator` - 7 edges
3. `runBitbucketReview()` - 4 edges
4. `runTestCheckerInternal()` - 4 edges
5. `runCiDebugger()` - 4 edges
6. `DependencyGraph` - 4 edges
7. `runSecurityAuditInternal()` - 3 edges
8. `AgentRunner` - 3 edges
9. `PlannerAgent` - 3 edges
10. `analyzeVulnerability()` - 2 edges

## Surprising Connections (you probably didn't know these)
- None detected - all connections are within the same source files.

## Communities

### Community 0 - "Community 0"
Cohesion: 0.22
Nodes (3): AgentRunner, main(), PlannerAgent

### Community 1 - "Community 1"
Cohesion: 0.46
Nodes (7): analyzeVulnerability(), getFixedCode(), hasTestFile(), runBitbucketReview(), runSecurityAuditInternal(), runTestCheckerInternal(), shouldHaveTest()

### Community 2 - "Community 2"
Cohesion: 0.43
Nodes (1): TriageAgent

### Community 3 - "Community 3"
Cohesion: 0.29
Nodes (1): DependencyGraph

### Community 4 - "Community 4"
Cohesion: 0.48
Nodes (1): Orchestrator

### Community 5 - "Community 5"
Cohesion: 0.7
Nodes (4): getSmartLog(), postToBitbucket(), postToGitHub(), runCiDebugger()

### Community 6 - "Community 6"
Cohesion: 1.0
Nodes (0): 

## Knowledge Gaps
- **Thin community `Community 6`** (1 nodes): `index.ts`
  Too small to be a meaningful cluster - may be noise or needs more connections extracted.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Orchestrator` connect `Community 4` to `Community 3`?**
  _High betweenness centrality (0.131) - this node is a cross-community bridge._
- **Why does `TriageAgent` connect `Community 2` to `Community 0`?**
  _High betweenness centrality (0.074) - this node is a cross-community bridge._