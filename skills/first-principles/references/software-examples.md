# First Principles in Software Engineering: Examples

Case studies of how reasoning from fundamental truths can lead to better architectural decisions.

---

## Example 1: Choosing Between Monolith and Microservices

### The Analogy (Avoid this)

"Netflix and Uber use microservices for scalability, so our new e-commerce startup should start with them too."

### The First Principles Analysis

**1. Problem Essence:**
We need to deliver feature A and B to users sustainably.

**2. Challenging Assumptions:**

- *Assumption:* Microservices are required for scaling.
- *Challenge:* Does our expected traffic (e.g., 1k users/day) actually require independent scaling of components?
- *Verdict:* Discard. A single well-optimized server can handle 10k+ concurrent users.

**3. Ground Truths:**

- Distributed systems introduce network latency and partial failure modes.
- Deployment overhead increases with the number of independent units.
- Team communication is the primary bottleneck in engineering.

**4. Reasoning Upward:**

- Team is small (3 people).
- Deployment complexity should be minimal to maximize coding time.
- Network latency between services adds complexity (retries, timeouts).
- → Conclusion: Start with a **Modular Monolith**. It provides logical separation (Ground Truth 4) without the operational tax of microservices.

---

## Example 2: Database Storage Strategy (JSON vs. Relational)

### The Analogy (Avoid this)

"Schema-less is more flexible, let's use MongoDB for everything."

### The First Principles Analysis

**1. Problem Essence:**
Store and retrieve user profile data with 100% consistency.

**2. Challenging Assumptions:**

- *Assumption:* We need total flexibility for future fields.
- *Challenge:* How often do fundamental core profile fields (email, id) change?
- *Verdict:* Modify. Core fields are stable; only extended attributes are "flexible".

**3. Ground Truths:**

- Inconsistent data leads to bugs and manual cleanup costs.
- Relational integrity (Foreign Keys) is a mathematical guarantee at the engine level.
- Storage is cheap; computing (joins) has a cost.

**4. Reasoning Upward:**

- Most of our queries involve joining data.
- Data integrity is non-negotiable for our domain.
- → Conclusion: Use **PostgreSQL with a JSONB column**. Use relational columns for fixed, searchable fields to get engine-level integrity (Ground Truth 2) and JSONB for the truly experimental flexible fields.

---

## Example 3: Re-implementing Orchestrator Kernels

### The Analogy (Avoid this)

"Modern projects use Go or Rust for CLI tools because they are faster."

### The First Principles Analysis

**1. Problem Essence:**
Glue various local tools (git, ollama, grep, jq) into a cohesive workflow.

**2. Challenging Assumptions:**

- *Assumption:* Performance is the bottleneck.
- *Challenge:* Is the execution of the glue code (loops, variables) slower than the external calls (git, LLM API)?
- *Verdict:* Discard. 99.9% of time is spent waiting for the LLM or Git.

**3. Ground Truths:**

- External dependencies (runtimes like Node, Python) add friction to installation.
- Bash is the native language of the OS and already exists everywhere.
- Portability = Zero dependencies.

**4. Reasoning Upward:**

- Speed of development and zero-install footprint are higher priorities than millisecond execution speed.
- The logic is primarily calling other CLI tools.
- → Conclusion: Stick with **Bash and Coreutils**. It matches the fundamental need for zero-dependency glue (Ground Truth 3) perfectly.
