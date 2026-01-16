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

// Check if we're in a zellij session
const inZellij = () => {
  return process.env.ZELLIJ_SESSION_NAME !== undefined
}

// Kill existing dev server panes if they exist
if (inZellij()) {
  console.log('Detected zellij session, checking for existing dev server panes...')
  try {
    // List all clients to see what's running in each pane
    const clients = await $`zellij action list-clients`.quiet()
    const devServerPanes = []
    
    // Parse the output to find panes running dev servers
    for (const line of clients.stdout.trim().split('\n')) {
      if (line.includes('pnpm dev') || line.includes('npm run dev') || line.includes('yarn dev')) {
        const parts = line.trim().split(/\s+/)
        if (parts.length >= 2) {
          const paneId = parts[1]
          devServerPanes.push(paneId)
        }
      }
    }
    
    if (devServerPanes.length > 0) {
      console.log(`Found ${devServerPanes.length} dev server pane(s), closing them...`)
      
      // Navigate to each dev server pane and close it
      for (const paneId of devServerPanes) {
        try {
          // Focus the pane by navigating through panes
          await $`zellij action focus-next-pane`.quiet()
          await $`zellij action close-pane`.quiet()
        } catch (error) {
          console.warn(`Could not close dev server pane ${paneId}:`, error)
        }
      }
    } else {
      console.log('No existing dev server panes found')
    }
  } catch (error) {
    console.warn('Could not check for existing dev server panes:', error)
  }
}

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

// Restart dev server at the end
if (inZellij()) {
  console.log('Creating new dev server pane...')
  await $`zellij action new-pane --name "dev server" --cwd ${process.cwd()} -- pnpm dev`
  console.log('✓ Dev server started in new zellij pane')
}

console.log('✓ Setup complete!')
console.log(`✓ Branch: ${BRANCH_NAME}`)
console.log('✓ Draft PR created')
if (inZellij()) {
  console.log('✓ Dev server running in "dev server" pane')
}
