const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

async function runCiDebugger() {
  const {
    ANTHROPIC_API_KEY,
    BITBUCKET_PULL_REQUEST_ID,
    BITBUCKET_REPO_FULL_NAME,
    BITBUCKET_API_TOKEN,
    GITHUB_TOKEN,
    PR_NUMBER,
    REPO,
    ORCHESTRATOR_PATH = '.'
  } = process.env;

  const logFile = process.argv[2];
  if (!logFile || !fs.existsSync(logFile)) {
    console.error('Usage: node ci-debugger.js <path-to-log-file>');
    process.exit(1);
  }

  if (!ANTHROPIC_API_KEY) throw new Error('ANTHROPIC_API_KEY is missing');

  console.log(`Starting AI Failure Analysis for ${logFile}...`);

  // 1. Load context
  const agentPath = path.join(ORCHESTRATOR_PATH, 'agents/debugger.md');
  const skillPath = path.join(ORCHESTRATOR_PATH, 'skills/root-cause-analysis/SKILL.md');
  
  if (!fs.existsSync(agentPath)) throw new Error(`Agent not found at ${agentPath}`);
  
  const agentInstructions = fs.readFileSync(agentPath, 'utf-8').replace(/^---[\s\S]*?---/, '').trim();
  const skillInstructions = fs.existsSync(skillPath) ? fs.readFileSync(skillPath, 'utf-8').trim() : '';

  // 2. Smart Truncate Log
  const rawLog = fs.readFileSync(logFile, 'utf-8');
  const truncatedLog = getSmartLog(rawLog);

  // 3. Call Claude
  const systemPrompt = `
You are the **AI Debugger**. Your mission is to find the fundamental cause of CI failures.
${agentInstructions}

### GUIDING PRINCIPLES
${skillInstructions}
`;

  const prompt = `
The CI pipeline has failed. Analyze the logs below and provide a Root Cause Analysis.
Target Repository: ${BITBUCKET_REPO_FULL_NAME || REPO}

FAILING LOG:
\`\`\`text
${truncatedLog}
\`\`\`

PROPOSE:
1. **The Root Cause**: What exactly caused the failure?
2. **Impact**: How many systems/modules are affected?
3. **Recommended Fix**: Provide a code snippet if possible.
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
      max_tokens: 4096,
      system: systemPrompt,
      messages: [{ role: 'user', content: prompt }]
    })
  });

  if (!anthropicResponse.ok) {
    const error = await anthropicResponse.text();
    throw new Error(`Anthropic API Error: ${error}`);
  }

  const result = await anthropicResponse.json();
  const analysisReport = result.content[0].text;

  // 4. Post to PR
  const commentBody = `### 🚨 AI Root Cause Analysis\n\n${analysisReport}`;
  
  if (BITBUCKET_PULL_REQUEST_ID) {
    await postToBitbucket(commentBody, BITBUCKET_REPO_FULL_NAME, BITBUCKET_PULL_REQUEST_ID, BITBUCKET_API_TOKEN);
  } else if (GITHUB_TOKEN && PR_NUMBER) {
    await postToGitHub(commentBody, REPO, PR_NUMBER, GITHUB_TOKEN);
  } else {
    console.log('--- ANALYSIS RESULT ---\n', analysisReport);
  }
}

function getSmartLog(log) {
  const lines = log.split('\n');
  if (lines.length <= 500) return log;

  // Try to find the first large error block
  const errorIndex = lines.findIndex(l => 
    l.toLowerCase().includes('error') || 
    l.toLowerCase().includes('failed') || 
    l.toLowerCase().includes('exception')
  );

  const start = Math.max(0, errorIndex - 50);
  const end = Math.min(lines.length, start + 400);
  
  return `... (truncated) ...\n${lines.slice(start, end).join('\n')}\n... (truncated) ...`;
}

async function postToBitbucket(body, repo, prId, token) {
  console.log('Posting analysis to Bitbucket...');
  const url = `https://api.bitbucket.org/2.0/repositories/${repo}/pullrequests/${prId}/comments`;
  const response = await fetch(url, {
    method: 'POST',
    headers: { 'Authorization': `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ content: { raw: body } })
  });
  if (!response.ok) console.error('Bitbucket API Error:', await response.text());
}

async function postToGitHub(body, repo, prNumber, token) {
  console.log('Posting analysis to GitHub...');
  const url = `https://api.github.com/repos/${repo}/issues/${prNumber}/comments`;
  const response = await fetch(url, {
    method: 'POST',
    headers: { 'Authorization': `Bearer ${token}`, 'Accept': 'application/vnd.github.v3+json', 'Content-Type': 'application/json' },
    body: JSON.stringify({ body })
  });
  if (!response.ok) console.error('GitHub API Error:', await response.text());
}

runCiDebugger().catch(err => {
  console.error('Error during failure analysis:', err.message);
  process.exit(1);
});
