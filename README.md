# claude-plugins

Claude Code plugins by Beau Gunderson.

## Install

```
/plugin marketplace add beaugunderson/claude-plugins
```

## Plugins

### iterm-tab-color

iTerm2 tab colors and titles for Claude Code sessions.

- **Work sessions:** dark blue when idle, bright blue when working
- **Personal sessions:** dark green when idle, bright green when working
- **Reset:** tab color and title clear on session end

```
/plugin install iterm-tab-color
```

**Setup:** After installing, disable Claude Code's built-in terminal title so it doesn't overwrite the plugin's titles. Add to `~/.claude/settings.json`:

```json
{
  "env": {
    "CLAUDE_CODE_DISABLE_TERMINAL_TITLE": "1"
  }
}
```

Then in iTerm2, change your profile's title format to **Session Name** only (Settings > Profiles > General > Title) so it doesn't append `(node)`.

### session-title

Names each new session from its first prompt. Haiku writes a 2 to 6 word title in the background (no `claude -p`, no wait), and it is applied when the second prompt is submitted. A `/rename`, a resumed session that already has a title, or a slash-command first prompt is left alone.

Load it from a clone by adding the folder to `~/.claude/settings.json`:

```json
{
  "env": {
    "CLAUDE_CODE_PLUGIN_DIRS": "~/p/claude-plugins/session-title"
  }
}
```

Tests: `claude plugin test session-title`.
