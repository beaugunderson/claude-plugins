# iterm-tab-color

iTerm2 tab colors and titles for Claude Code sessions.

- **Green** — Claude is working
- **Yellow** — waiting for you (done, needs approval, waiting for input)
- **Reset** — tab color and title clear on session end

## Setup

After installing, disable Claude Code's built-in terminal title so it doesn't overwrite the plugin's titles. Add to `~/.claude/settings.json`:

```json
{
  "env": {
    "CLAUDE_CODE_DISABLE_TERMINAL_TITLE": "1"
  }
}
```

Then in iTerm2, change your profile's title format to **Session Name** only (Settings > Profiles > General > Title) so it doesn't append `(node)`.

## Install

```
/plugin marketplace add beaugunderson/claude-iterm-tab-color
/plugin install iterm-tab-color
```

## Test locally

```bash
claude --plugin-dir /path/to/claude-iterm-tab-color
```
