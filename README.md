# Forever Searching

A free addon for WoW Forever that brings NPC, item and quest search, vendor discovery, navigation and saved transmog sets into one Forever-style interface.

**Author:** [junglistloydee](https://github.com/junglistloydee)

**Status:** Public beta · **Version:** 0.14.3 · **Interface:** 16001

## Features

- Search NPCs, items and quests together, including item descriptions and related sources.
- Find nearby locations, filter by your faction plus neutral, and save favourites.
- Browse vendor stock where data is available and build a shopping list with nearby vendor stops.
- Set a map waypoint and follow a direction arrow. Travel and purchases remain manual.
- Compare recorded locations and local sightings when an NPC is difficult to find.
- Browse collected appearances, preview looks, and save custom wardrobe profiles.
- Load a saved set into the transmog vendor preview with a click; confirm the cost and application in the native vendor screen.
- Copy Wowhead links for further research.

## Installation

1. Download a packaged addon ZIP, or download this repository and locate its `ForeverSearching` folder.
2. Copy that folder into your WoW Forever `Interface/AddOns` directory. The path should end in `Interface/AddOns/ForeverSearching/ForeverSearching.toc`.
3. For the searchable database, install the Forever-compatible **QuestieDB** addon separately and enable it.
4. Restart the client or reload its UI, then type **`/find`**.

With the main search field focused, Shift-click an item link in chat to search its item ID in Items mode. This interaction still needs verification in the live client.

There are no automatic keyboard bindings. The addon stores its own preferences in `ForeverSearchingDB`; it does not write global game settings or keybindings.

## Data and limitations

**QuestieDB is an optional, separately installed dependency.** Credit goes to the **Questie team and contributors** for that database. Its source and data are not bundled in this repository or covered by this project's MIT licence. Without it, catalogue coverage is limited to data available locally, such as observed NPCs and vendor stock.

Database locations and source relationships may be incomplete or differ from live spawns. The navigation arrow shows a direct bearing, not a terrain-aware path. Wardrobe availability depends on the client APIs and collection data; saved sets cannot bypass vendor restrictions.

This is a beta. Offline regression checks and author testing do not establish compatibility with every client build or other addon. This project is not an official Blizzard product, and no guarantee of platform approval is implied.

## Help and feedback

See the [detailed guide and change history](docs/USER_GUIDE.md). Report bugs through [GitHub Issues](https://github.com/junglistloydee/forever-searching/issues), including your addon version, client build, steps to reproduce, and any Lua error. Remove account or personal information from attachments.

## Development

Install Node.js and PowerShell, then run from the repository root:

```powershell
npm install --prefix .tools fengari-node-cli@0.1.0
node .tools/node_modules/fengari-node-cli/src/lua-cli.js tests/run.lua
node .tools/node_modules/fengari-node-cli/src/lua-cli.js tests/performance.lua
node .tools/node_modules/fengari-node-cli/src/lua-cli.js tests/search-performance.lua
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/test-build-safety.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/build.ps1
```

Confirm each Lua suite prints its final `PASS:` result, because the Lua runner can return a successful process code after a Lua error. The archive is built into `dist/` with an explicit file allowlist, including the README and licence. Build guards reject prohibited settings, binding, purchase and transmog-commit APIs. GitHub Actions runs these checks and uploads a build artifact; it does not publish a release automatically.

## Licence

[MIT](LICENSE) — Copyright (c) 2026 junglistloydee. Free to use, modify and redistribute under the licence terms. Third-party dependencies retain their own licences.
