const fs = require('fs');
const path = require('path');

async function runBitbucketReview() {
  const {
    BITBUCKET_WORKSPACE,
    BITBUCKET_REPO_SLUG,
    BITBUCKET_PULL_REQUEST_ID,
    BITBUCKET_API_TOKEN,
    ANTHROPIC_API_KEY,
    REVIEW_TYPE = 'general', // hygiene, security, general
    LANGUAGE = 'auto',       // typescript, python, flutter, swift, bash, auto
    ORCHESTRATOR_PATH = '.'  // Path to the ai-orchestrator repo (e.g. ./.ai-orchestrator)
  } = process.env;

  if (!ANTHROPIC_API_KEY) throw new Error('ANTHROPIC_API_KEY is missing');
  if (!BITBUCKET_API_TOKEN) throw new Error('BITBUCKET_API_TOKEN is missing');

  if (!BITBUCKET_PULL_REQUEST_ID) {
    console.log('BITBUCKET_PULL_REQUEST_ID not found. This script only runs on Pull Request pipelines. Skipping review.');
    return;
  }

  console.log(`Starting ${REVIEW_TYPE} review for PR #${BITBUCKET_PULL_REQUEST_ID} in ${BITBUCKET_REPO_SLUG}...`);

  // 1. Language Auto-Detection
  let detectedLang = LANGUAGE;
  if (detectedLang === 'auto') {
    if (fs.existsSync('tsconfig.json') || fs.existsSync('package.json')) detectedLang = 'typescript';
    else if (fs.existsSync('pyproject.toml') || fs.existsSync('requirements.txt')) detectedLang = 'python';
    else if (fs.existsSync('pubspec.yaml')) detectedLang = 'flutter';
    else if (fs.existsSync('Package.swift')) detectedLang = 'swift';
    else detectedLang = 'general';
    console.log(`Auto-detected language: ${detectedLang}`);
  }

  const authHeader = `Bearer ${BITBUCKET_API_TOKEN}`;

  // 2. Fetch PR Diff from Bitbucket
  console.log('Fetching PR diff...');
  const diffUrl = `https://api.bitbucket.org/2.0/repositories/${BITBUCKET_WORKSPACE}/${BITBUCKET_REPO_SLUG}/pullrequests/${BITBUCKET_PULL_REQUEST_ID}/diff`;
  const diffResponse = await fetch(diffUrl, {
    headers: { 'Authorization': authHeader }
  });

  if (!diffResponse.ok) {
    const error = await diffResponse.text();
    throw new Error(`Failed to fetch diff from Bitbucket: ${error}`);
  }
  const prDiff = await diffResponse.text();

  if (!prDiff || prDiff.trim().length === 0) {
    console.log('No changes detected in the diff. Skipping review.');
    return;
  }

  // 3. Load System Prompt from reviewer.md and plugin commands
  const agentPath = path.join(ORCHESTRATOR_PATH, 'agents/reviewer.md');
  const pluginCmdPath = path.join(ORCHESTRATOR_PATH, 'plugins/reviewer/commands/review.md');

  if (!fs.existsSync(agentPath)) throw new Error(`Agent file not found at ${agentPath}`);
  
  let agentInstructions = fs.readFileSync(agentPath, 'utf-8').replace(/^---[\s\S]*?---/, '').trim();
  let pluginInstructions = fs.existsSync(pluginCmdPath) ? fs.readFileSync(pluginCmdPath, 'utf-8').trim() : '';

  const systemPrompt = `
You are the **Rigorous Code Reviewer**. You are a CI audit tool designed for strict enforcement of project standards.

### CORE MISSION & RULES
${agentInstructions}

### TACTICAL REVIEW STEPS
${pluginInstructions}

### FINAL AUTHORITY
The standards provided in the "CONSIDER THESE STANDARDS" section are PROJECT LAW. 
Any deviation from them is a CRITICAL violation. 
Your tone must be professional, concise, and direct.
`;

  // 4. Load Standards Context
  let standardsContext = '';
  if (REVIEW_TYPE === 'hygiene') {
    const standardsFile = path.join(ORCHESTRATOR_PATH, `skills/${detectedLang}-code-standarts.md`);
    if (fs.existsSync(standardsFile)) {
      standardsContext = fs.readFileSync(standardsFile, 'utf-8');
    } else {
      console.warn(`Standards file not found: ${standardsFile}. Using general guidelines.`);
    }
  } else if (REVIEW_TYPE === 'security') {
    const securityFile = path.join(ORCHESTRATOR_PATH, 'skills/security-hardening/SKILL.md');
    if (fs.existsSync(securityFile)) {
      standardsContext = fs.readFileSync(securityFile, 'utf-8');
    }
  }

  // 5. Call Anthropic API
  console.log('Sending request to Anthropic Claude...');
  const prompt = `
Please review the following PR diff from Bitbucket.
Review Type: ${REVIEW_TYPE.toUpperCase()}
Target Language: ${detectedLang.toUpperCase()}

${standardsContext ? `CONSIDER THESE STANDARDS:\n${standardsContext}\n` : ''}

DIFF TO REVIEW:
\`\`\`diff
${prDiff}
\`\`\`

Strictly follow the output format specified in the system instructions.
Use the emoji formatting (❌ for issues, ✅ for no violations) as defined in the tactical steps.
Your verdict must start with "VERDICT: APPROVED" or "VERDICT: NEEDS CHANGES".
`;

  const anthropicResponse = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: {
      'x-api-key': ANTHROPIC_API_KEY,
      'anthropic-version': '2023-06-01',
      'content-type': 'application/json'
    },
    body: JSON.stringify({
      model: 'claude-3-5-sonnet-20241022',
      max_tokens: 8192,
      system: systemPrompt,
      messages: [
        { role: 'user', content: prompt }
      ]
    })
  });

  if (!anthropicResponse.ok) {
    const error = await anthropicResponse.text();
    throw new Error(`Anthropic API Error: ${error}`);
  }

  const result = await anthropicResponse.json();
  const reviewText = result.content[0].text;

  // 6. Post Comment to Bitbucket
  console.log('Review completed. Posting comment to Bitbucket...');
  const botName = `AI ${REVIEW_TYPE.charAt(0).toUpperCase() + REVIEW_TYPE.slice(1)} Bot`;
  const commentUrl = `https://api.bitbucket.org/2.0/repositories/${BITBUCKET_WORKSPACE}/${BITBUCKET_REPO_SLUG}/pullrequests/${BITBUCKET_PULL_REQUEST_ID}/comments`;
  
  const commentBody = {
    content: {
      raw: `### 🤖 ${botName} Review\n\n${reviewText}`
    }
  };

  const bbCommentResponse = await fetch(commentUrl, {
    method: 'POST',
    headers: {
      'Authorization': authHeader,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify(commentBody)
  });

  if (!bbCommentResponse.ok) {
    const error = await bbCommentResponse.text();
    console.error(`Bitbucket API Error (Comment): ${error}`);
  } else {
    console.log('Comment posted successfully.');
  }
}

runBitbucketReview().catch(err => {
  console.error('Error during Bitbucket review:', err.message);
  process.exit(1);
});
