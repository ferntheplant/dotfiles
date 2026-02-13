#!/usr/bin/env zx

import { $, question } from 'zx'

// Check if we're in the "ploutos" repo and on main branch
const repoName = await $`git rev-parse --show-toplevel`.quiet()
const repoBasename = repoName.stdout.trim().split('/').pop()
const currentBranch = await $`git branch --show-current`.quiet()

if (repoBasename !== 'ploutos') {
  console.error('Error: This script can only be run in the "ploutos" repository')
  process.exit(1)
}

if (currentBranch.stdout.trim() !== 'main') {
  console.error('Error: This script can only be run from the main branch')
  process.exit(1)
}

// Prompt for Linear ticket URL
console.log('Enter Linear ticket URL:')
const LINEAR_URL = await question('Linear URL: ')

if (!LINEAR_URL) {
  console.error('Error: Linear ticket URL is required')
  process.exit(1)
}

// Extract ticket ID from URL (e.g., PROD-XXX)
const TICKET_ID = LINEAR_URL.match(/[A-Z]+-[0-9]+/)?.[0]

if (!TICKET_ID) {
  console.error('Error: Could not extract ticket ID from URL')
  process.exit(1)
}

console.log(`Setting up for ticket: ${TICKET_ID}`)

// Prompt for conventional commit message
console.log('Enter a conventional commit message (e.g., "feat: add new feature", "fix: resolve bug"):')
const CONVENTIONAL_COMMIT = await question('Commit message: ')

if (!CONVENTIONAL_COMMIT) {
  console.error('Error: Conventional commit message is required')
  process.exit(1)
}

// Validate conventional commit format (basic check)
const commitTypes = ['feat', 'fix', 'docs', 'style', 'refactor', 'test', 'chore', 'perf', 'ci', 'build', 'revert']
const commitType = CONVENTIONAL_COMMIT.split(':')[0]?.trim()
if (!commitTypes.includes(commitType)) {
  console.warn(`Warning: ${commitType} is not a standard conventional commit type`)
  console.warn(`Standard types: ${commitTypes.join(', ')}`)
}

const BRANCH_NAME = TICKET_ID
const COMMIT_TITLE = CONVENTIONAL_COMMIT

console.log(`Branch: ${BRANCH_NAME}`)
console.log(`Commit: ${COMMIT_TITLE}`)

// Check if there are any changes to stash
const hasChanges = await $`git status --porcelain`.quiet()
let STASHED = false
if (hasChanges.stdout.trim()) {
  console.log('Stashing current changes...')
  await $`git stash push -m "WIP: switching to ${TICKET_ID}"`
  STASHED = true
} else {
  console.log('No changes to stash')
}

// Create new branch
console.log(`Creating branch: ${BRANCH_NAME}`)
await $`git checkout -b ${BRANCH_NAME}`

// Create initial commit
console.log('Creating initial commit...')
await $`git commit --allow-empty -m ${COMMIT_TITLE}`

// Push to remote
console.log('Pushing to remote...')
await $`git push -u origin ${BRANCH_NAME}`

// Create draft PR
console.log('Creating draft PR...')
const PR_BODY = `Closes [${TICKET_ID}](${LINEAR_URL})`
await $`gh pr create --title ${COMMIT_TITLE} --body ${PR_BODY} --draft --base main --head ${BRANCH_NAME}`

// Unstash changes if any
if (STASHED) {
  console.log('Unstashing changes...')
  await $`git stash pop`
}

console.log('✓ Setup complete!')
console.log(`✓ Branch: ${BRANCH_NAME}`)
console.log('✓ Draft PR created')
