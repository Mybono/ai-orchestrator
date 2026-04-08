---
name: root-cause-analysis
description: >
  Systematically trace problems (bugs, incidents, performance regressions) back to 
  their fundamental, actionable causes using the 5-Whys methodology.
  Trigger when the user asks: "find the root cause", "почему это произошло", 
  "найди причину бага", "debug this issue", "排查问题", "why did this happen",
  "root cause analysis", "RCA", or when diagnosing CI/CD failures.
---

# Root Cause Analysis (5-Whys)

A systematic technique for drilling down through symptoms to uncover the true root cause of a problem by repeatedly asking "Why?" until the fundamental issue is revealed.

## When to use

- Bug investigation where the obvious fix didn't work.
- Production incidents requiring post-mortem analysis.
- Performance problems with unclear origins.
- Recurring issues that keep coming back after "fixes".
- CI/CD pipeline failures (e.g., Gitleaks, Linting, Test failures).

## The Methodology

### Phase 1: Define the Problem Clearly

State the problem as a specific, observable fact:

- **Good:** "Gitleaks failed in CI because it found a fake key in documentation."
- **Poor:** "CI is broken."

### Phase 2: Ask "Why?" Iteratively

For each answer, ask "Why does that happen?" until reaching an actionable root cause.

| Level | Question | Answer | Evidence |
|-------|----------|--------|----------|
| **Why 1** | Why did [problem] occur? | [Answer] | [Logs/Screenshot] |
| **Why 2** | Why did [Why 1 answer]? | [Answer] | [Code/Traces] |
| **Why 3** | Why did [Why 2 answer]? | [Answer] | [Architecture] |
| **Why 4** | Why did [Why 3 answer]? | [Answer] | [Process/Docs] |
| **Why 5** | Why did [Why 4 answer]? | [Root Cause] | [Final link] |

### Phase 3: Define Countermeasures

1. **Immediate fix (Containment):** Stop the bleeding now.
2. **Preventive measure (Permanent fix):** Ensure it never happens again.
3. **Detection mechanism:** Catch it automatically if it tries to return.

## Principles

1. **Focus on Process, Not People:** Blame systems and missing checks, not individuals.
2. **Actionable Outcomes:** A root cause must be something you can actually change.
3. **Fact-Based:** Every "Why" must be supported by evidence (logs, code, metrics).

## Standard Output Format

```markdown
## Root Cause Analysis: [Problem Title]

### Problem Statement
**What:** [Specific behavior]
**Impact:** [Consequence]

### Why Chain
1. **Why?** [Answer 1]
2. **Why?** [Answer 2]
3. **Why?** [Answer 3]
4. **Why?** [Answer 4]
5. **Why?** [Root Cause]

### Countermeasures
- **Immediate:** [Action]
- **Preventive:** [Action]
- **Detection:** [Action]
```

## Reference Patterns

- **Knowledge Gap:** Team was unaware of a specific constraint or tool behavior.
- **Process Gap:** Missing linting, testing, or review step.
- **Design Flaw:** Tight coupling or lack of proper error handling.
- **Tooling Issue:** False positives or misconfigured scanners.

## Reference Materials

- **[Software Patterns](references/software-patterns.md)** - Common root cause patterns in software (Error handling, Resource leaks, Race conditions, etc.)
- **[Toyota Origins](references/toyota-origins.md)** - History and core principles from the Toyota Production System (Genchi Genbutsu, Respect for People, Kaizen)
