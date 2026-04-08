Optimize an existing Dockerfile for smaller images, faster builds, and better security.

Load the following expertise before starting:

- [docker-best-practices](../../../skills/docker-best-practices/SKILL.md)
- [DevOps Agent](../../../agents/devops.md)

## Steps

1. Analyze the current Dockerfile instruction by instruction.
2. Identify optimization opportunities:
   - Base image selection (Alpine/distroless).
   - Layer reduction (combining RUNs).
   - Cache optimization (ordering).
   - Multi-stage build conversion.
3. Apply security hardening:
   - Specific tags.
   - Non-root USER.
   - Health checks.
4. Compare before/after sizes and build performance.

## Rules

- Follow the [docker-best-practices](../../../skills/docker-best-practices/SKILL.md) checklist.
- Test the optimized image before recommending changes.
- Prioritize security over marginal size gains.
