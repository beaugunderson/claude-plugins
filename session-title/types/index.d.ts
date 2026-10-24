// none: no title yet, the next real prompt starts one
// pending: a title request is in flight
// ready: `title` holds a title waiting for the next prompt to apply it
// done: the session has a title (ours, a resumed one, or the person's /rename)
export type Phase = 'none' | 'pending' | 'ready' | 'done'

declare module 'claude-code' {
  interface PluginState {
    'session-title': { phase: Phase; title: string }
  }
}
