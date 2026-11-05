# Bears Greeter

## [2026.11.04](https://github.com/N6REJ/Bears-Greeter/tree/2026.11.04) (2026-11-04)
[Full Changelog](https://github.com/N6REJ/Bears-Greeter/commits/2026.11.04) [Previous Releases](https://github.com/N6REJ/Bears-Greeter/releases)

- docs: remove "Not implemented yet" section from README  
- docs: clarify locale files ship English templates  
- docs: remove outdated "working skeleton" wording  
- docs: clarify greeting is per cache window, not once per day  
- docs: mention Forever support in README intro  
- docs: update README (commands, defaults, Forever install path)  
- chore: default delay changed to 15 seconds  
- fix: minimap left-click calls addon.OpenOptionsDialog (not addonTable)  
- feat(locales): translate all strings into 10 non-English locales  
    deDE, esES, esMX, frFR, itIT, koKR, ptBR, ruRU, zhCN, zhTW now carry full translations including new time-of-day and trigger strings.  
- chore(locales): populate all locale files with full English key set  
    Non-English locales now contain every key as an English template so translators have a complete starting set; missing translations fall back to enUS at runtime.  
- feat: add time-of-day greeting option based on server time  
    New Time of day greeting checkbox uses Good Morning/Afternoon/Evening based on GetServerTime.  
    When enabled, greeting is greeting plus name. Add locale strings and update README and CHANGELOG.  
- chore: remove /bgreet slash alias (keep /greeter and /bg)  
- fix: /greeter opens options; add /bg alias; robust minimap button creation  
    addonTable.OpenOptionsDialog was nil (it lives on addon); use addon.OpenOptionsDialog.  
    Register /bg in addition to /greeter and /bgreet.  
    Create minimap button lazily in PLAYER\_ENTERING\_WORLD if Minimap was not ready at OnEnable; init missing minimap profile table.  
- docs: cite verified API (C\_GuildInfo.GuildRoster exists in retail and Forever)  
- fix: use C\_GuildInfo.GuildRoster() (GuildRoster() removed in 12.1.5)  
    GuildRoster() global is gone in retail 12.1.5; use C\_GuildInfo.GuildRoster() with a fallback to the global for Forever/Classic clients.  
- feat: support World of Warcraft: Forever (interface 16001) alongside retail  
    - TOC Interface now lists 120105, 16001 (retail required target, Forever optional).  
    - Neither client is required to be installed; each loads the addon independently.  
    - Update AGENTS.md and README.md to document Forever as a supported client.  
- chore: match Bears\_Boon\_Viewer minimap location behavior (draggable button)  
    Replaces LibDBIcon with the manual CreateFrame minimap button used by Bears\_Boon\_Viewer: draggable around the minimap edge, angle stored in minimap.minimapButtonAngle.  
- chore: use LibDBIcon for minimap button (consistent with Bears-Decor-Tool)  
    Re-adds LibDataBroker-1.1 and LibDBIcon-1.0 externals and uses LibDBIcon for the minimap button, matching Bears-Decor-Tool.  
- chore: drop LibDBIcon, use a manual minimap button (no extra external)  
    Replaces the LibDataBroker/LibDBIcon-based minimap button with a self-contained CreateFrame button, matching Bears\_Boon\_Viewer, so no new external library is needed.  
    Keeps the ability\_priest\_heavanlyvoice icon for the addon and minimap button.  
- feat: use ability\_priest\_heavanlyvoice icon for addon and minimap button  
    - Set TOC IconTexture to Interface\\Icons\\ability\_priest\_heavanlyvoice.  
    - Add LibDataBroker-1.1 and LibDBIcon-1.0 externals.  
    - Add a minimap button (left-click opens options, right-click toggles greetings) with show/hide option.  
    - Update README (minimap button no longer listed as unimplemented).  
- feat: add login trigger, delay, cache time, and <name> greeting template  
    - Login (on join) trigger mode by default; guild chat trigger remains an option.  
    - Configurable delay (seconds) before sending a greeting.  
    - Configurable cache time (hours; 24 means until the calendar day changes).  
    - Greeting template now uses <name> instead of %s.  
    - Update options panel, locales, README, CHANGELOG, and AGENTS guidance.  
- chore: add .packager (BigWigs packager scripts)  
    Adds action.yml, release.sh, and release.yml matching the other Bears addons so local/CI packaging works.  
- chore(pkgmeta): pin all externals to tag: latest  
    Rewrite externals in the readable url/tag form so the packager fetches the latest tagged release of each library.  
- feat: add guild greeting addon with packaging and workflows  
    - Greet each guild member on their first guild chat message per day  
    - AceConfig options panel with /greeter and /bgreet commands  
    - Ace3 libraries declared as packager externals; local Libs/ ignored  
    - CurseForge release, changelog, labels, and stats workflows  
    - TOC version uses the 2026.11.04 placeholder  
- Initial commit  