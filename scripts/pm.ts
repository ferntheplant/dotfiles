#!/usr/bin/env zx

import fs from 'node:fs/promises'
import path from 'node:path'
import os from 'node:os'
import { fileURLToPath } from 'node:url'
import net from 'node:net'
import { spawn } from 'node:child_process'
import { LinearClient, type WorkflowState } from '@linear/sdk'
import { $, argv, question, cd } from 'zx'

type Mode = 'start' | 'switch' | 'list' | 'status' | 'close' | 'review' | 'resolve'
type PullRequest = {
  number: number
  url: string
  isDraft: boolean
  state: string
  headRefName: string
  title: string
}
type Check = {
  name: string
  bucket: string
  state: string
  workflow?: string
  link?: string
}

const HOME = os.homedir()
const PLOUTOS_MAIN_DIR = path.join(HOME, 'withco', 'ploutos')
const WORKTREES_DIR = path.join(HOME, 'withco', 'ploutos-worktrees')
const REGISTRY_FILE = path.join(WORKTREES_DIR, '.registry.json')

const scriptDir = path.dirname(fileURLToPath(import.meta.url))
const dotfilesRoot = path.resolve(scriptDir, '..')

type Registry = {
  worktrees: Record<string, WorktreeEntry>
  nextPortOffset: number
}

type WorktreeEntry = {
  branch: string
  worktreePath: string
  ports: { cloud: number; site: number; frontend: number }
  deploymentName: string
  linearUrl: string
  createdAt: string
}

async function loadRegistry(): Promise<Registry> {
  try {
    const data = await fs.readFile(REGISTRY_FILE, 'utf8')
    return JSON.parse(data)
  } catch (e: any) {
    if (e.code === 'ENOENT') {
      return { worktrees: {}, nextPortOffset: 1 }
    }
    throw e
  }
}

async function saveRegistry(registry: Registry) {
  await fs.mkdir(WORKTREES_DIR, { recursive: true })
  await fs.writeFile(REGISTRY_FILE, JSON.stringify(registry, null, 2))
}

// ----------------------------------------------------------------------------
// TICKET RESOLUTION
// ----------------------------------------------------------------------------

async function resolveTicket(arg?: string): Promise<string> {
  if (arg) {
    return arg
  }
  if (process.env.ZELLIJ_SESSION_NAME) {
    const reg = await loadRegistry()
    if (reg.worktrees[process.env.ZELLIJ_SESSION_NAME]) {
      return process.env.ZELLIJ_SESSION_NAME
    }
  }
  const cwd = process.cwd()
  if (cwd.startsWith(WORKTREES_DIR)) {
    const rel = path.relative(WORKTREES_DIR, cwd)
    const ticketId = rel.split(path.sep)[0]
    if (ticketId) {
      const reg = await loadRegistry()
      if (reg.worktrees[ticketId]) {
        return ticketId
      }
    }
  }
  fail('Could not resolve ticket. Please provide a ticket ID as an argument.')
}

async function getWorktreePath(ticketId: string): Promise<string> {
  const reg = await loadRegistry()
  const entry = reg.worktrees[ticketId]
  if (!entry) {
    fail(`Ticket ${ticketId} not found in registry`)
  }
  return entry.worktreePath
}

// ----------------------------------------------------------------------------
// INITIALIZATION
// ----------------------------------------------------------------------------

await loadEnvFile(path.join(dotfilesRoot, '.env'))
const linearApiToken = getLinearApiToken()
const linearClient = linearApiToken ? new LinearClient({ apiKey: linearApiToken }) : null

const positionalArgs = [...argv._].map(String)
while (positionalArgs[0] && looksLikeScriptPath(positionalArgs[0])) {
  positionalArgs.shift()
}

const requestedMode = positionalArgs[0]?.toLowerCase() ?? ''
const helpRequested = requestedMode === '--help' || requestedMode === '-h' || argv.help === true || argv.h === true || requestedMode === ''
const dryRun = argv['dry-run'] === true || argv.dryRun === true

if (helpRequested || !isMode(requestedMode)) {
  console.log('Usage: pm <start|switch|list|status|close|review|resolve> [args]')
  console.log('  start [url]     - create branch, worktree, local backend, and zellij session (use --dry-run to preview)')
  console.log('  switch [ticket] - attach to an existing zellij session for a ticket')
  console.log('  list            - list all tracked worktrees and branches')
  console.log('  status [ticket] - verify PR checks and unresolved threads')
  console.log('  close [ticket]  - squash merge PR, remove worktree, delete local/remote branch, return to main')
  console.log('  review [ticket] - show unresolved PR review comments')
  console.log('  resolve <id>    - resolve a review thread by ID')
  process.exit(helpRequested ? 0 : 1)
}

const mode: Mode = requestedMode

if (mode === 'start') {
  await runStart(positionalArgs[1])
} else if (mode === 'switch') {
  await runSwitch(positionalArgs[1])
} else if (mode === 'list') {
  await runList()
} else if (mode === 'status') {
  const ticketId = await resolveTicket(positionalArgs[1])
  await runStatus(ticketId)
} else if (mode === 'review') {
  const ticketId = await resolveTicket(positionalArgs[1])
  await runReview(ticketId)
} else if (mode === 'resolve') {
  const threadId = positionalArgs[1]
  if (!threadId) {
    fail('Usage: pm resolve <thread-id>')
  }
  const ticketId = await resolveTicket() // Needs context just to ensure we're targeting the right repo
  await runResolve(ticketId, threadId)
} else if (mode === 'close') {
  const ticketId = await resolveTicket(positionalArgs[1])
  await runClose(ticketId)
}

// ----------------------------------------------------------------------------
// COMMANDS
// ----------------------------------------------------------------------------

async function runStart(linearUrl?: string) {
  if (!linearUrl) {
    linearUrl = await question('Linear URL: ')
    if (!linearUrl) fail('Linear ticket URL is required')
  }

  const ticketId = extractTicketId(linearUrl)
  if (!ticketId) fail('Could not extract ticket ID from URL')

  if (!await directoryExists(PLOUTOS_MAIN_DIR)) {
    fail(`Main ploutos directory not found at ${PLOUTOS_MAIN_DIR}`)
  }

  const reg = await loadRegistry()
  const existing = reg.worktrees[ticketId]
  const branchName = ticketId
  const worktreePath = existing?.worktreePath ?? path.join(WORKTREES_DIR, ticketId)
  const offset = existing ? Math.max(1, Math.floor((existing.ports.cloud - 3210) / 1000)) : reg.nextPortOffset
  const cloudPort = existing?.ports.cloud ?? 3210 + offset * 1000
  const sitePort = existing?.ports.site ?? 3211 + offset * 1000
  const frontendPort = existing?.ports.frontend ?? 5173 + offset * 1000
  const deploymentName = existing?.deploymentName ?? `local-withco-ploutos-${ticketId.toLowerCase()}`
  const effectiveLinearUrl = existing?.linearUrl ?? linearUrl

  console.log(`Setting up for ticket: ${ticketId}`)

  cd(PLOUTOS_MAIN_DIR)
  const localBranchExists = await hasLocalBranch(branchName)
  const remoteBranchExists = await hasRemoteBranch(branchName)
  const pr = await getBranchPr(branchName)
  const worktreeExists = await directoryExists(worktreePath)

  let commitTitle = pr?.title ?? ''
  const needsInitialBranchSetup = !localBranchExists && !remoteBranchExists
  if (needsInitialBranchSetup) {
    commitTitle = await question('Commit message (e.g., "feat: add new feature", "fix: resolve bug"): ')
    if (!commitTitle) fail('Conventional commit message is required')
    warnIfNonStandardConventionalCommit(commitTitle)
  } else if (!commitTitle) {
    commitTitle = await getHeadCommitTitle(branchName)
    if (!commitTitle) {
      commitTitle = await question('Commit message for PR title: ')
      if (!commitTitle) fail('Commit message is required when creating a PR')
    }
  }

  const needsPr = !pr
  const needsPush = localBranchExists && !remoteBranchExists
  const needsWorktree = !worktreeExists
  const needsBackendSetup = needsWorktree || !existing
  const needsBranchOrPrWork = needsInitialBranchSetup || needsPush || needsPr || (!localBranchExists && remoteBranchExists)

  console.log(`Branch: ${branchName}`)
  console.log(`Commit: ${commitTitle}`)

  if (dryRun) {
    console.log('')
    console.log('[dry-run] No changes will be made. Planned actions based on current state:')
    console.log(`[dry-run] state: localBranch=${localBranchExists}, remoteBranch=${remoteBranchExists}, pr=${pr ? `#${pr.number}` : 'missing'}, worktree=${worktreeExists ? 'present' : 'missing'}, registry=${existing ? 'present' : 'missing'}`)
    if (needsInitialBranchSetup) {
      console.log('[dry-run] create branch flow: checkout main, pull, create branch, empty commit, push')
      console.log('[dry-run] linear: assign issue and set In Progress')
    } else if (needsPush) {
      console.log(`[dry-run] push existing local branch to origin: ${branchName}`)
    }
    if (!localBranchExists && remoteBranchExists) {
      console.log(`[dry-run] create local branch from origin/${branchName}`)
    }
    if (needsPr) {
      const prBody = `Closes [${ticketId}](${effectiveLinearUrl})`
      console.log(`[dry-run] create PR: gh pr create --title "${commitTitle}" --body "${prBody}" --draft --base main --head ${branchName}`)
    }
    if (needsWorktree) {
      console.log(`[dry-run] create worktree: git worktree add ${worktreePath} ${branchName}`)
    }
    if (needsBackendSetup) {
      console.log('[dry-run] setup worktree backend: pnpm install, copy env files, patch .env/.mise.local/package.json ports, run backend in background, setup-local-backend.sh, pnpm e2e:import')
    } else {
      console.log('[dry-run] backend setup already completed according to registry; skipping')
    }
    const sessionExists = await hasZellijSession(ticketId)
    if (process.env.ZELLIJ_SESSION_NAME) {
      console.log(`[dry-run] zellij: currently in ${process.env.ZELLIJ_SESSION_NAME}; would instruct detach then pm switch ${ticketId}`)
    } else if (sessionExists) {
      console.log(`[dry-run] zellij: attach existing session ${ticketId}`)
    } else {
      console.log(`[dry-run] zellij: create new session ${ticketId} with ploutos.kdl`)
    }
    return
  }

  if (needsInitialBranchSetup) {
    await maybeSetLinearInProgress(ticketId)
  }

  if (needsBranchOrPrWork) {
    let stashed = false
    const hasChanges = await $`git status --porcelain`.quiet()
    try {
      if (hasChanges.stdout.trim()) {
        console.log('Stashing current changes in main worktree...')
        await $`git stash push -m "WIP: switching to ${ticketId}"`
        stashed = true
      }

      await $`git checkout main`
      await $`git pull origin main`

      if (needsInitialBranchSetup) {
        console.log(`Creating branch: ${branchName}`)
        await $`git checkout -b ${branchName}`

        console.log('Creating initial commit...')
        await $`git commit --allow-empty -m ${commitTitle}`

        console.log('Pushing to remote...')
        await $`git push -u origin ${branchName}`
      } else {
        if (!localBranchExists && remoteBranchExists) {
          console.log(`Creating local branch ${branchName} from origin/${branchName}...`)
          await $`git fetch origin ${branchName}:${branchName}`
        }
        if (needsPush) {
          console.log(`Pushing existing branch ${branchName} to origin...`)
          await $`git push -u origin ${branchName}`
        }
      }

      if (needsPr) {
        console.log('Creating draft PR...')
        const prBody = `Closes [${ticketId}](${effectiveLinearUrl})`
        await $`gh pr create --title ${commitTitle} --body ${prBody} --draft --base main --head ${branchName}`
      }
    } finally {
      await $`git checkout main`
      if (stashed) {
        console.log('Unstashing changes in main worktree...')
        const stashPop = await $`git stash pop`.nothrow()
        if (stashPop.exitCode !== 0) {
          console.warn('Warning: Could not automatically apply stashed changes. Resolve manually with `git stash list`.')
        }
      }
    }
  } else {
    console.log('Branch/PR already prepared; skipping git/PR setup step')
  }

  if (needsWorktree) {
    console.log(`Creating worktree at ${worktreePath}`)
    await $`git worktree add ${worktreePath} ${branchName}`
  } else {
    console.log(`Worktree already exists at ${worktreePath}; resuming setup`)
  }

  cd(worktreePath)
  console.log(`Using ports: frontend=${frontendPort}, cloud=${cloudPort}, site=${sitePort}`)
  if (needsBackendSetup) {
    console.log('Installing dependencies...')
    await $`pnpm install`

    console.log('Setting up env files...')
    await $`cp ${path.join(PLOUTOS_MAIN_DIR, '.env.local')} .`
    await $`cp ${path.join(PLOUTOS_MAIN_DIR, '.env.server')} .`
    await $`cp ${path.join(PLOUTOS_MAIN_DIR, 'e2e-convex-data.zip')} .`

    let envLocal = await fs.readFile('.env.local', 'utf8')
    envLocal = upsertEnvVar(envLocal, 'CONVEX_DEPLOYMENT', `local:${deploymentName}`)
    envLocal = upsertEnvVar(envLocal, 'VITE_CONVEX_URL', `http://127.0.0.1:${cloudPort}`)
    envLocal = upsertEnvVar(envLocal, 'VITE_CONVEX_SITE_URL', `http://127.0.0.1:${sitePort}`)
    await fs.writeFile('.env.local', envLocal)

    let envServer = await fs.readFile('.env.server', 'utf8')
    envServer = upsertEnvVar(envServer, 'SITE_URL', `localhost:${frontendPort}`)
    await fs.writeFile('.env.server', envServer)

    const miseConfigPath = '.mise.local.toml'
    const existingMiseConfig = await fs.readFile(miseConfigPath, 'utf8').catch((error: NodeJS.ErrnoException) => {
      if (error.code === 'ENOENT') return ''
      throw error
    })
    let miseConfig = upsertMiseEnvVar(existingMiseConfig, 'LOCAL_BACKEND_CLOUD_PORT', String(cloudPort))
    miseConfig = upsertMiseEnvVar(miseConfig, 'LOCAL_BACKEND_SITE_PORT', String(sitePort))
    miseConfig = upsertMiseEnvVar(miseConfig, 'LOCAL_FRONTEND_PORT', String(frontendPort))
    await fs.writeFile(miseConfigPath, miseConfig)

    const packageJsonRaw = await fs.readFile('package.json', 'utf8')
    const packageJson = JSON.parse(packageJsonRaw) as { scripts?: Record<string, string> }
    if (!packageJson.scripts?.['dev:frontend']) {
      fail('Could not find scripts.dev:frontend in package.json')
    }
    packageJson.scripts['dev:frontend'] = `vite --port ${frontendPort}`
    await fs.writeFile('package.json', `${JSON.stringify(packageJson, null, 2)}\n`)

    await bootstrapBackendThenSeed(worktreePath, cloudPort, sitePort)
  } else {
    console.log('Backend setup already completed; skipping env/bootstrap/import steps')
  }

  reg.worktrees[ticketId] = {
    branch: branchName,
    worktreePath,
    ports: { cloud: cloudPort, site: sitePort, frontend: frontendPort },
    deploymentName,
    linearUrl: effectiveLinearUrl,
    createdAt: existing?.createdAt ?? new Date().toISOString()
  }
  if (!existing) {
    reg.nextPortOffset = offset + 1
  }
  await saveRegistry(reg)

  console.log('✓ Setup complete!')
  console.log('Launching Zellij session...')

  if (process.env.ZELLIJ_SESSION_NAME) {
    console.log(`You are currently inside a Zellij session (${process.env.ZELLIJ_SESSION_NAME}).`)
    console.log(`Please detach (Ctrl+o d) and run: pm switch ${ticketId}`)
    return
  }

  const sessionExists = await hasZellijSession(ticketId)
  if (sessionExists) {
    await runZellijAttach(ticketId)
  } else {
    await runZellijCreate(ticketId)
  }
}

async function directoryExists(dirPath: string): Promise<boolean> {
  return fs.stat(dirPath).then((s) => s.isDirectory()).catch(() => false)
}

async function hasLocalBranch(branchName: string): Promise<boolean> {
  const result = await $`git show-ref --verify --quiet refs/heads/${branchName}`.nothrow()
  return result.exitCode === 0
}

async function hasRemoteBranch(branchName: string): Promise<boolean> {
  const result = await $`git ls-remote --heads origin ${branchName}`.nothrow()
  if (result.exitCode !== 0) {
    return false
  }
  return result.stdout.trim().length > 0
}

type BranchPr = { number: number; state: string; isDraft: boolean; url: string; title: string }

async function getBranchPr(branchName: string): Promise<BranchPr | null> {
  const result = await $`gh pr list --state all --head ${branchName} --json number,state,isDraft,url,title --limit 1`.nothrow()
  if (result.exitCode !== 0 || !result.stdout.trim()) {
    return null
  }

  try {
    const parsed = JSON.parse(result.stdout) as BranchPr[]
    return parsed[0] ?? null
  } catch {
    return null
  }
}

function warnIfNonStandardConventionalCommit(message: string) {
  const commitTypes = ['feat', 'fix', 'docs', 'style', 'refactor', 'test', 'chore', 'perf', 'ci', 'build', 'revert']
  const commitType = message.split(':')[0]?.trim()
  if (!commitTypes.includes(commitType)) {
    console.warn(`Warning: ${commitType} is not a standard conventional commit type`)
    console.warn(`Standard types: ${commitTypes.join(', ')}`)
  }
}

async function getHeadCommitTitle(branchName: string): Promise<string> {
  const hasLocal = await hasLocalBranch(branchName)
  if (!hasLocal) {
    const hasRemote = await hasRemoteBranch(branchName)
    if (hasRemote) {
      await $`git fetch origin ${branchName}:${branchName}`
    }
  }

  const result = await $`git log -1 --pretty=%s ${branchName}`.nothrow()
  if (result.exitCode !== 0) {
    return ''
  }
  return result.stdout.trim()
}

async function hasZellijSession(sessionName: string): Promise<boolean> {
  const result = await $`zellij list-sessions -n`.nothrow()
  if (result.exitCode !== 0) {
    return false
  }

  return result.stdout
    .split('\n')
    .map((line) => line.trim())
    .filter(Boolean)
    .some((line) => line === sessionName || line.startsWith(`${sessionName} `))
}

async function runZellijAttach(sessionName: string, createIfMissing = false) {
  const commandText = createIfMissing ? `zellij attach ${sessionName} -c` : `zellij attach ${sessionName}`
  if (!process.stdin.isTTY || !process.stdout.isTTY) {
    console.log(`Skipping zellij attach in non-interactive terminal. Run manually: ${commandText}`)
    return
  }

  const result = createIfMissing
    ? await $`zellij attach ${sessionName} -c`.quiet().nothrow()
    : await $`zellij attach ${sessionName}`.quiet().nothrow()

  if (result.exitCode !== 0) {
    const details = (result.stderr || result.stdout || '').trim()
    if (details.includes('could not get terminal attribute') || details.includes('EOPNOTSUPP')) {
      console.warn(`Zellij attach failed due to terminal limitations. Run manually: ${commandText}`)
      return
    }
    fail(`Failed to attach zellij session ${sessionName}${details ? `:\n${details}` : ''}`)
  }
}

async function runZellijCreate(sessionName: string) {
  const commandText = `zellij attach ${sessionName} -c`
  if (!process.stdin.isTTY || !process.stdout.isTTY) {
    console.log(`Skipping zellij start in non-interactive terminal. Run manually: ${commandText}`)
    return
  }

  const result = await $`zellij attach ${sessionName} -c`.quiet().nothrow()
  if (result.exitCode !== 0) {
    const details = (result.stderr || result.stdout || '').trim()
    if (details.includes('could not get terminal attribute') || details.includes('EOPNOTSUPP')) {
      console.warn(`Zellij start failed due to terminal limitations. Run manually: ${commandText}`)
      return
    }
    fail(`Failed to start zellij session ${sessionName}${details ? `:\n${details}` : ''}`)
  }
}

async function waitForTcpPort(host: string, port: number, timeoutMs: number): Promise<void> {
  const startedAt = Date.now()
  while (Date.now() - startedAt < timeoutMs) {
    const isOpen = await new Promise<boolean>((resolve) => {
      const socket = net.createConnection({ host, port })
      socket.setTimeout(1000)
      socket.once('connect', () => {
        socket.end()
        resolve(true)
      })
      socket.once('timeout', () => {
        socket.destroy()
        resolve(false)
      })
      socket.once('error', () => {
        resolve(false)
      })
    })

    if (isOpen) {
      return
    }
    await new Promise((resolve) => setTimeout(resolve, 1000))
  }

  fail(`Timed out waiting for backend on ${host}:${port}`)
}

async function bootstrapBackendThenSeed(worktreePath: string, cloudPort: number, sitePort: number) {
  console.log('Starting local backend in background...')
  const backendLogPath = path.join(worktreePath, '.pm-backend.log')
  const logHandle = await fs.open(backendLogPath, 'a')
  const backendProcess = spawn(
    'mise',
    [
      'x',
      'node@20',
      '--',
      'pnpm',
      'dev:backend',
      '--configure=existing',
      '--team=withco',
      '--project=ploutos',
      '--dev-deployment=local',
      `--local-cloud-port=${cloudPort}`,
      `--local-site-port=${sitePort}`,
    ],
    {
      cwd: worktreePath,
      detached: true,
      stdio: ['ignore', logHandle.fd, logHandle.fd],
    },
  )
  await logHandle.close()
  backendProcess.unref()

  if (!backendProcess.pid) {
    fail('Could not start backend process')
  }

  try {
    await waitForTcpPort('127.0.0.1', cloudPort, 120_000)

    console.log('Setting server env vars...')
    const setupResult = await $`./scripts/setup-local-backend.sh`.quiet().nothrow()
    if (setupResult.exitCode !== 0) {
      const details = (setupResult.stderr || setupResult.stdout || '').trim()
      fail(`setup-local-backend.sh failed${details ? `:\n${details}` : ''}`)
    }

    console.log('Importing e2e data...')
    const importResult = await $`pnpm e2e:import`.quiet().nothrow()
    if (importResult.exitCode !== 0) {
      const details = (importResult.stderr || importResult.stdout || '').trim()
      fail(`pnpm e2e:import failed${details ? `:\n${details}` : ''}`)
    }
  } finally {
    try {
      process.kill(-backendProcess.pid, 'SIGTERM')
    } catch {
      try {
        process.kill(backendProcess.pid, 'SIGTERM')
      } catch {
        // no-op
      }
    }
  }
}

async function runSwitch(ticketId?: string) {
  if (!ticketId) fail('Usage: pm switch <ticket-id>')
  const worktreePath = await getWorktreePath(ticketId)

  if (!await fs.stat(worktreePath).then(s => s.isDirectory()).catch(() => false)) {
    fail(`Worktree not found at ${worktreePath}`)
  }

  if (process.env.ZELLIJ_SESSION_NAME) {
    console.log(`You are inside Zellij session ${process.env.ZELLIJ_SESSION_NAME}.`)
    console.log(`Zellij does not support nested sessions or switching from within.`)
    console.log(`Please detach (Ctrl+o d) first, then run: pm switch ${ticketId}`)
    process.exit(1)
  }

  cd(worktreePath)
  await runZellijAttach(ticketId, true)
}

async function runList() {
  const reg = await loadRegistry()
  const entries = Object.entries(reg.worktrees).sort(([a], [b]) => a.localeCompare(b))

  if (entries.length === 0) {
    console.log('No tracked worktrees found.')
    return
  }

  console.log(`Tracked worktrees (${entries.length}):`)
  for (const [ticketId, entry] of entries) {
    const frontend = entry.ports.frontend
    const cloud = entry.ports.cloud
    const site = entry.ports.site
    console.log(`- ${ticketId}`)
    console.log(`  branch: ${entry.branch}`)
    console.log(`  path: ${entry.worktreePath}`)
    console.log(`  ports: frontend=${frontend}, cloud=${cloud}, site=${site}`)
    console.log(`  deployment: local:${entry.deploymentName}`)
  }
}

async function runStatus(ticketId: string) {
  const worktreePath = await getWorktreePath(ticketId)
  cd(worktreePath)

  const pr = await getCurrentBranchPr()
  const issues: string[] = []

  if (pr.state !== 'OPEN') {
    issues.push(`PR #${pr.number} is not open (state: ${pr.state})`)
  }
  if (pr.isDraft) {
    issues.push(`PR #${pr.number} is still in draft mode`)
  }

  console.log(`Checking required CI for PR #${pr.number}...`)
  const checksResult = await $`gh pr checks ${pr.number} --required --json name,bucket,state,workflow,link`.nothrow()
  const checks = parseChecks(checksResult.stdout)

  if (checksResult.exitCode !== 0 && checks.length === 0) {
    fail('Could not fetch PR checks. Ensure GitHub CLI auth is valid and the PR exists.')
  }

  const nonPassingChecks = checks.filter((check) => check.bucket !== 'pass')
  if (nonPassingChecks.length > 0) {
    const failingNames = nonPassingChecks.map((check) => `${check.name} (${check.bucket})`).join(', ')
    issues.push(`Required checks are not all passing: ${failingNames}`)
  }

  console.log(`Checking unresolved review threads for PR #${pr.number}...`)
  const unresolvedThreads = await getUnresolvedThreadCount(pr.number)
  if (unresolvedThreads > 0) {
    issues.push(`PR has ${unresolvedThreads} unresolved review thread(s)`)
  }

  if (issues.length > 0) {
    console.error('PR status failed:')
    for (const issue of issues) {
      console.error(`- ${issue}`)
    }
    process.exit(1)
  }

  console.log(`✓ PR #${pr.number} is open and ready`)
  console.log('✓ Not draft')
  console.log(`✓ Required CI checks passing (${checks.length})`)
  console.log('✓ No unresolved review threads')
}

async function runReview(ticketId: string) {
  const worktreePath = await getWorktreePath(ticketId)
  cd(worktreePath)

  const prResult = await $`gh pr view --json number`.nothrow()
  if (prResult.exitCode !== 0 || !prResult.stdout.trim()) {
    console.log('No PR found for the current branch.')
    return
  }

  const { number: prNumber } = JSON.parse(prResult.stdout) as { number: number }

  const repoResult = await $`gh repo view --json nameWithOwner`.quiet()
  const nameWithOwner = (JSON.parse(repoResult.stdout) as { nameWithOwner?: string }).nameWithOwner

  if (!nameWithOwner || !nameWithOwner.includes('/')) {
    fail('Could not determine repository owner/name from gh CLI')
  }

  const [owner, name] = nameWithOwner.split('/')
  const query = `
    query($owner: String!, $name: String!, $number: Int!) {
      repository(owner: $owner, name: $name) {
        pullRequest(number: $number) {
          reviewThreads(first: 100) {
            nodes {
              id
              isResolved
              isOutdated
              path
              line
              comments(first: 50) {
                nodes {
                  author { login }
                  body
                  createdAt
                }
              }
            }
          }
        }
      }
    }
  `

  const result = await $`gh api graphql -f query=${query} -F owner=${owner} -F name=${name} -F number=${prNumber}`.nothrow()
  if (result.exitCode !== 0 || !result.stdout.trim()) {
    fail('Could not query PR review threads')
  }

  type ReviewComment = { author: { login: string }; body: string; createdAt: string }
  type ReviewThread = {
    id: string
    isResolved: boolean
    isOutdated: boolean
    path: string
    line: number | null
    comments: { nodes: ReviewComment[] }
  }

  const parsed = JSON.parse(result.stdout) as {
    data?: { repository?: { pullRequest?: { reviewThreads?: { nodes?: ReviewThread[] } } } }
  }

  const threads = parsed.data?.repository?.pullRequest?.reviewThreads?.nodes ?? []
  const unresolvedThreads = threads.filter((t) => !t.isResolved)

  if (unresolvedThreads.length === 0) {
    console.log(`PR #${prNumber} has no unresolved review comments.`)
    return
  }

  console.log(`PR #${prNumber} has ${unresolvedThreads.length} unresolved review thread(s):\\n`)

  for (const thread of unresolvedThreads) {
    const location = thread.line ? `${thread.path}:${thread.line}` : thread.path
    const outdatedLabel = thread.isOutdated ? ' [OUTDATED]' : ''
    console.log(`--- ${location}${outdatedLabel} ---\\nThread ID: ${thread.id}`)

    for (let i = 0; i < thread.comments.nodes.length; i++) {
      const comment = thread.comments.nodes[i]
      const body = stripBugbotLinks(comment.body)
      const isReply = i > 0
      const prefix = isReply ? '[REPLY] ' : ''
      console.log(`${prefix}@${comment.author.login}:`)
      console.log(body)
      console.log('')
    }
  }
}

async function runResolve(ticketId: string, threadId: string) {
  const worktreePath = await getWorktreePath(ticketId)
  cd(worktreePath)

  const mutation = `
    mutation($threadId: ID!) {
      resolveReviewThread(input: { threadId: $threadId }) {
        thread {
          id
          isResolved
        }
      }
    }
  `

  const result = await $`gh api graphql -f query=${mutation} -F threadId=${threadId}`.nothrow()
  if (result.exitCode !== 0) {
    const errorMsg = result.stderr || result.stdout
    fail(`Could not resolve review thread: ${errorMsg}`)
  }

  type ResolveResponse = {
    data?: { resolveReviewThread?: { thread?: { id: string; isResolved: boolean } } }
    errors?: Array<{ message: string }>
  }

  const parsed = JSON.parse(result.stdout) as ResolveResponse
  if (parsed.errors?.length) {
    fail(`GraphQL error: ${parsed.errors.map((e) => e.message).join(', ')}`)
  }

  const thread = parsed.data?.resolveReviewThread?.thread
  if (!thread?.isResolved) {
    fail('Thread was not resolved (unexpected API response)')
  }

  console.log(`✓ Resolved review thread ${threadId}`)
}

async function runClose(ticketId: string) {
  const worktreePath = await getWorktreePath(ticketId)
  cd(worktreePath)

  const worktreeStatus = await $`git status --porcelain`.quiet()
  if (worktreeStatus.stdout.trim()) {
    fail('Working tree is not clean. Commit or stash local changes before running "close".')
  }

  const pr = await getCurrentBranchPr()
  const linearUrl = (await loadRegistry()).worktrees[ticketId].linearUrl
  const linearTicketId = extractTicketId(linearUrl) || extractTicketId(pr.headRefName) || extractTicketId(pr.title)

  if (pr.state !== 'OPEN') {
    fail(`PR #${pr.number} is not open (state: ${pr.state})`)
  }

  if (pr.isDraft) {
    fail(`PR #${pr.number} is draft. Mark it ready for review before running "close".`)
  }

  console.log(`Merging PR #${pr.number} with squash + branch delete...`)
  await $`gh pr merge ${pr.number} -sd`

  // Switch to main directory to cleanup worktree
  cd(PLOUTOS_MAIN_DIR)

  console.log('Syncing main branch...')
  await $`git checkout main`
  await $`git pull --ff-only origin main`

  console.log(`Removing worktree ${worktreePath}...`)
  await $`git worktree remove ${worktreePath}`

  console.log('Syncing branch references...')
  await $`git fetch origin --prune`
  const remoteBranch = await $`git ls-remote --heads origin ${ticketId}`.quiet()
  if (remoteBranch.stdout.trim()) {
    console.warn(`Warning: Remote branch "${ticketId}" still exists on origin.`)
  }

  if (linearTicketId) {
    await maybeSetLinearDone(linearTicketId)
  }

  // Cleanup registry
  const reg = await loadRegistry()
  delete reg.worktrees[ticketId]
  await saveRegistry(reg)

  // Kill zellij session if running
  await $`zellij kill-session ${ticketId}`.nothrow()

  console.log('✓ PR merged with squash')
  console.log('✓ Worktree removed and registry updated')
  console.log(`✓ Zellij session ${ticketId} killed`)
}

// ----------------------------------------------------------------------------
// UTILITIES
// ----------------------------------------------------------------------------

async function getCurrentBranchPr(): Promise<PullRequest> {
  const prResult = await $`gh pr view --json number,url,isDraft,state,headRefName,title`.nothrow()
  if (prResult.exitCode !== 0 || !prResult.stdout.trim()) {
    fail('No PR found for the current branch')
  }

  try {
    const parsed = JSON.parse(prResult.stdout) as PullRequest
    return parsed
  } catch {
    fail('Could not parse PR information from gh CLI output')
  }
}

function parseChecks(raw: string): Check[] {
  if (!raw.trim()) {
    return []
  }

  try {
    const parsed = JSON.parse(raw)
    if (!Array.isArray(parsed)) {
      fail('Unexpected response shape from `gh pr checks`')
    }
    return parsed as Check[]
  } catch {
    fail('Could not parse check results from `gh pr checks`')
  }
}

async function getUnresolvedThreadCount(prNumber: number): Promise<number> {
  const repoResult = await $`gh repo view --json nameWithOwner`.quiet()
  const nameWithOwner = (JSON.parse(repoResult.stdout) as { nameWithOwner?: string }).nameWithOwner

  if (!nameWithOwner || !nameWithOwner.includes('/')) {
    fail('Could not determine repository owner/name from gh CLI')
  }

  const [owner, name] = nameWithOwner.split('/')
  const query = `
    query($owner: String!, $name: String!, $number: Int!) {
      repository(owner: $owner, name: $name) {
        pullRequest(number: $number) {
          reviewThreads(first: 100) {
            nodes {
              isResolved
            }
          }
        }
      }
    }
  `
  const unresolvedResult = await $`gh api graphql -f query=${query} -F owner=${owner} -F name=${name} -F number=${prNumber}`.nothrow()
  if (unresolvedResult.exitCode !== 0 || !unresolvedResult.stdout.trim()) {
    fail('Could not query unresolved review threads')
  }

  try {
    const parsed = JSON.parse(unresolvedResult.stdout) as {
      data?: { repository?: { pullRequest?: { reviewThreads?: { nodes?: Array<{ isResolved: boolean }> } } } }
    }
    const threads = parsed.data?.repository?.pullRequest?.reviewThreads?.nodes ?? []
    return threads.filter((t) => !t.isResolved).length
  } catch {
    fail('Could not parse unresolved review thread response')
  }
}

function fail(message: string): never {
  console.error(`Error: ${message}`)
  process.exit(1)
}

function isMode(value: string): value is Mode {
  return value === 'start' || value === 'switch' || value === 'list' || value === 'status' || value === 'close' || value === 'review' || value === 'resolve'
}

function looksLikeScriptPath(value: string): boolean {
  return value === 'pm.ts' || value.endsWith('/pm.ts')
}

async function loadEnvFile(filePath: string) {
  try {
    const contents = await fs.readFile(filePath, 'utf8')
    for (const rawLine of contents.split('\\n')) {
      const line = rawLine.trim()
      if (!line || line.startsWith('#')) {
        continue
      }

      const equalsIndex = line.indexOf('=')
      if (equalsIndex === -1) {
        continue
      }

      let key = line.slice(0, equalsIndex).trim()
      let value = line.slice(equalsIndex + 1).trim()

      if (key.startsWith('export ')) {
        key = key.slice('export '.length).trim()
      }

      if (
        (value.startsWith('"') && value.endsWith('"')) ||
        (value.startsWith("'") && value.endsWith("'"))
      ) {
        value = value.slice(1, -1)
      }

      if (key && process.env[key] === undefined) {
        process.env[key] = value
      }
    }
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code !== 'ENOENT') {
      throw error
    }
  }
}

function getLinearApiToken(): string | null {
  const token =
    process.env.LINEAR_API_TOKEN ??
    process.env.LINEAR_API_KEY ??
    process.env.LINEAR_TOKEN

  if (!token?.trim()) {
    return null
  }

  return token.trim()
}

function extractTicketId(input: string | undefined): string | null {
  if (!input) {
    return null
  }
  return input.match(/[A-Z]+-[0-9]+/)?.[0] ?? null
}

function upsertEnvVar(contents: string, key: string, value: string): string {
  const line = `${key}=${value}`
  const regex = new RegExp(`^${key}=.*$`, 'm')
  if (regex.test(contents)) {
    return contents.replace(regex, line)
  }

  const suffix = contents.endsWith('\n') ? '' : '\n'
  return `${contents}${suffix}${line}\n`
}

function upsertMiseEnvVar(contents: string, key: string, value: string): string {
  const envSectionRegex = /^\[env\]\s*$/m
  const lineRegex = new RegExp(`^\\s*${key}\\s*=.*$`, 'm')
  const line = `${key} = "${value}"`

  if (!envSectionRegex.test(contents)) {
    const suffix = contents.endsWith('\n') ? '' : '\n'
    return `${contents}${suffix}\n[env]\n${line}\n`
  }

  const envStart = contents.search(envSectionRegex)
  const afterEnvStart = contents.indexOf('\n', envStart) + 1
  const rest = contents.slice(afterEnvStart)
  const nextSectionOffset = rest.search(/^\[[^\]]+\]\s*$/m)
  const envEnd = nextSectionOffset === -1 ? contents.length : afterEnvStart + nextSectionOffset
  const envBlock = contents.slice(afterEnvStart, envEnd)

  const updatedBlock = lineRegex.test(envBlock)
    ? envBlock.replace(lineRegex, line)
    : `${envBlock}${envBlock.endsWith('\n') || envBlock.length === 0 ? '' : '\n'}${line}\n`

  return `${contents.slice(0, afterEnvStart)}${updatedBlock}${contents.slice(envEnd)}`
}

async function maybeSetLinearInProgress(ticketId: string) {
  if (!linearClient) {
    console.log('Skipping Linear assignment/state update (LINEAR_API_TOKEN not set).')
    return
  }

  console.log(`Updating Linear issue ${ticketId}: assign to me + set "In Progress"...`)
  try {
    const issue = await linearClient.issue(ticketId)
    const viewer = await linearClient.viewer
    const team = await issue.team
    if (!team) {
      fail(`Could not determine team for Linear issue ${ticketId}`)
    }

    const workflowStates = (await team.states({ first: 250 })).nodes
    const inProgressState = findLinearState(workflowStates, ['in progress'], ['started'])
    if (!inProgressState) {
      fail(`Could not find an "In Progress" workflow state for issue ${ticketId}`)
    }

    const updateResult = await issue.update({
      assigneeId: viewer.id,
      stateId: inProgressState.id,
    })
    if (!updateResult.success) {
      fail(`Linear issue update failed for ${ticketId}`)
    }
  } catch (error) {
    fail(`Linear API request failed while updating ${ticketId}: ${formatErrorMessage(error)}`)
  }

  console.log(`✓ Linear issue ${ticketId} assigned to you and set to "In Progress"`)
}

async function maybeSetLinearDone(ticketId: string) {
  if (!linearClient) {
    console.log('Skipping Linear "done" update (LINEAR_API_TOKEN not set).')
    return
  }

  console.log(`Updating Linear issue ${ticketId}: set to "Done"...`)
  try {
    const issue = await linearClient.issue(ticketId)
    const team = await issue.team
    if (!team) {
      fail(`Could not determine team for Linear issue ${ticketId}`)
    }

    const workflowStates = (await team.states({ first: 250 })).nodes
    const doneState = findLinearState(workflowStates, ['done'], ['completed'])
    if (!doneState) {
      fail(`Could not find a "Done" workflow state for issue ${ticketId}`)
    }

    const updateResult = await issue.update({ stateId: doneState.id })
    if (!updateResult.success) {
      fail(`Linear issue update failed for ${ticketId}`)
    }
  } catch (error) {
    fail(`Linear API request failed while updating ${ticketId}: ${formatErrorMessage(error)}`)
  }

  console.log(`✓ Linear issue ${ticketId} set to "Done"`)
}

function findLinearState(
  states: WorkflowState[],
  preferredNames: string[],
  preferredTypes: string[],
): WorkflowState | null {
  const normalizedPreferredNames = preferredNames.map(normalizeStateName)
  const normalizedPreferredTypes = preferredTypes.map((value) => value.toLowerCase())

  const nameMatch = states.find((state) => normalizedPreferredNames.includes(normalizeStateName(state.name)))
  if (nameMatch) {
    return nameMatch
  }

  const typeMatch = states.find((state) => normalizedPreferredTypes.includes(state.type.toLowerCase()))
  if (typeMatch) {
    return typeMatch
  }

  return null
}

function normalizeStateName(value: string): string {
  return value.trim().toLowerCase().replace(/[-_]/g, ' ').replace(/\\s+/g, ' ')
}

function formatErrorMessage(error: unknown): string {
  if (error instanceof Error && error.message) {
    return error.message
  }
  return String(error)
}

function stripBugbotLinks(body: string): string {
  return body.replace(/<p><a href="https:\/\/cursor\.com\/open\?data=[\s\S]*$/, '').trim()
}
