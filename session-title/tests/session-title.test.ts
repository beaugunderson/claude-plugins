import { expect, mock, test } from 'claude-code/testing'
import type { On } from 'claude-code'

import { clean } from '../hooks/register'

const USAGE = {
  input_tokens: 1,
  output_tokens: 1,
  cache_creation_input_tokens: 0,
  cache_read_input_tokens: 0,
}

// The engine beneath the plugin: no settings hooks, and Haiku answering `reply`,
// once `gate` resolves when one is given.
const engine = (on: On, reply: string, asked: string[] = [], gate?: Promise<void>) => {
  const clock = mock.clock(on)
  on('classic.SessionStart', () => ({}))
  on('classic.UserPromptSubmit', () => ({}))
  on('prompt.submit', (_, e) => ({ text: e.text }))
  on('model.complete', async (_, e) => {
    asked.push(typeof e.prompt === 'string' ? e.prompt : '')
    if (gate) await gate
    return { value: { isAnswered: true, text: reply, usage: USAGE } }
  })
  return clock
}

test('the title from the first prompt lands on the first prompt', async ($, on) => {
  const asked: string[] = []
  const clock = engine(on, 'Fix flaky login test', asked)

  await $.classic.SessionStart({ source: 'startup' })
  const first = await $.classic.UserPromptSubmit({ prompt: 'the login test keeps failing in CI' })
  expect(first.sessionTitle).toBe('fix-flaky-login-test')
  expect(asked.length).toBe(1)
  expect(asked[0]).toContain('the login test keeps failing in CI')

  const second = await $.classic.UserPromptSubmit({ prompt: 'thanks' })
  await clock.settle()
  expect(second.sessionTitle).toBeUndefined()
  expect(asked.length).toBe(1)
})

test('a title slower than the cap lands on the next prompt', async ($, on) => {
  let release = () => {}
  const gate = new Promise<void>(r => (release = r))
  const clock = engine(on, 'Slow title', [], gate)

  await $.classic.SessionStart({ source: 'startup' })
  const pending = $.classic.UserPromptSubmit({ prompt: 'do the slow thing' })
  await clock.advance(2000)
  expect((await pending).sessionTitle).toBeUndefined()

  release()
  await clock.settle()
  const next = await $.classic.UserPromptSubmit({ prompt: 'go on' })
  expect(next.sessionTitle).toBe('slow-title')
})

test('a resumed session that has a title is left alone', async ($, on) => {
  const asked: string[] = []
  const clock = engine(on, 'Anything', asked)

  await $.classic.SessionStart({ source: 'resume', session_title: 'Mine' })
  await $.classic.UserPromptSubmit({ prompt: 'keep going' })
  await clock.settle()
  const next = await $.classic.UserPromptSubmit({ prompt: 'more' })

  expect(asked.length).toBe(0)
  expect(next.sessionTitle).toBeUndefined()
})

test('a /rename first wins', async ($, on) => {
  const asked: string[] = []
  const clock = engine(on, 'Generated title', asked)

  await $.classic.SessionStart({ source: 'startup' })
  await $.prompt.submit({
    text: '/rename my name',
    command: { name: 'rename', args: 'my name' },
    wait: false,
    origin: { kind: 'composer' },
  })
  await clock.settle()
  const next = await $.classic.UserPromptSubmit({ prompt: 'go on' })

  expect(next.sessionTitle).toBeUndefined()
  expect(asked.length).toBe(0)
})

test('a slash command first prompt does not start a title', async ($, on) => {
  const asked: string[] = []
  const clock = engine(on, 'Anything', asked)

  await $.classic.SessionStart({ source: 'startup' })
  await $.classic.UserPromptSubmit({ prompt: '/revisit' })
  await clock.settle()

  expect(asked.length).toBe(0)
})

test('clean dashifies and strips quoting and labels', async () => {
  expect(clean('Title: "Fix flaky login test."')).toBe('fix-flaky-login-test')
  expect(clean('**Upgrade deps**\nextra line')).toBe('upgrade-deps')
  expect(clean("Debug Beau's  iTerm / tab_color")).toBe('debug-beaus-iterm-tab-color')
  expect(clean('already-dashed-title')).toBe('already-dashed-title')
})
