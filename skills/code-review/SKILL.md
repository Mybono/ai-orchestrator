---
name: code-review
description: |
  Provides comprehensive code review guidance for React 19, Vue 3, Rust, TypeScript, Java, Python, and C/C++.
  Helps catch bugs, improve code quality, and give constructive feedback.
  Use when: reviewing pull requests, conducting PR reviews, code review, reviewing code changes,
  establishing review standards, mentoring developers, architecture reviews, security audits,
  checking code quality, finding bugs, giving feedback on code.
---

# Code Review Excellence

Transform code reviews from gatekeeping to knowledge sharing through constructive feedback, systematic analysis, and collaborative improvement.

## When to Use This Skill

- Reviewing pull requests and code changes
- Establishing code review standards for teams
- Mentoring junior developers through reviews
- Conducting architecture reviews
- Creating review checklists and guidelines
- Improving team collaboration
- Reducing code review cycle time
- Maintaining code quality standards

## Core Principles

### 1. The Review Mindset

**Goals of Code Review:**

- Catch bugs and edge cases
- Ensure code maintainability
- Share knowledge across team
- Enforce coding standards
- Improve design and architecture
- Build team culture

**Not the Goals:**

- Show off knowledge
- Nitpick formatting (use linters)
- Block progress unnecessarily
- Rewrite to your preference

### 2. Effective Feedback

**Good Feedback is:**

- Specific and actionable
- Educational, not judgmental
- Focused on the code, not the person
- Balanced (praise good work too)
- Prioritized (critical vs nice-to-have)

```text
[BAD]  "This is wrong."
[GOOD] "This could cause a race condition when multiple users
        access simultaneously. Consider using a mutex here."

[BAD]  "Why didn't you use X pattern?"
[GOOD] "Have you considered the Repository pattern? It would
        make this easier to test. Here's an example: [link]"

[BAD]  "Rename this variable."
[GOOD] "[nit] Consider `userCount` instead of `uc` for
        clarity. Not blocking if you prefer to keep it."
```

### 3. Review Scope

**What to Review:**

- Logic correctness and edge cases
- Security vulnerabilities
- Performance implications
- Test coverage and quality
- Error handling
- Documentation and comments
- API design and naming
- Architectural fit

**What Not to Review Manually:**

- Code formatting (use Prettier, Black, etc.)
- Import organization
- Linting violations
- Simple typos

## Review Process

### Phase 1: Context Gathering (2-3 minutes)

Before diving into code, understand:

1. Read PR description and linked issue
2. Check PR size (>400 lines? Ask to split)
3. Review CI/CD status (tests passing?)
4. Understand the business requirement
5. Note any relevant architectural decisions

### Phase 2: High-Level Review (5-10 minutes)

1. **Architecture & Design** - Does the solution fit the problem?
   - For significant changes, consult [Architecture Review Guide](references/architecture-review-guide.md)
   - Check: SOLID principles, coupling/cohesion, anti-patterns
2. **Performance Assessment** - Are there performance concerns?
   - For performance-critical code, consult [Performance Review Guide](references/performance-review-guide.md)
   - Check: Algorithm complexity, N+1 queries, memory usage
3. **File Organization** - Are new files in the right places?
4. **Testing Strategy** - Are there tests covering edge cases?

### Phase 3: Line-by-Line Review (10-20 minutes)

For each file, check:

- **Logic & Correctness** - Edge cases, off-by-one, null checks, race conditions
- **Security** - Input validation, injection risks, XSS, sensitive data
- **Performance** - N+1 queries, unnecessary loops, memory leaks
- **Maintainability** - Clear names, single responsibility, comments

### Phase 4: Summary & Decision (2-3 minutes)

1. Summarize key concerns
2. Highlight what you liked
3. Make clear decision:
   - `[approve]` Approve
   - `[comment]` Comment (minor suggestions)
   - `[changes]` Request Changes (must address)
4. Offer to pair if complex

## Review Techniques

### Technique 1: The Checklist Method

Use checklists for consistent reviews. See [Security Review Guide](references/security-review-guide.md) for comprehensive security checklist.

### Technique 2: The Question Approach

Instead of stating problems, ask questions:

```text
[BAD]  "This will fail if the list is empty."
[GOOD] "What happens if `items` is an empty array?"

[BAD]  "You need error handling here."
[GOOD] "How should this behave if the API call fails?"
```

### Technique 3: Suggest, Don't Command

Use collaborative language:

```text
[BAD]  "You must change this to use async/await"
[GOOD] "Suggestion: async/await might make this more readable. What do you think?"

[BAD]  "Extract this into a function"
[GOOD] "This logic appears in 3 places. Would it make sense to extract it?"
```

### Technique 4: Differentiate Severity

Use labels to indicate priority:

- `[blocking]` - Must fix before merge
- `[important]` - Should fix, discuss if disagree
- `[nit]` - Nice to have, not blocking
- `[suggestion]` - Alternative approach to consider
- `[learning]` - Educational comment, no action needed
- `[praise]` - Good work, keep it up!

## Language-Specific Guides

Consult the corresponding detailed guide based on the language being reviewed:

| Language/Framework | Reference File | Key Topics |
|-------------------|----------------|------------|
| **React** | [React Guide](references/react.md) | Hooks, useEffect, React 19 Actions, RSC, Suspense, TanStack Query v5 |
| **Vue 3** | [Vue Guide](references/vue.md) | Composition API, reactivity system, Props/Emits, Watchers, Composables |
| **Rust** | [Rust Guide](references/rust.md) | Ownership/borrowing, Unsafe review, async code, error handling |
| **TypeScript** | [TypeScript Guide](references/typescript.md) | Type safety, async/await, immutability |
| **Python** | [Python Guide](references/python.md) | Mutable default arguments, exception handling, class attributes |
| **Java** | [Java Guide](references/java.md) | Java 17/21 features, Spring Boot 3, virtual threads, Stream/Optional |
| **Go** | [Go Guide](references/go.md) | Error handling, goroutine/channel, context, interface design |
| **C** | [C Guide](references/c.md) | Pointers/buffers, memory safety, UB, error handling |
| **C++** | [C++ Guide](references/cpp.md) | RAII, lifetimes, Rule of 0/3/5, exception safety |
| **CSS/Less/Sass** | [CSS Guide](references/css-less-sass.md) | Variable conventions, !important, performance, responsive design, compatibility |
| **Qt** | [Qt Guide](references/qt.md) | Object model, signals/slots, memory management, thread safety, performance |

## Additional Resources

- [Architecture Review Guide](references/architecture-review-guide.md) - Architecture design review guide (SOLID, anti-patterns, coupling)
- [Performance Review Guide](references/performance-review-guide.md) - Performance review guide (Web Vitals, N+1, complexity)
- [Common Bugs Checklist](references/common-bugs-checklist.md) - Common bugs checklist organized by language
- [Security Review Guide](references/security-review-guide.md) - Security review guide
- [Code Review Best Practices](references/code-review-best-practices.md) - Code review best practices
- [PR Review Template](assets/pr-review-template.md) - PR review comment template
- [Review Checklist](assets/review-checklist.md) - Quick reference checklist
