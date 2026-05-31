Create a structured user story and save it to .claude/context/.

## Instructions

1. Ask the user: "Describe the feature in one sentence (who needs it and why):"

2. Based on the answer, generate a user story using this template:

   ```markdown
   # Story: <short title>

   ## User Story
   As a <user role>, I want <capability> so that <benefit>.

   ## Acceptance Criteria
   - [ ] <criterion 1 — testable and specific>
   - [ ] <criterion 2>
   - [ ] <criterion 3>

   ## Out of Scope
   - <what this story explicitly does NOT cover>

   ## Technical Notes
   <implementation hints, dependencies, risks>

   ## Estimate
   S (< 2h) / M (2–8h) / L (1–3d) / XL (> 3d): <your estimate with brief reason>
   ```

3. Derive a slug from the first 3 words of the story title (lowercase, hyphens). Save to `.claude/context/story_<slug>.md`.

4. Print the file path.
