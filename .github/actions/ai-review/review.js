const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

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
    DIFF_FILE_PATH,
    AUTO_FIX = 'false',
    MAIN_BRANCH = 'main'
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

The standards provided in the "CONSIDER THESE STANDARDS" section are PROJECT LAW. 
Any deviation from them is a CRITICAL violation. 
Your tone must be professional, concise, and direct.

### AUTO-FIX MODE
If REVIEW_TYPE is "hygiene", at the end of your review, identify files that violate the standards and can be automatically fixed without changing business logic.
List them clearly at the very bottom in this exact format:
AUTOFIX_FILES: [filename1, filename2]
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
  let reviewText = result.content[0].text;

  // 6. Additional Checks based on REVIEW_TYPE
  if (REVIEW_TYPE === 'security') {
    console.log('Running contextual security audit...');
    const auditReport = await runSecurityAuditInternal(ANTHROPIC_API_KEY);
    if (auditReport) {
      reviewText += `\n\n---\n\n${auditReport}`;
    }
  } else if (REVIEW_TYPE === 'general') {
    console.log('Running test coverage check...');
    const testReport = await runTestCheckerInternal(ANTHROPIC_API_KEY);
    if (testReport) {
      reviewText += `\n\n---\n\n${testReport}`;
    }
  }

  // 7. Auto-Fix Logic
  const fixedFiles = [];
  if (REVIEW_TYPE === 'hygiene' && AUTO_FIX === 'true') {
    const autofixMatch = reviewText.match(/AUTOFIX_FILES: \[(.*?)\]/);
    if (autofixMatch) {
      const filesToFix = autofixMatch[1].split(',').map(f => f.trim().replace(/['"`]/g, '')).filter(f => f.length > 0);
      console.log(`AI identified ${filesToFix.length} files for auto-fix: ${filesToFix.join(', ')}`);
      
      for (const file of filesToFix) {
        if (fs.existsSync(file)) {
          console.log(`Applying auto-fix to ${file}...`);
          const originalCode = fs.readFileSync(file, 'utf-8');
          const fixedCode = await getFixedCode(file, originalCode, standardsContext, ANTHROPIC_API_KEY);
          if (fixedCode && fixedCode !== originalCode) {
            fs.writeFileSync(file, fixedCode);
            fixedFiles.push(file);
          }
        }
      }
    }
  }

  if (fixedFiles.length > 0) {
    reviewText += `\n\n✅ **Applied AI Auto-fixes to:**\n${fixedFiles.map(f => `- \`${f}\``).join('\n')}\n\n*Please review the automated commit and verify changes.*`;
  }

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

async function runSecurityAuditInternal(apiKey) {
  let auditJson;
  try {
    const output = execSync('npm audit --json', { encoding: 'utf-8', maxBuffer: 10 * 1024 * 1024 });
    auditJson = JSON.parse(output);
  } catch (err) {
    try {
      auditJson = JSON.parse(err.stdout.toString());
    } catch (e) { return null; }
  }

  const advisories = auditJson.vulnerabilities || auditJson.advisories;
  if (!advisories || Object.keys(advisories).length === 0) return null;

  const reportEntries = [];
  for (const [pkgName, info] of Object.entries(advisories)) {
    let usageContext = '';
    try {
      usageContext = execSync(`grep -r "from ['\\"]${pkgName}['\\"]" --include="*.ts" --include="*.js" . || true`, { encoding: 'utf-8' });
    } catch (err) { usageContext = 'No direct imports found.'; }

    const analysis = await analyzeVulnerability(pkgName, info, usageContext, apiKey);
    reportEntries.push(analysis);
  }

  return `### 🛡️ AI Security Audit (Contextual)\n\n${reportEntries.join('\n\n---\n\n')}`;
}

async function analyzeVulnerability(pkgName, info, context, apiKey) {
  const systemPrompt = `You are a specialized AppSec Auditor. Analyze if a dependency vulnerability is exploitable based on code usage. Verdicts: CRITICAL | HIGH | MEDIUM | LOW (Contextual).`;
  const prompt = `Package: ${pkgName}\nVulnerability Info: ${JSON.stringify(info)}\nUsage Context:\n${context}`;
  
  try {
    const response = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: { 'x-api-key': apiKey, 'anthropic-version': '2023-06-01', 'content-type': 'application/json' },
      body: JSON.stringify({
        model: 'claude-3-5-sonnet-20241022',
        max_tokens: 500,
        system: systemPrompt,
        messages: [{ role: 'user', content: prompt }]
      })
    });
    const data = await response.json();
    return `**Package: ${pkgName}**\n${data.content[0].text}`;
  } catch (err) { return `**Package: ${pkgName}**\nError during analysis.`; }
}

async function runTestCheckerInternal(apiKey) {
  const MAIN_BRANCH = process.env.MAIN_BRANCH || 'main';
  let modifiedFiles = [];
  try {
    const diffFiles = execSync(`git diff --name-only origin/${MAIN_BRANCH}...HEAD`, { encoding: 'utf-8' });
    modifiedFiles = diffFiles.split('\n').filter(f => f.trim().length > 0);
  } catch (err) { return null; }

  const sourceExtensions = ['.ts', '.js', '.py', '.swift', '.dart'];
  const testFilesMissing = [];

  for (const file of modifiedFiles) {
    if (!sourceExtensions.includes(path.extname(file))) continue;
    if (file.includes('.test.') || file.includes('.spec.') || file.includes('test_')) continue;
    if (!hasTestFile(file)) testFilesMissing.push(file);
  }

  if (testFilesMissing.length === 0) return null;

  const suspectFiles = [];
  for (const file of testFilesMissing) {
    const diff = execSync(`git diff origin/${MAIN_BRANCH}...HEAD -- "${file}"`, { encoding: 'utf-8' });
    if (await shouldHaveTest(file, diff, apiKey)) suspectFiles.push(file);
  }

  if (suspectFiles.length === 0) return null;

  return `### 🧪 Test Coverage Warning\nSignificant changes found without tests:\n${suspectFiles.map(f => `- \`${f}\``).join('\n')}`;
}

function hasTestFile(sourceFile) {
  const dir = path.dirname(sourceFile);
  const base = path.basename(sourceFile, path.extname(sourceFile));
  const ext = path.extname(sourceFile);
  const patterns = [path.join(dir, `${base}.test${ext}`), path.join(dir, `${base}.spec${ext}`), path.join(dir, '__tests__', `${base}${ext}`)];
  return patterns.some(p => fs.existsSync(p));
}

async function shouldHaveTest(filename, diff, apiKey) {
  const systemPrompt = `Analyze code diff. Answer YES if it requires a new unit test, NO if trivial (comments, renames).`;
  const prompt = `File: ${filename}\nDiff:\n${diff}\n\nRequires test? YES/NO`;
  try {
    const response = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: { 'x-api-key': apiKey, 'anthropic-version': '2023-06-01', 'content-type': 'application/json' },
      body: JSON.stringify({ model: 'claude-3-5-sonnet-20241022', max_tokens: 10, system: systemPrompt, messages: [{ role: 'user', content: prompt }] })
    });
    const data = await response.json();
    return data.content[0].text.trim().toUpperCase().includes('YES');
  } catch (err) { return true; }
}

async function getFixedCode(filename, code, standards, apiKey) {
  const systemPrompt = `You are the AI Code Fixer. Your mission is to fix hygiene and style violations according to the PROJECT LAW.
- Apply formatting, naming, and organizational rules.
- Do NOT change business logic or functionality.
- Output ONLY the updated raw code. No markdown formatting, no comments, no explanations.`;

  const prompt = `File: ${filename}\n\nSTANDARDS:\n${standards}\n\nORIGINAL CODE:\n${code}\n\nOutput only the fixed code:`;

  try {
    const response = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
        'content-type': 'application/json'
      },
      body: JSON.stringify({
        model: 'claude-3-5-sonnet-20241022',
        max_tokens: 8192,
        system: systemPrompt,
        messages: [{ role: 'user', content: prompt }]
      })
    });

    const data = await response.json();
    let fixedCode = data.content[0].text.trim();
    // Remove potential markdown fences if Claude ignored instructions
    fixedCode = fixedCode.replace(/^```[\w]*\n/, '').replace(/\n```$/, '');
    return fixedCode;
  } catch (err) {
    console.error(`Failed to fix ${filename}:`, err.message);
    return null;
  }
}

runReview().catch(err => {
  console.error(err);
  process.exit(1);
});
