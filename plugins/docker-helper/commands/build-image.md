Build a Docker image with best practices for caching, security, and size optimization.

Load the following expertise before starting:

- [docker-best-practices](../../../skills/docker-best-practices/SKILL.md)
- [DevOps Agent](../../../agents/devops.md)

## Steps

1. Read existing Dockerfile or suggest a template.
2. Analyze build context:
   - Check `.dockerignore`.
   - Identify base image and layers.
3. Build the image:
   - Use BuildKit: `DOCKER_BUILDKIT=1`.
   - Tag appropriately (`latest`, `version`, `git-sha`).
4. Verify results:
   - Report final image size.
   - Perform a basic smoke test.

## Rules

- Strictly follow [docker-best-practices](../../../skills/docker-best-practices/SKILL.md).
- Use specific base image tags, never `latest`.
- Use multi-stage builds.
- Run as non-root user.
