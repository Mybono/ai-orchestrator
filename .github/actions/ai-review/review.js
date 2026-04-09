const fs = require('fs');
const path = require('path');

async function runReview() {
  const {
    ANTHROPIC_API_KEY,
    PR_DIFF,
    REVIEW_TYPE, // hygiene, security, general
    LANGUAGE,    // typescript, python, flutter, swift, bash, general
    GITHUB_TOKEN,
    PR_NUMBER,
    REPO,        // owner/repo
    ORCHESTRATOR_PATH = './ai-orchestrator', // Path to standards repo
    DIFF_FILE_PATH
  } = process.env;

  let prDiff = PR_DIFF;
  if (!prDiff && DIFF_FILE_PATH && fs.existsSync(DIFF_FILE_PATH)) {
    prDiff = fs.readFileSync(DIFF_FILE_PATH, 'utf-8');
  }

  if (!ANTHROPIC_API_KEY) throw new Error('ANTHROPIC_API_KEY is missing');
  if (!prDiff) throw new Error('PR_DIFF and DIFF_FILE_PATH are missing');
  if (!GITHUB_TOKEN) throw new Error('GITHUB_TOKEN is missing');

  console.log(`Starting ${REVIEW_TYPE} review for ${LANGUAGE}...`);

  // 1. Load System Prompt from reviewer.md and plugin commands
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

  // 2. Load Standards Context
  let standardsContext = '';
  if (REVIEW_TYPE === 'hygiene') {
    const standardsFile = path.join(ORCHESTRATOR_PATH, `skills/${LANGUAGE}-code-standarts.md`);
    if (fs.existsSync(standardsFile)) {
      standardsContext = fs.readFileSync(standardsFile, 'utf-8');
    } else {
      console.warn(`Standards file not found: ${standardsFile}. Using general guidelines.`);
    }
  } else if (REVIEW_TYPE === 'security') {
    const securityFile = path.join(ORCHESTRATOR_PATH, 'skills/security-hardening/SKILL.md');
    standardsContext = fs.readFileSync(securityFile, 'utf-8');
  }

  // 3. Construct the message for Claude
  const prompt = `
Please review the following PR diff.
Review Type: ${REVIEW_TYPE.toUpperCase()}
Target Language: ${LANGUAGE.toUpperCase()}

${standardsContext ? `CONSIDER THESE STANDARDS:\n${standardsContext}\n` : ''}

DIFF TO REVIEW:
\`\`\`diff
${prDiff}
\`\`\`

Strictly follow the output format specified in the system instructions.
Use the emoji formatting (❌ for issues, ✅ for no violations) as defined in the tactical steps.
Your verdict must start with "VERDICT: APPROVED" or "VERDICT: NEEDS CHANGES".
`;

  // 4. Call Anthropic API
  const response = await fetch('https://api.anthropic.com/v1/messages', {
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

  if (!response.ok) {
    const error = await response.text();
    throw new Error(`Anthropic API Error: ${error}`);
  }

  const result = await response.json();
  const reviewText = result.content[0].text;

  // 5. Post to GitHub
  console.log('Review completed. Posting comment to GitHub...');
  const botName = `AI ${REVIEW_TYPE.charAt(0).toUpperCase() + REVIEW_TYPE.slice(1)} Bot`;
  const commentBody = `### 🤖 ${botName} Review\n\n${reviewText}`;

  const ghResponse = await fetch(`https://api.github.com/repos/${REPO}/issues/${PR_NUMBER}/comments`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${GITHUB_TOKEN}`,
      'Accept': 'application/vnd.github.v3+json',
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({ body: commentBody })
  });

  if (!ghResponse.ok) {
    const error = await ghResponse.text();
    console.error(`GitHub API Error: ${error}`);
  } else {
    console.log('Comment posted successfully.');
  }
}

runReview().catch(err => {
  console.error(err);
  process.exit(1);
});
