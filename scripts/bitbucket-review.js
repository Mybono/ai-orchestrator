const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

async function runBitbucketReview() {
  const {
    BITBUCKET_WORKSPACE,
    BITBUCKET_REPO_SLUG,
    BITBUCKET_PULL_REQUEST_ID,
    BITBUCKET_API_TOKEN,
    ANTHROPIC_API_KEY,
    REVIEW_TYPE = 'general', // hygiene, security, general
    LANGUAGE = 'auto',       // typescript, python, flutter, swift, bash, auto
    ORCHESTRATOR_PATH = '.', // Path to the ai-orchestrator repo (e.g. ./.ai-orchestrator)
    AUTO_FIX = 'false',      // Set to 'true' to enable automatic hygiene fixes
    MAIN_BRANCH = 'main'
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
  let agentPath = path.join(ORCHESTRATOR_PATH, 'agents/reviewer.md');
  if (REVIEW_TYPE === 'devops') {
    agentPath = path.join(ORCHESTRATOR_PATH, 'agents/devops.md');
  }
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

### AUTO-FIX MODE
If REVIEW_TYPE is "hygiene", at the end of your review, identify files that violate the standards and can be automatically fixed without changing business logic.
List them clearly at the very bottom in this exact format:
AUTOFIX_FILES: [filename1, filename2]
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
  } else if (REVIEW_TYPE === 'devops') {
    const devopsSkills = [
      'skills/ci-cd-pipelines/SKILL.md',
      'skills/docker-best-practices/SKILL.md',
      'skills/aws-cloud-patterns/SKILL.md',
      'skills/devops-automation/SKILL.md'
    ];
    standardsContext = devopsSkills
      .map(file => path.join(ORCHESTRATOR_PATH, file))
      .filter(p => fs.existsSync(p))
      .map(p => `### ${path.basename(path.dirname(p))}\n${fs.readFileSync(p, 'utf-8')}`)
      .join('\n\n---\n\n');
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
    const testReport = await runTestCheckerInternal(ANTHROPIC_API_KEY, prDiff);
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

  // 6. Post Comment to Bitbucket
  console.log('Review completed. Posting comment to Bitbucket...');
  const botName = `AI ${REVIEW_TYPE.charAt(0).toUpperCase() + REVIEW_TYPE.slice(1)} Agent`;
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

runBitbucketReview().catch(err => {
  console.error('Error during Bitbucket review:', err.message);
  process.exit(1);
});
