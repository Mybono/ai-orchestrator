## Hardware Environment

- **Device**: Apple Silicon (M2 Pro / M5 Pro)
- **RAM**: 16GB - 24GB
- **Quantization**: IQ4_XS (for 14B models), Q4_K_M (for others)

## Full Pipeline Stress Test: Docker Implementation (End-to-End)

| Stage | Model (Role) | Time | Quality / Behavioral Observation | Verdict |
|-------|--------------|------|----------------------------------|---------|
| **Triage** | 0.8b (triage) | 81s | Perfect JSON, but extreme latency due to "Thinking" overhead. | **Slow but Accurate** |
| **Planner** | 14b GGUF (planner) | 47s | High-quality multi-stage design on Alpine. Correct script paths. | **Expert Design** |
| **Pre-Review** | 7b (pre-reviewer) | 21s | Approved, but hallucinated missing multi-stage (which was present). | **Fast but Shallow** |
| **Coder** | 14b GGUF (coder) | 25s | Very stable logic. Followed multi-stage plan. Note: Built Ollama from source. | **High Confidence** |
| **Reviewer** | 7b (reviewer) | <1s | Instant approval. Very permissive but efficient for final sanity check. | **Ultra Fast** |
| **Commit** | 7b (commit) | 24s | Perfect conventional commit. Analyzed 13 staged files accurately. | **Production Ready** |

## Embedding Model Benchmarks

| Model | Latency | Dimensions | Context Window | Quality | Verdict |
|-------|---------|------------|----------------|---------|---------|
| **nomic-embed-text** | **0.07s** | 768 | 8k | Baseline. Good for simple search. | **The Speedrunner** |
| **mxbai-embed-large** | 1.07s | **1024** | 512* | **Superior.** Much better for technical code RAG. | **EXPERT** |

*Note: MxBai often has a smaller context window (512) compared to Nomic (8k), but its reasoning within that window is deeper.

## Key Findings (Updated)

1. **Qwen 3.5 (0.8b)**: Uses a "Thinking" mode that adds significant overhead even for small tasks. While it starts generating fast, it occasionally loses track of character limits and makes linguistic errors.
2. | **Qwen 2.5 Coder (7b)** | **4.2s** | **Perfect.** Followed format, provided instant verdict. | **EXPERT** |
| **Llama 3.1 (8b)** | 13.7s | **Fail.** Hallucinated that diff content was missing. | **Unusable** |
| **Qwen 3 (8b)** | 26.0s | **Fail.** Hallucinated that diff content was missing. | **Unusable** |

## Cross-Model Triage/Commit Comparison

| Model | Triage Time | Triage Quality | Commit Time (pure gen) | Commit Quality |
|-------|-------------|----------------|------------------------|----------------|
| **Qwen 2.5 Coder (7b)** | ~15s | High (Expert) | ~15s | **Production-Ready** |
| **Llama 3.1 (8b)** | **~8s** | Medium (General) | **~2s** | Good (Conventional) |
| **Qwen 3 (8b)** | ~26s | High (Thinking) | ~8s | Minimalist |

## Critical Insights & Recommendations

### 1. The "Specialist" Advantage

Specialized "Coder" models (like **Qwen 2.5 Coder 7b**) have a significantly higher attention span for structured data like Git diffs. General-purpose models (Llama 3.1, Qwen 3) treat code diffs as chat context and often fail to "see" the data within the instructions.
3. **Fixed Overhead**: The `markdown_review.sh` (linting) adds a substantial (~35s) fixed delay for multi-file commits. This makes the difference between a 45s run and a 61s run feel marginal in actual use.
