# Project guidance

- Scope: this addon uses only the repository at `E:\wow\Bears-Greeter` and these test installs: `C:\Gaming\World of Warcraft_retail_\Interface\AddOns\Bears_Greeter` and `C:\Gaming\World of Warcraft_forever_\Interface\AddOns\Bears_Greeter`. Do not read, search, edit, or use files from `E:\Bearsampp-development` or any other project.
- Bears_Greeter targets retail World of Warcraft (Midnight 12.1.5+) and also supports World of Warcraft: Forever (1.60.1, interface 16001) as an optional, additional client. Neither client is required to be installed. Do not add other Classic variants.
- Keep the addon Lua 5.1 compatible. Ace libraries are declared as packager externals in `.pkgmeta`; local copies under `Libs/` are ignored by git.
- Keep the folder name, TOC filename, addon name, and SavedVariables prefix (`BearsGreeterDB`) consistent.
- Register runtime files in `Bears_Greeter.toc` before `options.lua`.
- Add user-facing strings to `Locales/enUS.lua` first; other locales fall back to English.
- Never greet the player or send more than one greeting per member per cache window.
- Mark a member as greeted before sending so repeated triggers cannot duplicate a greeting.
- Greetings may be sent in response to an eligible guild chat message, a member coming online (login trigger mode, after the configured delay), or an explicit test command. Never send on load or for any other event.
- Update `README.md` and `CHANGELOG.md` when behavior changes.
