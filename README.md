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
