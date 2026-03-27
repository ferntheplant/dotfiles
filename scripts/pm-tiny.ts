#!/usr/bin/env zx
import { $, argv } from 'zx'

const owner = 'withcompany'
const repoName = 'ploutos'

function isMode(value: string): value is Mode {
  return value === 'review' || value === 'resolve'
}

function stripBugbotLinks(body: string): string {
  return body.replace(/<p><a href="https:\/\/cursor\.com\/open\?data=[\s\S]*$/, '').trim()
}

function fail(message: string): never {
  console.error(`Error: ${message}`)
  process.exit(1)
}

function looksLikeScriptPath(value: string): boolean {
  return value === 'tiny-pm.ts' || value.endsWith('/tiny-pm.ts')
}

async function review(prNumber: string) {
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

  const result = await $`gh api graphql -f query=${query} -F owner=${owner} -F name=${repoName} -F number=${prNumber}`.nothrow()

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

  const asJson = [] as any
  for (const thread of unresolvedThreads) {
    const location = thread.line ? `${thread.path}:${thread.line}` : thread.path
    for (let i = 0; i < thread.comments.nodes.length; i++) {
      const comment = thread.comments.nodes[i]
      const body = stripBugbotLinks(comment.body)
      const isReply = i > 0
      asJson.push({
        id: thread.id,
        location: location,
        ...(thread.isOutdated ? { outdated: true } : {}),
        comments: thread.comments.nodes.map((c) => ({
          body,
          ...(isReply ? { reply: true } : {}),
        })),
      })
    }
  }
  console.log(JSON.stringify(asJson))
}

async function resolve(threadId: string) {
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

const positionalArgs = [...argv._].map(String)
while (positionalArgs[0] && looksLikeScriptPath(positionalArgs[0])) {
  positionalArgs.shift()
}

const requestedMode = positionalArgs[0]?.toLowerCase() ?? ''
const helpRequested = requestedMode === '--help' || requestedMode === '-h' || argv.help === true || argv.h === true || requestedMode === ''

if (helpRequested || !isMode(requestedMode)) {
  console.log('Usage: tiny-pm.ts <review|resolve> [args]')
  console.log('  review  <pr number> - show unresolved PR review comments')
  console.log('  resolve <id>        - resolve a review thread by ID')
  process.exit(helpRequested ? 0 : 1)
}


type Mode = 'review' | 'resolve'

const mode: Mode = requestedMode

if (mode === 'review') {
  await review(positionalArgs[1])
} else if (mode === 'resolve') {
  const threadId = positionalArgs[1]
  if (!threadId) {
    fail('Usage: pm resolve <thread-id>')
  }
  await resolve(threadId)
}
