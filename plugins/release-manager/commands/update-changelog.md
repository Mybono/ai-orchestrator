Regenerate or update the CHANGELOG.md file based on the git commit history.

Load the following expertise before starting:
- [DevOps Agent](../../../agents/devops.md)
- [git-advanced](../../../skills/git-advanced/SKILL.md)

## Process

1. Verify that `git-cliff` is installed in the system environment.
2. Check for the existence of `cliff.toml` configuration in the project root.
3. Run the generator:
   ```bash
   git-cliff --config cliff.toml -o CHANGELOG.md
   ```
4. If there are new entries, stage the `CHANGELOG.md` file.
5. Provide a summary of the newly added changes.

## Rules

- Do not commit the changes directly; let the user or the commit script handle the staged file.
- If `cliff.toml` is missing, recommend creating one based on project standards.
- Ensure the changelog uses Conventional Commits formatting.
