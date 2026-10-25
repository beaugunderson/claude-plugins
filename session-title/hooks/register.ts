// A session title can only be set through a UserPromptSubmit or SessionStart
// hook result, and SessionStart runs before any prompt exists. So the first
// prompt waits up to WAIT_MS for Haiku's title; a slower answer is kept and
// handed over on the next prompt.

import type { Register } from 'claude-code'

import type { Phase } from '../types'

const PHASE = { plugin: 'session-title', key: 'phase' } as const
const TITLE = { plugin: 'session-title', key: 'title' } as const

const MAX_PROMPT_CHARS = 4000
const WAIT_MS = 2000

const ASK = `Name this Claude Code session from the user's first request.
Reply with the title alone: 2 to 6 lowercase words joined by dashes, like
fix-flaky-login-test. No quotes, no "session" or "claude" in it. Name the
task, not the tooling.

First request:

`

export const clean = (text: string): string =>
  (text.split('\n')[0] ?? '')
    .replace(/^(title|session title)\s*:\s*/i, '')
    .toLowerCase()
    .replace(/['`’]/g, '')
    .replace(/[^a-z0-9]+/g, '-')
    .slice(0, 60)
    .replace(/^-+|-+$/g, '')

export const register: Register = on => {
  on('classic.SessionStart', async ($, e, next) => {
    const r = await next(e)
    let phase: Phase = 'none'
    if (e.session_title || r.sessionTitle) phase = 'done'
    else if (e.source === 'resume' || e.source === 'compact') {
      // Keep whatever this session already reached.
      const { value } = await $.state.get(PHASE)
      phase = value ?? 'none'
    }
    await $.state.set(PHASE, phase)
    return r
  })

  // The person's own /rename always wins over a title written here.
  on('prompt.submit', async ($, e, next) => {
    if (e.command?.name === 'rename') await $.state.set(PHASE, 'done')
    return next(e)
  })

  on('classic.UserPromptSubmit', async ($, e, next) => {
    const r = await next(e)
    if (e.agent_id) return r

    const { value: phase = 'none' } = await $.state.get(PHASE)

    if (r.sessionTitle) {
      await $.state.set(PHASE, 'done')
      return r
    }

    if (phase === 'ready') {
      const { value: title } = await $.state.get(TITLE)
      await $.state.set(PHASE, 'done')
      return title ? { ...r, sessionTitle: title } : r
    }

    if (phase !== 'none' || r.block) return r
    if (e.source && e.source !== 'user') return r

    const prompt = e.prompt.trim()
    if (!prompt || prompt.startsWith('/')) return r

    await $.state.set(PHASE, 'pending')

    // Resolves once the title (or its absence) is recorded in state, so a
    // late answer is waiting for the next prompt either way.
    const titled = (async () => {
      const t = await $.model.complete({
        model: 'haiku',
        effort: 'low',
        maxTokens: 40,
        timeoutMs: 15_000,
        prompt: ASK + prompt.slice(0, MAX_PROMPT_CHARS),
      })
      const { value: now } = await $.state.get(PHASE)
      if (now !== 'pending') return ''
      const title = t.isAnswered ? clean(t.text) : ''
      if (title) {
        await $.state.set(TITLE, title)
        await $.state.set(PHASE, 'ready')
      } else {
        await $.state.set(PHASE, 'none')
      }
      return title
    })()

    const title = await Promise.race([titled, $.clock.sleep(WAIT_MS).then(() => '')])
    if (!title) return r
    await $.state.set(PHASE, 'done')
    return { ...r, sessionTitle: title }
  })
}
