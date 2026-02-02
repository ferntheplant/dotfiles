#!/usr/bin/env zx

import fs from 'node:fs/promises'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

type ThemeColor = [number, number, number, number]

type UserSettingsCustomTheme = {
  base: ThemeColor
  accent: ThemeColor
  contrast: number
  sidebar: {
    base: ThemeColor
    accent: ThemeColor
    contrast: number
  }
}

type ThemeName = 'light' | 'dark'

const THEMES: Record<ThemeName, UserSettingsCustomTheme> = {
  light: {
    base: [98.51759439330654, 4.072083570420195, 78.2083305332952, 1],
    accent: [41.17628486186868, 25.530191638284727, 235.1000925755649, 1],
    contrast: 30,
    sidebar: {
      base: [96.5159611844216, 4.297759256158401, 73.96939676095296, 1],
      accent: [41.17628486186868, 25.530191638284727, 235.1000925755649, 1],
      contrast: 30,
    },
  },
  dark: {
    base: [16.849272290281057, 16.24792006455235, 293.33604400175125, 1],
    accent: [72.77892230249421, 34.72977079189661, 305.2780190605827, 1],
    contrast: 30,
    sidebar: {
      base: [13.75566453563686, 14.570894079627253, 292.21722440550764, 1],
      accent: [72.77892230249421, 34.72977079189661, 305.2780190605827, 1],
      contrast: 30,
    },
  },
}

const getThemeArg = (args: string[]): ThemeName | null => {
  const direct = args.find((arg) => arg === 'light' || arg === 'dark')
  if (direct === 'light' || direct === 'dark') {
    return direct
  }

  if (args.includes('--light')) {
    return 'light'
  }

  if (args.includes('--dark')) {
    return 'dark'
  }

  const flag = args.find((arg) => arg.startsWith('--theme='))
  const value = flag?.split('=')[1]
  return value === 'light' || value === 'dark' ? value : null
}

const loadEnvFile = async (filePath: string) => {
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

      const key = line.slice(0, equalsIndex).trim()
      let value = line.slice(equalsIndex + 1).trim()

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

const scriptDir = path.dirname(fileURLToPath(import.meta.url))
const repoRoot = path.resolve(scriptDir, '..')
await loadEnvFile(path.join(repoRoot, '.env'))

const themeName = getThemeArg(process.argv.slice(2))
if (!themeName) {
  console.error('Usage: update-linear-theme.ts <light|dark> [--theme=light|dark]')
  process.exit(1)
}

const linearApiKey =
  process.env.LINEAR_API_KEY ??
  process.env.LINEAR_API_TOKEN ??
  process.env.LINEAR_TOKEN

if (!linearApiKey) {
  console.error('Missing Linear API token. Set LINEAR_API_KEY in .env.')
  process.exit(1)
}

const mutation = `
  mutation UpdateUserSettings($input: UserSettingsUpdateInput!) {
    userSettingsUpdate(input: $input) {
      success
    }
  }
`

const response = await fetch('https://api.linear.app/graphql', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    Authorization: linearApiKey,
  },
  body: JSON.stringify({
    query: mutation,
    variables: {
      input: {
        customTheme: THEMES[themeName],
      },
    },
  }),
})

const body = (await response.json()) as {
  data?: { userSettingsUpdate?: { success?: boolean } }
  errors?: { message: string }[]
}

if (!response.ok || body.errors?.length) {
  console.error('Linear API request failed.')
  if (body.errors?.length) {
    for (const error of body.errors) {
      console.error(`- ${error.message}`)
    }
  }
  process.exit(1)
}

if (!body.data?.userSettingsUpdate?.success) {
  console.error('Linear API did not confirm theme update.')
  process.exit(1)
}

console.log(`✓ Linear theme updated (${themeName}).`)
