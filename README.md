# Bears Greeter

[![WoW Version](https://img.shields.io/badge/WoW-12.1.5-darkgreen)](https://worldofwarcraft.blizzard.com/) [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT) [![GitHub](https://img.shields.io/badge/GitHub-Source-blue?logo=github)](https://github.com/N6REJ/Bears-Greeter)

Greets each guild member the first time they speak in guild chat each day.

Bears Greeter is a small World of Warcraft retail addon. It listens for guild
chat, remembers who has already been greeted today, and sends one greeting per
member per day. The list resets when the calendar day changes.

This repository is a working skeleton: the core loop, options panel, slash
commands, localization hooks, and release automation are in place, ready for
additional greeting rules.

## Status

Working baseline. The default behavior is:

- A guild member speaks in guild chat.
- If the member has not been greeted today, send `Welcome back, <name>!` to
  guild chat.
- Remember the member until the next calendar day.
- Ignore messages from the player.

## Requirements

- Retail World of Warcraft: Midnight, patch **12.1.5** or newer. Classic is not
  supported.
- Guild membership.

The TOC uses interface number `120105` (12.1.5). If your client reports a
different value, update the TOC:

```text
/dump select(4, GetBuildInfo())
```

## Installation

The repository root is the addon folder, but the folder must be named
`Bears_Greeter` to match `Bears_Greeter.toc`. Junction or clone it into the
retail AddOns directory:

```powershell
New-Item -ItemType Junction `
    -Path "C:\Gaming\World of Warcraft\_retail_\Interface\AddOns\Bears_Greeter" `
    -Target "E:\wow\Bears-Greeter"
```

Then run `/reload` in game.

## Usage

Guild chat is monitored automatically. Open the options with `/greeter`, `/bgreet`,
or the addon entry in **Options > AddOns > Bears Greeter**.

The first time a guild member speaks each day:

```text
[Guild] Bearesquishy: Welcome back, Thrall!
```

The player is never greeted. Members are tracked by short name, so the same
character on the same realm is only greeted once per day.

## Slash commands

| Command | Description |
| --- | --- |
| `/greeter` | Open the options panel. |
| `/greeter test` | Send a test greeting. |
| `/greeter reset` | Clear today's greeted list. |
| `/greeter toggle` | Turn greetings on or off. |
| `/greeter help` | Print command help. |

`/bgreet` is an alias for `/greeter`.

## Options

| Option | Description |
| --- | --- |
| Enable greetings | Turn automatic greetings on or off. |
| Greeting message | Template sent to chat. `%s` is replaced with the member's name. |
| Delivery | Send to guild chat or whisper the member. |
| Debug messages | Print a local message after each greeting. |
| Test | Send a test greeting using the current settings. |
| Reset today | Clear the greeted list so members can be greeted again. |

Defaults are saved per Blizzard account in `BearsGreeterDB`.

## How it works

`CHAT_MSG_GUILD` provides the speaker's name. The addon normalizes it with
`Ambiguate` (falling back to the part before the realm separator), checks the
saved `greeted` table for today, and sends the greeting through
`SendChatMessage`. The member is marked as greeted before sending, so a burst of
messages cannot produce duplicate greetings.

The daily key is `date("%Y-%m-%d")`. The table is cleared on
`PLAYER_ENTERING_WORLD` when the date changes, and whenever the addon loads on a
new day.

## File layout

```text
Bears_Greeter.toc          Addon manifest and load order
core.lua                   Addon lifecycle, guild chat handling, greeting logic, slash commands
options.lua                AceConfig options panel
Locales/                   AceLocale-3.0 localization files
Libs/                      Ace libraries; external dependencies fetched by the packager (local copies ignored by git)
.github/                   Labels, dependabot, release, and changelog workflows
.pkgmeta                   BigWigs packager configuration
README.md                  This file
CHANGELOG.md               Version history
AGENTS.md                  Project guidance for contributors and agents
```

## Development

- The addon name, TOC filename, folder name, and SavedVariables prefix
  (`BearsGreeterDB`) must stay consistent.
- Add any new runtime file to `Bears_Greeter.toc` before `options.lua`.
- Add user-facing strings to `Locales/enUS.lua` first. Other locales fall back
  to English until translated.
- Keep the code Lua 5.1 compatible.

## Release automation

`.github/workflows/release.yml` runs BigWigsMods/packager when a tag is pushed.
It expects the repository secrets `CF_API_KEY`, `WAGO_API_TOKEN`, and the
automatic `GITHUB_TOKEN`. The TOC already includes
`## X-Curse-Project-ID: 1783140`; add `## X-Wago-ID` if the addon is also
published through Wago.

`.github/workflows/changelog.yml` appends generated notes to an existing
release. `.github/workflows/create-labels.yml` syncs `.github/labels.yml`.
`.github/workflows/auto-merge.yml` enables dependabot auto-merge for minor
updates. `.github/workflows/curseforge-stats.yml` refreshes download stats in
`stats/` daily and needs the `CF_STUDIO_API_KEY` secret.

## Not implemented yet

- Multiple greeting templates or random messages.
- Per-rank or per-member exclusions.
- Officer chat, party, raid, or instance chat triggers.
- First-seen tracking across days rather than a daily reset.
- Minimap button.

## Limitations

- The addon cannot know whether another addon already greeted someone.
- Changing the system clock can reset the daily list early or late.
- `CHAT_MSG_GUILD` only fires for messages the client can see.
- Not affiliated with Blizzard Entertainment.
