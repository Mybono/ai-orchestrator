# Common Root Cause Patterns in Software

Frequently encountered root causes when applying 5-Whys to software problems.

---

## Pattern 1: Missing Error Handling

### Typical Chain

```text
Problem: Service returns 500 error intermittently
Why 1: Unhandled exception in payment processing
Why 2: External API returned unexpected format
Why 3: API version changed without notice
Why 4: No schema validation on API response
Why 5: Error handling assumes happy path only
```

### Root Cause Type

**Design Gap** - Defensive programming not applied

### Countermeasures

| Type | Action |
|------|--------|
| Immediate | Add try-catch, return graceful error |
| Preventive | Schema validation on all external inputs |
| Detection | Alert on unexpected response formats |

---

## Pattern 2: Resource Leaks

### Typical Chain

```text
Problem: Application memory grows until OOM
Why 1: Heap usage increases over time
Why 2: Objects not garbage collected
Why 3: References held in static cache
Why 4: Cache has no eviction policy
Why 5: Cache designed for small dataset, now large
```

### Root Cause Type

**Scaling Assumption** - Design didn't account for growth

### Countermeasures

| Type | Action |
|------|--------|
| Immediate | Restart service, add memory |
| Preventive | LRU cache with size limits |
| Detection | Memory usage alerts at 80% |

---

## Pattern 3: Race Conditions

### Typical Chain

```text
Problem: Duplicate orders created occasionally
Why 1: Same order inserted twice
Why 2: Two requests processed simultaneously
Why 3: No idempotency key check
Why 4: Assumed single request per order
Why 5: No distributed system thinking in design
```

### Root Cause Type

**Concurrency Gap** - Single-threaded assumptions in distributed system

### Countermeasures

| Type | Action |
|------|--------|
| Immediate | Database unique constraint |
| Preventive | Idempotency keys required |
| Detection | Duplicate detection in monitoring |

---

## Pattern 4: Configuration Drift

### Typical Chain

```text
Problem: Feature works in staging, fails in prod
Why 1: Environment variable missing in prod
Why 2: Manual deployment missed the variable
Why 3: No config validation at startup
Why 4: No infrastructure-as-code for env vars
Why 5: Config management treated as afterthought
```

### Root Cause Type

**Process Gap** - Manual process where automation needed

### Countermeasures

| Type | Action |
|------|--------|
| Immediate | Add missing config |
| Preventive | IaC for all configuration |
| Detection | Config diff check in CI/CD |

---

## Pattern 5: Cascade Failures

### Typical Chain

```text
Problem: All services down during traffic spike
Why 1: Database connection pool exhausted
Why 2: Queries taking 10x longer than normal
Why 3: Missing index on new query pattern
Why 4: New feature added query without review
Why 5: No query performance review in PR process
```

### Root Cause Type

**Process Gap** - Missing review step

### Countermeasures

| Type | Action |
|------|--------|
| Immediate | Add index, restart services |
| Preventive | Query review checklist in PR |
| Detection | Query latency alerts |

---

## Pattern 6: Security Vulnerabilities

### Typical Chain

```text
Problem: SQL injection found in production
Why 1: User input directly in SQL query
Why 2: Using string concatenation for queries
Why 3: Developer unaware of parameterized queries
Why 4: No security training for new developers
Why 5: Security not part of onboarding process
```

### Root Cause Type

**Knowledge Gap** - Training/onboarding deficiency

### Countermeasures

| Type | Action |
|------|--------|
| Immediate | Fix query, audit similar code |
| Preventive | Security training mandatory |
| Detection | Static analysis in CI |

---

## Pattern 7: Dependency Failures

### Typical Chain

```text
Problem: Build failed after weekend
Why 1: npm install fails
Why 2: Package version no longer exists
Why 3: Using floating version (^1.0.0)
Why 4: Lock file not committed
Why 5: No policy on dependency pinning
```

### Root Cause Type

**Policy Gap** - Missing standard/guideline

### Countermeasures

| Type | Action |
|------|--------|
| Immediate | Pin version, commit lock file |
| Preventive | Require lock files in all repos |
| Detection | CI fails if lock file missing |

---

## Pattern 8: Data Corruption

### Typical Chain

```text
Problem: Users see wrong account balance
Why 1: Balance calculation includes deleted transactions
Why 2: Soft delete not filtered in query
Why 3: New query copied from old one without filter
Why 4: No standard query patterns/repository layer
Why 5: Each feature writes raw SQL independently
```

### Root Cause Type

**Architecture Gap** - Missing abstraction layer

### Countermeasures

| Type | Action |
|------|--------|
| Immediate | Fix query, audit similar |
| Preventive | Repository pattern with standard filters |
| Detection | Data consistency checks |

---

## Root Cause Categories Summary

| Category | Description | Typical Fix |
|----------|-------------|-------------|
| **Design Gap** | Missing consideration in design | Redesign component |
| **Process Gap** | Manual where automation needed | Automate process |
| **Knowledge Gap** | Team missing skill/awareness | Training, documentation |
| **Policy Gap** | No standard/guideline exists | Create and enforce policy |
| **Architecture Gap** | Missing abstraction/pattern | Refactor architecture |
| **Scaling Assumption** | Design didn't anticipate growth | Redesign for scale |
| **Concurrency Gap** | Single-thread thinking in distributed | Add synchronization |

---

## Anti-Patterns in 5-Whys

### Anti-Pattern 1: The Blame Game

```text
❌ Wrong:
Why 5: Developer didn't test properly

✓ Right:
Why 5: No automated test coverage for this scenario
```

### Anti-Pattern 2: The Vendor Excuse

```text
❌ Wrong:
Why 5: Third-party API is unreliable

✓ Right:
Why 5: No retry/fallback for external dependencies
```

### Anti-Pattern 3: The Resource Excuse

```text
❌ Wrong:
Why 5: We don't have time to do it right

✓ Right:
Why 5: Technical debt not prioritized in planning
```

### Anti-Pattern 4: The Complexity Excuse

```text
❌ Wrong:
Why 5: The system is too complex

✓ Right:
Why 5: No documentation/tests for complex interactions
```

---

## Template for Software Issues

```markdown
## 5-Whys: [Issue Title]

### Problem
- **Symptom:** [What users/monitoring saw]
- **Time:** [When detected]
- **Duration:** [How long]
- **Impact:** [Users/revenue affected]

### Analysis

| Why | Question | Answer | Evidence |
|-----|----------|--------|----------|
| 1 | Why did [symptom]? | | Logs/metrics |
| 2 | Why did [Why1]? | | Code/config |
| 3 | Why did [Why2]? | | History/commits |
| 4 | Why did [Why3]? | | Process/docs |
| 5 | Why did [Why4]? | | Policy/culture |

### Root Cause
- **Category:** [Design/Process/Knowledge/Policy/Architecture]
- **Statement:** [One sentence]

### Actions
| Priority | Action | Owner | Status |
|----------|--------|-------|--------|
| P0 | [Immediate fix] | | |
| P1 | [Prevention] | | |
| P2 | [Detection] | | |
```
