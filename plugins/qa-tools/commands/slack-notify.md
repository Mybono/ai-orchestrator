Send asynchronous status updates to Slack to maintain team visibility.

Load the following expertise before starting:

- [QA Orchestrator](../../../agents/qa-orchestrator.md)

## Process

1. Format the status message (title, list of items, status color).
2. Gather relevant metrics (passed/failed tests, build duration).
3. Identify the target channel or recipient.
4. Execute the notification through a webhook or Slack CLI.
5. Confirm delivery.

## Rules

- Don't send noisy notifications for every step; focus on major milestones (Success, Failure).
- Use clear visual indicators (emojis, blocks).
- Always include a link to the relevant CI/CD run or PR.
