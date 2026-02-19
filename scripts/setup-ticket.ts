#!/usr/bin/env zx

import fs from 'node:fs/promises'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { LinearClient, type WorkflowState } from '@linear/sdk'
import { $, argv, question } from 'zx'

type Mode = 'start' | 'status' | 'close'
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

const scriptDir = path.dirname(fileURLToPath(import.meta.url))
const dotfilesRoot = path.resolve(scriptDir, '..')
await loadEnvFile(path.join(dotfilesRoot, '.env'))
const linearApiToken = getLinearApiToken()
const linearClient = linearApiToken ? new LinearClient({ apiKey: linearApiToken }) : null

const positionalArgs = [...argv._].map(String)
while (positionalArgs[0] && looksLikeScriptPath(positionalArgs[0])) {
  positionalArgs.shift()
}

const requestedMode = String(positionalArgs[0] ?? 'start').toLowerCase()
const helpRequested = requestedMode === '--help' || requestedMode === '-h' || argv.help === true || argv.h === true

if (helpRequested || !isMode(requestedMode)) {
  console.log('Usage: scripts/setup-ticket.ts <start|status|close>')
  console.log('  start  - create ticket branch + empty commit + draft PR')
  console.log('  status - verify current branch PR is ready (not draft, checks passing, no open review threads)')
  console.log('  close  - squash merge current branch PR, delete remote/local branch, return to main')
  process.exit(helpRequested ? 0 : 1)
}

const mode: Mode = requestedMode
const { repoBasename, currentBranch } = await getRepoContext()
ensurePloutosRepo(repoBasename)

if (mode === 'start') {
  await runStart(currentBranch)
} else if (mode === 'status') {
  await runStatus()
} else {
  await runClose(currentBranch)
}

async function runStart(currentBranch: string) {
  if (currentBranch !== 'main') {
    fail('The "start" command can only be run from the main branch')
  }

  console.log('Enter Linear ticket URL:')
  const linearUrl = await question('Linear URL: ')
  if (!linearUrl) {
    fail('Linear ticket URL is required')
  }

  const ticketId = linearUrl.match(/[A-Z]+-[0-9]+/)?.[0]
  if (!ticketId) {
    fail('Could not extract ticket ID from URL')
  }

  console.log(`Setting up for ticket: ${ticketId}`)
  console.log('Enter a conventional commit message (e.g., "feat: add new feature", "fix: resolve bug"):')
  const conventionalCommit = await question('Commit message: ')
  if (!conventionalCommit) {
    fail('Conventional commit message is required')
  }

  const commitTypes = ['feat', 'fix', 'docs', 'style', 'refactor', 'test', 'chore', 'perf', 'ci', 'build', 'revert']
  const commitType = conventionalCommit.split(':')[0]?.trim()
  if (!commitTypes.includes(commitType)) {
    console.warn(`Warning: ${commitType} is not a standard conventional commit type`)
    console.warn(`Standard types: ${commitTypes.join(', ')}`)
  }

  const branchName = ticketId
  const commitTitle = conventionalCommit

  await maybeSetLinearInProgress(ticketId)

  console.log(`Branch: ${branchName}`)
  console.log(`Commit: ${commitTitle}`)

  const hasChanges = await $`git status --porcelain`.quiet()
  let stashed = false

  try {
    if (hasChanges.stdout.trim()) {
      console.log('Stashing current changes...')
      await $`git stash push -m "WIP: switching to ${ticketId}"`
      stashed = true
    } else {
      console.log('No changes to stash')
    }

    console.log(`Creating branch: ${branchName}`)
    await $`git checkout -b ${branchName}`

    console.log('Creating initial commit...')
    await $`git commit --allow-empty -m ${commitTitle}`

    console.log('Pushing to remote...')
    await $`git push -u origin ${branchName}`

    console.log('Creating draft PR...')
    const prBody = `Closes [${ticketId}](${linearUrl})`
    await $`gh pr create --title ${commitTitle} --body ${prBody} --draft --base main --head ${branchName}`
  } finally {
    if (stashed) {
      console.log('Unstashing changes...')
      const stashPop = await $`git stash pop`.nothrow()
      if (stashPop.exitCode !== 0) {
        console.warn('Warning: Could not automatically apply stashed changes. Resolve manually with `git stash list`.')
      }
    }
  }

  console.log('✓ Setup complete!')
  console.log(`✓ Branch: ${branchName}`)
  console.log('✓ Draft PR created')
}

async function runStatus() {
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

async function runClose(currentBranch: string) {
  if (currentBranch === 'main') {
    fail('The "close" command must be run from a ticket branch, not main')
  }

  const worktreeStatus = await $`git status --porcelain`.quiet()
  if (worktreeStatus.stdout.trim()) {
    fail('Working tree is not clean. Commit or stash local changes before running "close".')
  }

  const pr = await getCurrentBranchPr()
  const linearTicketId = extractTicketId(pr.headRefName) ?? extractTicketId(currentBranch) ?? extractTicketId(pr.title)
  if (linearApiToken && !linearTicketId) {
    fail('Could not determine Linear ticket ID from branch/PR metadata')
  }

  if (pr.state !== 'OPEN') {
    fail(`PR #${pr.number} is not open (state: ${pr.state})`)
  }

  if (pr.isDraft) {
    fail(`PR #${pr.number} is draft. Mark it ready for review before running "close".`)
  }

  console.log(`Merging PR #${pr.number} with squash + branch delete...`)
  await $`gh pr merge ${pr.number} -sd`

  console.log('Switching back to main...')
  await $`git checkout main`
  await $`git pull --ff-only origin main`

  const branchExists = await $`git show-ref --verify --quiet refs/heads/${currentBranch}`.nothrow()
  if (branchExists.exitCode === 0) {
    await $`git branch -d ${currentBranch}`
  }

  console.log('Syncing branch references...')
  await $`git fetch origin --prune`
  const remoteBranch = await $`git ls-remote --heads origin ${currentBranch}`.quiet()
  if (remoteBranch.stdout.trim()) {
    console.warn(`Warning: Remote branch "${currentBranch}" still exists on origin.`)
  }

  if (linearTicketId) {
    await maybeSetLinearDone(linearTicketId)
  }

  console.log('✓ PR merged with squash')
  console.log('✓ Local repository returned to main')
  console.log(`✓ Branch "${currentBranch}" removed locally (and requested on remote)`)
}

async function getRepoContext() {
  const repoRoot = await $`git rev-parse --show-toplevel`.quiet()
  const branch = await $`git branch --show-current`.quiet()
  return {
    repoBasename: repoRoot.stdout.trim().split('/').pop() ?? '',
    currentBranch: branch.stdout.trim(),
  }
}

function ensurePloutosRepo(repoBasename: string) {
  if (repoBasename !== 'ploutos') {
    fail('This script can only be run in the "ploutos" repository')
  }
}

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
          reviewThreads(first: 1, states: UNRESOLVED) {
            totalCount
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
      data?: { repository?: { pullRequest?: { reviewThreads?: { totalCount?: number } } } }
    }
    return parsed.data?.repository?.pullRequest?.reviewThreads?.totalCount ?? 0
  } catch {
    fail('Could not parse unresolved review thread response')
  }
}

function fail(message: string): never {
  console.error(`Error: ${message}`)
  process.exit(1)
}

function isMode(value: string): value is Mode {
  return value === 'start' || value === 'status' || value === 'close'
}

function looksLikeScriptPath(value: string): boolean {
  return value === 'setup-ticket.ts' || value.endsWith('/setup-ticket.ts')
}

async function loadEnvFile(filePath: string) {
  try {
    const contents = await fs.readFile(filePath, 'utf8')
    for (const rawLine of contents.split('\n')) {
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
  return value.trim().toLowerCase().replace(/[-_]/g, ' ').replace(/\s+/g, ' ')
}

function formatErrorMessage(error: unknown): string {
  if (error instanceof Error && error.message) {
    return error.message
  }
  return String(error)
}
