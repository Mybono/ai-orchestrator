# Bitbucket Pipelines Integration Guide

This guide explains how to integrate the **AI PR Review System** into your Bitbucket repositories.

## 🔑 Prerequisites

1. **Anthropic API Key**: A central API key for your organization.
2. **Bitbucket Access Token**:
    * Go to **Repository settings** > **Access tokens**.
    * Create a new token with `Pull request: Write` permissions.
3. **Repository Variables**:
    In each repository, go to **Repository settings** > **Pipelines** > **Repository variables** and add:
    * `ANTHROPIC_API_KEY`: Your Claude API key (Secured).
    * `BITBUCKET_API_TOKEN`: The access token created above (Secured).

## 🚀 Setup

Add the following to your `bitbucket-pipelines.yml` file:

```yaml
definitions:
  steps:
    - step: &ai-review-step
        name: AI PR Review
        image: node:20
        script:
          # Clone the orchestrator repo at a specific version (v1.0.4)
          - git clone --branch v1.0.4 --depth 1 https://github.com/Mybono/ai-orchestrator.git .ai-orchestrator
          - export ORCHESTRATOR_PATH=./.ai-orchestrator
          - node .ai-orchestrator/scripts/bitbucket-review.js
        services:
          - docker

pipelines:
  pull-requests:
    '**':
      - parallel:
          - step:
              <<: *ai-review-step
              name: "AI Hygiene Bot (Auto-Fix)"
              env:
                REVIEW_TYPE: "hygiene"
                AUTO_FIX: "true" # Enable automatic fixes
              script:
                - git clone --branch v1.0.4 --depth 1 https://github.com/Mybono/ai-orchestrator.git .ai-orchestrator
                - export ORCHESTRATOR_PATH=./.ai-orchestrator
                - node .ai-orchestrator/scripts/bitbucket-review.js
                # Setup git for auto-commit
                - git config user.name "AI Orchestrator"
                - git config user.email "ai-bot@mybono.com"
                # Check for changes and push
                - |
                  if ! git diff --quiet; then
                    git add .
                    git commit -m "style: AI suggested hygiene fixes"
                    git push origin HEAD:${BITBUCKET_BRANCH}
                  fi
          - step:
              <<: *ai-review-step
              name: "AI Security Bot"
              env:
                REVIEW_TYPE: "security"
          - step:
              <<: *ai-review-step
              name: "AI Logic Review"
              env:
                REVIEW_TYPE: "general"
          - step:
              <<: *ai-review-step
              name: "AI DevOps Bot"
              condition:
                changesets:
                  includePaths:
                    - "**/Dockerfile"
                    - "bitbucket-pipelines.yml"
                    - "infrastructure/**"
                    - "terraform/**"
              env:
                REVIEW_TYPE: "devops"
```

## ⚙️ Configuration Variables

The script automatically uses these built-in Bitbucket variables:

* `BITBUCKET_WORKSPACE`
* `BITBUCKET_REPO_SLUG`
* `BITBUCKET_PULL_REQUEST_ID`

Custom environment variables you can set per step:

* `REVIEW_TYPE`: `hygiene`, `security`, or `general` (default).
* `LANGUAGE`: `typescript`, `python`, `flutter`, `swift`, `bash`. If not set, the script will auto-detectbased on files like `tsconfig.json` or `pubspec.yaml`.

## 🤖 Bot Identities

The review will appear as a comment in the PR from the user associated with the `BITBUCKET_APP_PASSWORD`. Each comment is clearly labeled:

* **AI Hygiene Bot Review**
* **AI Security Bot Review**
* **AI General Review**
