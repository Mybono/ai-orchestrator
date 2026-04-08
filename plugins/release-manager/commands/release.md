Create a full release including changelog, GitHub release, and package publishing.

Load the following expertise before starting:

- [DevOps Agent](../../../agents/devops.md)
- [git-advanced](../../../skills/git-advanced/SKILL.md)

## Process

1. Verify build and tests pass for the target branch.
2. Generate/Update `CHANGELOG.md` based on commit history.
3. Commit version bump and changelog.
4. Create and push a git tag for the version.
5. Create a GitHub Release with the changelog summary (via `gh release create`).
6. (Optional) Run publishing scripts for npm, PyPI, or internal registries.

## Rules

- Never release if tests are failing.
- Ensure the changelog is clean and categorized (Features, Fixes, Breaking Changes).
- Use signed tags if the project requires them.
