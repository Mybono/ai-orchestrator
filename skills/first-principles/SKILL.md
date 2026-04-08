---
name: first-principles-thinking
description: >
  Systematically decompose complex problems into fundamental truths and reason up 
  from there, avoiding the trap of reasoning by analogy.
  Trigger when the user asks: "analyze from first principles", "第一性原理",
  "think from scratch", "is this the right approach", "challenge assumptions", 
  "проанализируй архитектуру", "правильно ли мы это делаем?", "есть вариант лучше?",
  or when making major architectural decisions.
---

# First Principles Thinking

A systematic approach to breaking down complex problems into basic elements and building them up again from the ground up, avoiding reliance on conventions or analogies.

## When to use

- Evaluating whether an architecture or design is truly optimal for the context.
- Questioning "best practices" that may not fit this specific project.
- Making foundational decisions with long-term impact (e.g., choice of core tech).
- Challenging inherited assumptions in legacy code or processes.
- Designing new systems without cargo-culting existing patterns.

## The Methodology

### Phase 1: Identify the Problem essence

Strip away implementation details to find the core job to be done:

- What fundamental outcome are we trying to achieve?
- If this system didn't exist, what would we actually need?

### Phase 2: Challenge All Assumptions

Identify and question every technical, business, and historical assumption:

- "Why was this decision made originally?"
- "Must we use this specific technology/pattern?"
- "Is this requirement actually a fixed constraint?"

### Phase 3: Establish Ground Truths

Identify irreducible facts that cannot be violated:

- Physical/Math constraints (latency, throughput limits).
- Fundamental business invariants.
- Core user needs.

### Phase 4: Reason Upward

Build the solution from ground truths only:

- Start with the minimal possible implementation.
- Add only what is strictly necessary to satisfy ground truths.
- Each addition must defend its complexity.

## Standard Output Format

```markdown
## First Principles Analysis: [Topic]

### 1. Problem Essence
**Core problem:** [Statement of fundamental need]
**Success criteria:** [Irreducible requirements]

### 2. Assumptions Challenged
| Assumption | Challenge | Verdict |
|------------|-----------|---------|
| [Assumption 1] | [Why question it] | [Discard/Keep/Modify] |

### 3. Ground Truths
- [Irreducible Fact 1]
- [Irreducible Fact 2]

### 4. Reasoning Chain
[Ground Truth] → [Minimal Step] → [Justified Addition] → [Final Solution]

### 5. Conclusion
**Recommended approach:** [Description]
**Key insight:** [What the analysis revealed]
```

## Anti-Patterns to Avoid

1. **The Analogy Trap:** "Company X does it this way, so we should too."
2. **The Legacy Trap:** "We've always done it this way."
3. **The Complexity Trap:** Adding layers of abstraction before they are fundamentally necessary.
