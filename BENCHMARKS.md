# Commit Model Benchmarks

*Project: ai-orchestrator*

This document tracks execution times and quality for different local LLMs used by the `commit` role.

## Hardware Environment

- **Device**: Apple Silicon (M2 Pro / M5 Pro)
- **RAM**: 16GB - 24GB
- **Quantization**: IQ4_XS (for 14B models), Q4_K_M (for others)

## Benchmark Results (Test: Stage 12 files)

| Model | Total Time (with lint) | Ollama Gen Time | Quality / Accuracy | Verdict |
|-------|------------------------|-----------------|-------------------|---------|
| **Qwen 3.5 (0.8b)** | 45.4s | **~8s** | Concise but long (~120 chars). Typo: "Committs". | **The Speedrunner** |
| **Qwen 2.5 Coder (1.5b)** | 62.2s | ~21s | **Failed Rules.** No conventional commit format. | **The Failure** |
| **Qwen 2.5 Coder (7b)** | 61.5s | ~28s | **Perfection.** Followed all rules, exactly 61 chars. | **The Expert** |

## Reviewer Model Benchmarks (Test: Complex Diff + Standards)

| Model | Ollama Gen Time | Quality / Behavioral Observation | Verdict |
|-------|-----------------|----------------------------------|---------|
| **Qwen 3.5 (0.8b)** | 14.4s | **Hallucination.** Acted as a coder, ignored review format. | **Unusable** |
| **Qwen 2.5 Coder (1.5b)** | 6.3s | **Summary loop.** Just summarized the prompt text. | **Unusable** |
| **Qwen 2.5 Coder (7b)** | 27.0s | **Summary loop.** Better summary, but failed to review bugs. | **Unreliable** |
| **Qwen 2.5 Coder (14b GGUF)** | 54.2s | **Summary loop.** Hallucinated a "Conclusion" section. | **Unreliable** |

## Reviewer Model Benchmarks (Test: Coordinated Agent-Guided)

This test simulates the actual orchestration flow where the agent (Claude) acts as a coordinator, providing structured and focused prompts to the local model.

| Model | Ollama Gen Time | Behavior / Quality | Verdict |
|-------|-----------------|--------------------|---------|
| **Qwen 3.5 (0.8b)** | 14.4s | **Fail.** Produced empty output or hallucinated. | **Unusable** |
| **Qwen 2.5 Coder (1.5b)** | 2.1s | **Fail.** Requested the script (failed to see diff). | **Unusable** |
| **Qwen 2.5 Coder (7b)** | **4.2s** | **Perfect.** Followed format, provided instant verdict. | **EXPERT** |

## Critical Insights & Recommendations

### 1. The "Coordinator" Effect

The previous "Summary loop" seen in the 7b and 14b models was a result of poor prompt structure (Context Choking). When the agent provides a focused, structured prompt (distinguishing between instructions, standards, and code), the **7b model's performance improves by 6.5x** (27s down to 4s).

### 2. Model Tiering for Orchestration

- **Commit Role**: **Qwen 2.5 Coder (7b)** is the clear winner for quality/speed balance.
- **Reviewer Role**: **Qwen 2.5 Coder (7b)** is the clear winner when properly coordinated.
- **Triage/Pre-Review**:- **Logic/Reviewer**: These roles require a model to have high attention. On current hardware, **7b** is the sweet spot, but requires better prompt engineering to avoid the "summary loop."

### 3. The "Thinking" Penalty in 0.8B

During the Stress Test, the **0.8b (triage)** stage became a bottleneck, taking 81s for a 5-second task because the model's "Thinking" mode entered a circular reasoning loop.

- **Recommendation**: For roles that require instant, low-level identification (triage, simple intent), consider a model WITHOUT a forced thinking/COT mode, or limit its output tokens strictly.

### 4. Coordinated Efficiency

The total "Thinking + Generating" time for a complex Docker task (Plan -> Review -> Code -> Check -> Commit) was approximately **3 minutes** of pure LLM time. Given the high quality of the output (multi-stage Alpine build), this is a 10x-20x improvement over manual writing and debugging.

## Full Pipeline Stress Test: Docker Implementation (End-to-End)

| Stage | Model (Role) | Time | Quality / Behavioral Observation | Verdict |
|-------|--------------|------|----------------------------------|---------|
| **Triage** | 0.8b (triage) | 81s | Perfect JSON, but extreme latency due to "Thinking" overhead. | **Slow but Accurate** |
| **Planner** | 14b GGUF (planner) | 47s | High-quality multi-stage design on Alpine. Correct script paths. | **Expert Design** |
| **Pre-Review** | 7b (pre-reviewer) | 21s | Approved, but hallucinated missing multi-stage (which was present). | **Fast but Shallow** |
| **Coder** | 14b GGUF (coder) | 25s | Very stable logic. Followed multi-stage plan. Note: Built Ollama from source. | **High Confidence** |
| **Reviewer** | 7b (reviewer) | <1s | Instant approval. Very permissive but efficient for final sanity check. | **Ultra Fast** |
| **Commit** | 7b (commit) | 24s | Perfect conventional commit. Analyzed 13 staged files accurately. | **Production Ready** |

## Key Findings (Updated)

1. **Qwen 3.5 (0.8b)**: Uses a "Thinking" mode that adds significant overhead even for small tasks. While it starts generating fast, it occasionally loses track of character limits and makes linguistic errors.
2. **Qwen 2.5 Coder (7b)**: Though nearly 10x larger in parameters than the 0.8b model, it is the most well-rounded "Expert" for code-related tasks. It follows strict formatting instructions (Conventional Commits, character limits) perfectly.
3. **Fixed Overhead**: The `markdown_review.sh` (linting) adds a substantial (~35s) fixed delay for multi-file commits. This makes the difference between a 45s run and a 61s run feel marginal in actual use.

## Recommendation

As of April 2026, **Qwen 2.5 Coder (7b)** is the recommended default for the `commit` role on Apple Silicon M-series chips. It provides the best balance of reasoning depth and adherence to project standards.
