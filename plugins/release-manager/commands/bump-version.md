Bump the project version following semantic versioning rules based on changes since the last release.

Load the following expertise before starting:

- [DevOps Agent](../../../agents/devops.md)
- [git-advanced](../../../skills/git-advanced/SKILL.md)

## Process

1. Analyze commit history since the last tag/release using Conventional Commits patterns:
   - `feat` -> Minor version bump.
   - `fix` -> Patch version bump.
   - `BREAKING CHANGE` -> Major version bump.
2. Coordinate with existing version files (`package.json`, `pyproject.toml`, `VERSION`, etc.).
3. Update version strings across all relevant files.
4. Stage changes for commit.

## Rules

- Strictly follow Semantic Versioning (SemVer 2.0.0).
- If multiple types are present, use the most significant bump (Major > Minor > Patch).
- Ensure consistency across all configuration files.
