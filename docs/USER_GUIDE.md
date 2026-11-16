# Forever Searching

A WoW Forever addon with combined NPC, item and quest search, a collected-appearance wardrobe with custom profiles, vendor listings, location evidence, and native map/minimap navigation in a native Forever interface. Interface version **16001**, version **0.14.4**.

**Author:** [junglistloydee](https://github.com/junglistloydee)

## Wardrobe background consistency in 0.14.4

The wardrobe and model preview now use the same native inset background as the search results and details panels. No gameplay, saved-data, game-setting or keybinding changes.

## Shift-click item search in 0.14.3

With the main search field focused, Shift-click an item link in chat to search its ID in Items mode. Uses a secure post-hook on the available chat insertion API without replacing native handlers. Non-item links, unfocused or hidden search, wardrobe and combat are ignored. No keybinding or global game-setting changes. Offline tests pass; live chat interaction still needs verification.

## Wardrobe footer spacing in 0.14.2

Separated appearance pagination, source/variant/link buttons, selected-appearance text and save controls into distinct rows. Added footer height to preserve spacing below the controls. No behaviour, settings or keybinding changes.

## Wardrobe spacing and font compatibility in 0.14.1

Replaced unsupported arrow/check/star text glyphs with plain labels and the native raid-star texture. Favourite stars now have add/remove tooltips. Added spacing between filters, result counts and rows, and enlarged the wardrobe vertically to give status messages their own line below the save controls. Existing data, settings and keybindings are unaffected. Live rendering still needs verification.

## Search and wardrobe usability in 0.14.0

The native Forever frame and red/gold styling are retained. Search mode and source filters now open direct-choice menus. The known-location filter is a checkbox, and a Sort menu sits beside the result count. Scroll over results to move between pages. Result type icons supplement the existing labels; redundant unknown-purpose text is omitted. Selection-specific actions are hidden until relevant, and **Navigate here** starts the existing map-pin/arrow flow. **About / Data** shows detailed database status and credits.

The wardrobe uses a larger preview with mouse dragging to rotate and mouse-wheel zoom. Reset view and a **Showing: Worn / Edited** toggle remain visible. Search is above slot/type filters, with explicit favourites/usability states and a sort menu. Appearance rows have inline favourite stars, selected markers and mouse-wheel paging. Single-variant noise is removed and variant/source/link controls appear for relevant selections.

**New set** is visible in the sidebar. **Set actions** contains Rename, Duplicate, Capture current look and Delete; deletion retains its second-click confirmation. **Help / More** contains the checklist, refresh and diagnostics. Save changes, Revert changes and vendor handoff are grouped at the bottom. Existing saved profiles, favourites, search preferences and navigation data are retained; internal SavedVariables names are unchanged. Model gestures affect only the private preview and require no keybinding registration. Existing combat guards, manual vendor confirmation and global-settings protections remain in place.

Offline regression checks cover menu selection, contextual actions, model dragging, scrolling, combat guards and saved-data behaviour. Font sizing, clipping and overall appearance still need checking in the live Forever client.

## Pending-preview compatibility fix in 0.13.2

Loading saved sets now uses the native **HasPendingOutfitTransmogs** read to check whether the viewed outfit already has pending appearance edits. Previously, the safety check required selectable options on every reported slot, including unused/class-specific appearance and illusion slots. A clean outfit could therefore be rejected with **Cannot verify pending options for this outfit** before any saved appearance was loaded.

The outfit-wide read avoids that incorrect requirement. Existing pending edits are still protected across the outfit, and pending situation edits are also checked when that native read is available. Failed, secret or non-boolean pending-state reads stop loading; they are never interpreted as a clean outfit. Clients without the outfit-wide read retain the conservative slot scan. Every slot actually used by the saved profile still passes the original ownership, usability and option checks before any pending writes.

Install the updated ForeverSearching folder and reload the UI. At the vendor, manually save/discard existing native pending edits first, then select your saved set in **Forever sets** and click **Load into preview**. Final application and payment remain on the native **Save Outfit** button. No native edits are cleared, no restrictions are bypassed, and no settings or keybindings are changed. The fix is covered offline with optionless unused slots and unreadable/pending states; live-client loading still needs verification.

## Independent saved-set overlay in 0.13.1

**Forever sets** is now a separate addon-owned overlay near the upper-right corner of the transmogrifier window, above its collection area. Both the launcher and picker belong to **UIParent**, not the native vendor frame. Only our controls are positioned/styled; the vendor frame is used as a positioning reference. The addon does not resize, reparent, move, hide, or replace/hook scripts on the native screen. Your profiles remain separate from native Custom Sets, and final confirmation remains in the native Save Outfit control.

The overlay explicitly stays above the native screen's artwork, including fullscreen frame strata. A throttled four-times-per-second visibility check discovers a vendor window created after its open/load event, so attaching does not depend entirely on event order. The launcher is hidden when the vendor window is unavailable/closed or combat starts; the picker is not reopened automatically. These checks read visibility/frame information and update only our own controls. They never load appearances, change settings, or assign keybindings. No transmog write occurs until the player explicitly clicks Load into preview. Live-client placement and pending-preview behaviour still need verification; this is not formal Blizzard approval.

## Saved sets inside the native transmog screen in 0.13.0

The full Forever Wardrobe is now the place to create, preview, edit and **save profiles**. Loading a saved profile happens from the native transmogrifier window, so both large windows do not need to stay open together. Existing profiles are preserved in **ForeverSearchingDB**; there is no migration or native outfit import.

1. Create and save a profile in `/find` → Transmog. **Use in transmog screen** closes our editor and remembers the selected saved profile. It does not stage appearances or open the native window itself.
2. Talk to a transmogrifier and open its normal window. Click the **Forever sets** overlay near its upper-right corner to browse your saved addon profiles. Select an editable native outfit yourself.
3. Select a profile and click **Load into preview**. The addon rechecks the current saved profile, collected appearances and native slot restrictions, then stages only the selected appearances. Existing native pending edits must be saved/discarded manually first. Deleted or unavailable sets cannot be loaded from a stale selection.
4. Review the native preview, errors and cost. Use the native **Save Outfit** button for final confirmation and payment.

If the vendor screen is already open, **Use in transmog screen** hands off to the small saved-set picker. It never loads an unsaved draft. The picker and its button are independent addon-owned overlays; they do not replace native scripts, close the vendor frame, select an outfit, create native outfits, or alter Blizzard's **Custom Sets** database. Those native sets remain separate from Forever Searching profiles.

Opening the vendor, selecting a profile, paging, closing the picker, and collection events do not write any transmog appearances. Only clicking **Load into preview** invokes the existing guarded pending-preview operation. The picker closes in combat, and opening/loading is blocked until combat ends. It does not reopen automatically afterwards. No game settings, keybindings, native collection filters, equipment, automatic payment or final-apply calls are added. The integration uses public UI/collection APIs without bypassing restrictions; this is not formal Blizzard approval. Its title-bar placement and pending-preview behaviour still require verification in the live Forever client.

## Faster search in 0.12.1

Player typing now waits **120 ms after the last keystroke** before starting a search. Enter submits immediately; programmatic searches, source links and filter changes remain immediate. New input cancels obsolete search work, and closing the window invalidates pending typing timers.

Combined searches reuse each NPC's nearest-location calculation within that query, rather than repeating it for every matching item and quest at the same NPC. New queries still read the player's position and recompute distances. Broad item searches build one temporary lookup for observed vendor stock instead of repeatedly scanning every saved merchant. Narrow searches retain direct lookups. These snapshots are per query, so replaced or removed inventories are not kept across searches.

Literal item-name matches avoid tooltip/type API calls; other queries retain cached description/type matching and still discover items when the client later caches their data. Description words are prepared once per item query. Lowercase NPC and combined item text is reused until its source fields change. Text caches stay in memory, with no extra fields written to personal SavedVariables records. No background item-download requests, new dependencies, game settings or keybindings are introduced.

The deterministic broad-search fixture produces the same **2,200 rows in the same order** as 0.12.0. Nearest-location evaluations decrease from **2,200 to 100**, missing observed-stock lookups from **199,900 to 3,200**, and item metadata/cache API calls for this name-matching query from **4,000 to 0**. These are work counters from a synthetic fixture, not measured live-client FPS or a promise that every query is faster by those proportions. Run `tests/search-performance.lua` with the Fengari runner; pass an extracted previous addon's module directory to compare a release. Live Forever timing still needs verification.

## Shopping routes and navigation polish in 0.12.0

Build your **Shopping** list and set the quantities, then click **Plan vendor route**. The preview lists vendor stops in visit order, with the items at each stop and the estimated distance from the previous stop (or your current position for the first one). Hover a stop to read its full item list. Items with no eligible, usable vendor location appear separately as **Unrouted**, with a reason. **Start route** sends the first stop to the map pin and built-in arrow.

The planner chooses the closest eligible vendor, then the closest remaining vendor from that stop, and so on. Items sold by the same vendor are combined into one stop. It considers alternate recorded vendor locations, the faction preference and the current-zone preference. It reads item/vendor links directly, including personally observed inventories, without changing search mode or source filters. Completed list items are omitted. Planning uses cooperative work slices; closing the search window or entering combat cancels an unfinished plan.

At each stop, buy your items manually, then click **Got items / next** in the arrow or route preview. That marks all listed items at that stop complete and guides you to the next stop. **Skip** moves on while leaving those items pending. Reaching a vendor does not assume anything was bought. Quantity edits, removals and manual completion edits invalidate the old route; plan again for the revised list. Changes detected during planning cannot publish a stale plan. **Replan route** builds a fresh order from your new position. A used plan cannot be restarted accidentally. **Stop** or the arrow's X ends the route; the shared map pin is left alone. Replacing/removing the shared waypoint also ends the route. An active route survives combat, but planning and stop advancement are blocked during combat.

This is a nearby-first **vendor itinerary**, not a guaranteed shortest travel route. Distances are straight-line estimates; terrain, roads, entrances, flight paths and transport are not modelled. Different continents and unknown/phase-specific locations are not given invented distances. Vendor stock, prices, access requirements and availability are not guaranteed. Drops, quest rewards and related quests remain available through **Find sources** but are not treated as shops. Skipped/unrouted items remain pending, and route plans/progress are not saved across reload/logout.

The navigation widget now uses the client's outlined minimap-pointer artwork, with a compact horizontal layout, a two-line destination, larger distance text, quieter lock/close controls and a checkmark when nearby. The explanation and full location are available on hover. Shopping navigation adds the stop counter, item summary and manual next/skip controls. Default placement remains beside the minimap; existing saved arrow offsets and the lock/visibility preferences are preserved. No other navigation addon is required.

No buying, movement, quest acceptance, or gameplay completion is automated. The new route controls only update **ForeverSearchingDB** list completion and place the next waypoint on a click. They do not write/reset global game settings or keybindings. Live Forever testing is still needed to verify the new layout, pointer artwork and merchant visits.

## Built-in navigation arrow in 0.11.0

Click **Show waypoint** on a source with a usable location to place the existing native map pin and start Forever Searching's own gold direction arrow. No other navigation addon is required. The arrow appears beside the lower-left edge of the minimap, remains visible when search closes, and shows the destination and approximate distance in yards. Drag it to reposition it, then click **Lock** to prevent accidental dragging; **Unlock** allows moving it again. Its screen offsets and lock preference are saved only in **ForeverSearchingDB**. No minimap or other addon frame is moved or resized.

The **X** dismisses only our arrow and leaves the map pin alone. **Settings > Show navigation arrow** controls arrow visibility. Navigation starts only from a player waypoint click, is not saved across reload/logout, and stops when the shared Blizzard waypoint is removed or replaced. The search window and arrow hide on combat entry; an active arrow resumes after combat while the search window stays closed. There is no combat retargeting or automatic movement.

This is a **direct bearing to a recorded spot**, not a route around terrain or live NPC tracking. Within about 10 yards it displays **Nearby** and asks the player to look around. Different continents, missing coordinates or unreadable facing information show no directional pointer. Supported neighbouring zones use Blizzard's world coordinates; a same-zone fallback uses actual map width/height. Unsupported locations never receive invented directions. The arrow updates at most ten times a second while shown, using public read APIs and this addon's own line artwork.

No game settings, keybindings, native collection settings or equipment are written. The existing waypoint click still replaces the single shared user waypoint and enables native super tracking. Only this addon's navigation position and preferences are saved. The design was checked against [Blizzard's addon policy](https://eu.forums.blizzard.com/en/wow/t/wow-user-interface-add-on-development-policy/1642/1): this feature displays information and leaves movement and gameplay decisions to the player. This is not formal Blizzard approval; arrow placement, bearings and restricted-data behaviour still require live Forever verification.

## Wowhead links in 0.10.3

Select a search result or wardrobe appearance and click **Copy Wowhead link**. The dialog selects a Forever URL: press **Ctrl+C**, then paste it into your browser. Source results can offer separate buttons for the matched entity and related NPC, item or quest. Appearance links use the chosen variant's actual item ID; when that ID cannot be identified, the addon explains why a link is unavailable. Appearance and source IDs are never substituted for item IDs. Escape closes the addon; the dialog closes with the window on combat and is dismissed when switching pages.

Links use `https://www.wowhead.com/forever/npc=ID`, `/forever/item=ID` or `/forever/quest=ID`. The addon does not check whether Wowhead has a page for that ID. This feature makes no website requests, scrapes or downloads no data, bundles no Wowhead content, and does not launch a browser or access the clipboard automatically. There are no affiliate or tracking parameters, advertisements, or new dependencies. QuestieDB stays a separately installed optional dependency.

This implementation was reviewed against [Blizzard's Add-On Development Policy](https://eu.forums.blizzard.com/en/wow/t/wow-user-interface-add-on-development-policy/1642/1) and [Wowhead/Fanbyte's terms](https://corp.fanbyte.com/legal/terms). It only presents player-requested reference links; it does not automate gameplay or bypass protected actions. This review is not approval from Blizzard or Wowhead or a guarantee about enforcement. Browser use remains subject to the site's terms. Live-client rendering and copying still need verification before public release.

The new dialog writes no saved data. Existing game-settings/keybinding safeguards remain in place, and existing addon preferences, profiles and favourites are preserved. Ctrl+C is the edit box's normal manual copy operation; the addon assigns no shortcut or keybinding. Open the addon with `/find`.

## Flight opacity fix in 0.10.2

Movement fading now excludes flying and flight paths. Taking off restores full opacity, and ground movement after landing can fade normally. Unreadable flight-state data keeps the window opaque. This changes only the addon's own frame opacity; settings, keybindings, profiles and native collection filters remain untouched.

## Weapon discovery fix in 0.10.1

Weapon category discovery now follows Blizzard's native wardrobe: **GetCollectionInfoForSlotAndOption** supplies a category table for the particular outfit slot and enabled option. The previous implementation incorrectly expected **C_TransmogCollection.GetCategoryInfo** to return a table; it actually returns separate values, so weapons could disappear before any appearances were queried. The tests now model that real return shape and cover bows, guns, crossbows, melee weapons, shields/off-hand items, the Ranged UI picker, and pending ranged vendor preparation. A weapon descriptor's default category no longer limits other supported categories.

Install this update over the existing ForeverSearching folder, restart/reload, and select Ranged or a hand slot in the wardrobe. All available types combines the categories the native API allows. Existing collection restrictions and the local Usable only filter still apply; use All collected to include owned preview-only appearances. Saved profiles, favourites, movement fading and combat closing are preserved. No game-settings, collection-filter, gear or keybinding writes were added; final application is still confirmed in Blizzard's vendor screen.

## Expanded Forever Wardrobe in 0.10.0

The right-hand shirt tab now opens a larger **Forever Wardrobe** workspace. The window grows only for this addon page and returns to the original search dimensions when you switch back. Its scale preference is preserved; no global UI scale or native window is changed.

- **All available types** combines the enabled armour/weapon options Forever exposes for the selected character/slot. Slot, type and weapon-category controls now open paged choice menus. Paper-doll slot icons around the model provide direct navigation and show profile overrides.
- **All collected** is the default. Owned appearances with restrictions or unknown usability remain visible as grey **preview-only** pieces, rather than silently disappearing. Choose **Usable only** to narrow the list locally. Readable optional source flags no longer have to be explicitly true when the client reports no use error. Unknown ownership is never treated as collected.
- Identical visuals are **grouped into one appearance**, with icon, name, collection/usability status and a source/type count. **Choose variant** lets you choose another collected source for that visual. Searching matches any alternate source's item name, item ID, source ID or visual ID; words are matched literally. Only already-cached item names are read when source names are missing; no bulk item-data requests are made.
- **Star appearance**, **Starred only** and **Stars first** provide addon-local appearance favourites, saved by visual ID in **ForeverSearchingDB.transmogFavourites**, up to 500. They do not change Blizzard's appearance favourites.
- **Find sources** opens the existing item search using the selected source's item ID, connecting it to recorded vendors, drops and quests where QuestieDB has coverage. Your wardrobe draft is retained when switching pages; acquisition data is not a guarantee that a particular source is currently available.
- **Undo piece / Redo piece** retain up to 20 appearance-edit snapshots in memory. These cover selecting pieces, clearing overrides and capturing a current look; they do not undo profile renames, deletion or native vendor actions. **Unsaved changes** distinguishes draft edits from saved profiles.
- The private model supports **zoom**, mouse-wheel zoom, rotation, **Reset view**, and **Compare worn / draft**. Comparing never equips gear or writes a native outfit. An **Outfit checklist** lists overrides and their known collection/usability status.
- **Collection diagnostics** reports client entries, unique owned visuals, preview-only source entries, unavailable data/API reads, and locally filtered results. Raw entry counts can repeat across types; these are diagnostics, not a claim to enumerate the whole game database.
- Collection/source/search changes and relevant item-cache events refresh the visible list automatically, with a short coalescing delay. Loading and sorting stay in cooperative work slices; hidden/combat pages do not start event-driven browsing, and superseded requests are cancelled.

**Coverage remains limited to what the client returns under the current native collection filters.** All available types does not force another class, enable disabled options, expose uncollected items, or alter race/faction/source/search settings. If a known unlocked look is missing, inspect the selected slot and local filters, open Blizzard's wardrobe, then use **Refresh collection** and **Collection diagnostics**. The addon will not reset native filters to widen results. Vendor loading rechecks the chosen visual and option for native usability, so preview-only browsing cannot bypass application restrictions. Final saving/payment remains your explicit click in Blizzard's screen.

**Movement fading:** both Search and Wardrobe smoothly fade to **35% opacity** during ground movement and return to full opacity when stationary or flying, including flight paths. Disable **Fade while moving** in the addon's Settings to keep them opaque. Only this addon's root frame is faded; no game CVar, global frame, keybind or other addon's window is changed. Combat still closes the window and leaves it closed afterward.

## Combat closing and transmog audit in 0.9.1

Entering combat **closes the entire Forever Searching window**, including the Transmog page, and cancels pending appearance browsing. It **stays closed after combat**; use `/find` or the minimap button to reopen it. Saved profiles are preserved, and an unsaved draft/name/selection remains in memory when you return to the Transmog tab. Unsaved drafts are not written automatically or guaranteed to survive a reload/logout. Closing the addon does not clear, load, save or apply Blizzard's pending transmog choices.

The protected targeting button means ordinary addon Lua must not hide its parent during combat lockdown. A separate addon-owned **SecureHandlerStateTemplate** controller, configured outside combat with a reference to our window, uses Blizzard's [secure state driver](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_RestrictedAddOnEnvironment/SecureStateDriver.lua) to hide only that window on combat entry. The handler has no show-on-exit branch, does not run gameplay actions and does not modify any Blizzard frame or saved setting. Keeping the controller separate preserves the portrait frame's native scripts.

The transmog audit also fixes invalid profile IDs, malformed profile rows breaking the list, a stale delete confirmation surviving edits, and missing appearance data being reported as a successful preview. The browser now displays an incomplete-preview warning. Existing data is preserved rather than deleting malformed entries.

The runtime still has **no keybinding or global game-settings write/reset calls**. All persistent addon data remains in **ForeverSearchingDB**. Transmog writing is limited to explicit **Load at vendor** preparation; the addon never commits/pays, enables transmog, changes shared collection filters, switches outfits automatically or equips actual gear. Build guards and offline tests reject the prohibited operations. Live-client secure hiding and transmog preview/application checks remain required before public release; offline checks cannot certify Blizzard behaviour or other addons.

## Transmog profiles in 0.9.0

Open `/find` and click the **shirt tab on the right**. The spyglass tab returns to Search. Profiles save account-wide in **ForeverSearchingDB.transmogProfiles** (up to 50); existing addon preferences, personal lists and sightings are preserved. QuestieDB is not needed for this tab.

1. Click **New**, enter a name, and either **Capture current look** or choose appearances for individual slots. Use the slot icons and Slot, Type and Category menus, then the search box to filter appearances locally. Click an appearance to preview it on your character. Rotate, zoom and compare the private model with its controls.
2. **Keep current for this slot** removes that profile override; it does not hide the actual equipped item. The base character look is restored in the preview when an override is removed. A collected hidden appearance, where returned by the client, can be selected to hide a slot instead.
3. **Save profile** creates or updates only the addon profile. Select a saved profile to edit it; change its name and Save to rename it, or Copy and Save to create a separate profile. Discard abandons draft edits. Delete requires a second explicit click. Unsaved edits block selecting another profile or starting a new one.
4. At a transmogrifier, open **Blizzard's transmog screen**, enable transmog yourself if desired, and choose an editable, unlocked Blizzard outfit. Save or discard any existing pending changes there. Return to the addon, select a saved profile and click **Load at vendor**.
5. The addon validates every selected appearance before preparing any changes. When successful it closes its own window to reveal Blizzard's pending preview. **Review Blizzard's warnings and price, then click its Save Outfit button yourself to apply/pay.** This edits the currently viewed Blizzard outfit; the addon does not create, rename, select, equip or save a native outfit automatically. Addon profile names are independent of native outfit names.

The browser shows readable **collected appearances**, including labelled preview-only pieces, as returned with the current native collection filters. Usable only is an optional local filter. It supplies the complete inventory-slot location required by Forever's API, and never changes class/race/faction/source filters, search text, favourites, collected/uncollected visibility or transmog opt-in. Existing native filters can therefore restrict the list; adjust them yourself in Blizzard's screen if desired. **Refresh slots** retries data discovery after that screen has loaded. Unknown collection/usability data stays unavailable rather than being assumed owned. Account-wide profiles may contain appearances unusable on another character; loading is blocked if validation fails.

Version 0.9.0 edits **primary armour and weapon appearances**. Separate shoulder overrides, weapon illusions and sheath-position options remain controlled by Blizzard and are not written by a profile. Their existing pending edits still block loading, so the addon cannot silently mix them with a profile. Previews are advisory and do not prove final eligibility: Blizzard's vendor warnings remain authoritative. This is an appearance manager; it never swaps actual equipment.

There is no automatic load when approaching/opening a vendor, no timers that apply transmog, no button-click simulation, no protected-action bypass, and no direct gold-spending commit call. Browsing is time-sliced, obsolete requests are cancelled, and combat blocks preview/profile/vendor actions. If a pending API write is refused, loading stops and reports that a partial pending preview may remain; review or discard it in Blizzard's screen. Nothing is committed by the addon. All model operations affect an addon-owned DressUpModel; the shared Dressing Room is not changed.

The integration was checked against the **Forever** branch of Blizzard's shipped [transmog vendor UI](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_Transmog/Blizzard_Transmog.lua), [outfit API documentation](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/TransmogOutfitInfoDocumentation.lua), and [collection API documentation](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/TransmogItemsDocumentation.lua). It uses the same public pending-appearance operation as the native UI, with the final save left to the player. The implementation avoids automation and restriction bypasses and was reviewed against Blizzard's published [Add-On Policy](https://eu.forums.blizzard.com/en/wow/t/wow-user-interface-add-on-development-policy/1642/1) and [EULA](https://www.blizzard.com/en-gb/legal/08b946df-660a-40e4-a072-1fbde65173b1/blizzard-end-user-license-agreement); this is not Blizzard approval or a guarantee about enforcement. **Vendor integration, actual preview rendering and protected-action behaviour still require testing in the live Forever client before public release.**

## Forever interface in 0.8.0

The visual reference is [Olympus Guild](https://www.curseforge.com/wow/addons/olympus-guild), particularly its [Guild-window screenshot](https://github.com/dnl-gentile/olympus-addon/blob/main/docs/olympus-1.jpg). Forever Searching now uses the client's **PortraitFrameTemplate** for the window, portrait ring and title bar, **InsetFrameTemplate** for the list and detail panels, and standard red **UIPanelButtonTemplate** controls. The spyglass portrait, dark list rows, Blizzard gold highlights and grey secondary text replace the previous custom bronze cards. The client supplies the window artwork, so the chrome follows its Forever UI rather than a bundled approximation. Templates missing on another client fall back to a native basic frame and simple dark insets.

This update changes only Forever Searching's own presentation. The native close button retains the addon combat guard; targeting retains its secure action template. No Blizzard window, global font, keybinding, CVar or game-setting API is changed. Existing preferences, window scale, saved lists, history and observations remain in **ForeverSearchingDB**. The folder and TOC filenames stay **ForeverSearching**; no migration is needed from 0.7.x. The release contains no Olympus code, assets or dependency. Visual rendering still needs verification inside WoW Forever.

## Keybinding safety

Version **0.7.1** displays **Forever Searching** in the interface and AddOns list. The installed folder, TOC filenames and **ForeverSearchingDB** stay unchanged, so upgrading from 0.7.0 needs no data migration. Replace the existing **ForeverSearching** addon folder with the one in the new archive; no WTF or binding/configuration files are included or edited.

The 0.7.1 audit fixed source filters interpreting quest-title keywords, stale filtered selections, unknown database records erasing observed item names, stale observed vendor listings, incomplete merchant snapshots, personal sightings bypassing known faction data during loading, and unknown quest-completion reads. Grouped previews now retain match explanations and choose the nearest source even when sorting names. Long search-history entries deduplicate correctly.

Regression checks cover these cases and verify that loading an existing installation preserves every valid addon preference and personal list. Game-settings and binding mutation APIs are replaced with failing guards throughout the offline suite. The release builder rejects references to those APIs (including aliases), requires the sole SavedVariables declaration to be ForeverSearchingDB, and verifies that TOCs load only packaged Lua modules. The archive contains only the addon folder, source modules, TOCs and README. This is source and package verification; live-client rendering and protected-action checks still require WoW Forever.

Versions 0.5.0–0.5.2 included automatic shortcut assignment and `SaveBindings` calls that could save the whole active binding profile. A user reported all bindings becoming unbound; the precise sequence on that installation has not been reproduced. Version 0.5.3 removed that code and the UPDATE_BINDINGS listener. Version 0.5.4 also removes Bindings.xml, binding labels and the global binding callback entirely. The addon does not register, assign, save, load, clear or override keybindings. Existing SavedVariables flags do not re-enable the old code. Use `/find` instead.

If affected, preserve a copy of the entire `_forever_/WTF` folder before further logouts, resets or binding saves, and disable the old addon version. Account-wide and per-character folders may contain `bindings-cache.wtf` and a previous `bindings-cache.old`. Preserve both files before inspecting or attempting restoration. An `.old` file may already have been overwritten; do not assume it is a good backup or replace your only copy. Once backups are preserved, any restoration should be done with WoW fully closed and the old addon disabled or replaced. This update prevents the automatic-write code path; it cannot reconstruct bindings that no longer exist in any backup. See this [Blizzard support forum discussion of the binding cache files](https://us.forums.blizzard.com/en/wow/t/shift-mouse-over-items-not-showing-item-comparison-with-or-without-any-addons/686921?page=2).

## Credits

ForeverSearching uses [QuestieDB](https://github.com/Questie/QuestieDB) through its public API for NPC, item, quest and location data. QuestieDB is developed and maintained by the **Questie team and contributors**. Thank you for making that data and integration API available.

QuestieDB remains a **separately installed, optional data dependency**. Its code and database are not bundled in ForeverSearching's download, and its own licensing and attribution terms apply. This acknowledgement does not claim that the QuestieDB maintainers contributed to or endorse ForeverSearching, or grant additional permissions. See [QuestieDB's licence notes](https://github.com/Questie/QuestieDB/blob/master/LICENSE.md).

The same dependency credit is visible beneath the author and GitHub link in the addon window.

## Install

Copy this folder to:

```text
World of Warcraft\_forever_\Interface\AddOns\ForeverSearching\
    ForeverSearching.toc
    ForeverSearching_Camelot.toc
    Work.lua
    Data.lua
    Evidence.lua
    Distance.lua
    Settings.lua
    ItemText.lua
    Sources.lua
    Personal.lua
    Results.lua
    QuestDetails.lua
    Merchants.lua
    Transmog.lua
    Core.lua
    ToolsUI.lua
    TransmogUI.lua
    UI.lua
```

Restart WoW and enable **Forever Searching** in the AddOns list. Open it with **`/find`**, or enter **`/find meat vendor`** to search directly. The spyglass button and `/fs`, `/foreversearching` aliases also work. The old `/sf`, `/searchingforever`, `/npcs`, `/npcsearch` aliases are retained. A closed window always opens in **All** mode; if the window is already open, its active mode is retained.

The archive is named **ForeverSearching-0.10.2.zip** and contains **ForeverSearching/**. With WoW closed, remove the old **Interface/AddOns/NPCSearch** addon folder, then extract the new **ForeverSearching** folder into AddOns. Do not merge with the old folder or keep both addons enabled: an older copy could still run its old code. Do not delete the WTF folder or rename other addons. The development source now lives in the repository's **ForeverSearching/** folder; tests and packaging tools remain outside the installable addon.

### Keeping preferences and sightings after the folder rename

WoW stores SavedVariables in a file named for the addon folder. A fresh **ForeverSearching** installation therefore starts with addon defaults unless you transfer its previous data. This does not reset WoW's own settings.

To keep the old addon data, first back up your WTF folder with WoW closed. In the relevant `_forever_/WTF/Account/<account>/SavedVariables/` directory, copy **NPCSearch.lua** to **ForeverSearching.lua**. Copy rather than remove the original. Do not overwrite an existing ForeverSearching.lua without backing it up and checking which copy you want to keep. Do not edit or rename binding/configuration files. The new addon can read the legacy NPCSearchDB table from that copied file and saves future addon data as ForeverSearchingDB. If current ForeverSearchingDB data already exists, it takes priority. The addon does not perform filesystem migration or modify any other addon's data.

Keep QuestieDB installed separately under its existing **QuestieDB** folder.

## Game-settings safety audit in 0.7.0

The reviewed runtime has no keybinding integration, CVar writes, console commands, graphics/audio resets, chat resets or Edit Mode layout writes. Scale/visibility changes target only ForeverSearching's own window and minimap launcher. **Reset defaults** replaces only `ForeverSearchingDB.settings`; it does not reset WoW settings, sightings, or other addons. Escape handling adds/removes only ForeverSearching's own window from WoW's close-window list. SavedVariables are limited to ForeverSearchingDB: addon preferences, sightings, favourites, recent queries, shopping entries, dated vendor observations and transmog profiles.

The intentional changes to game state are explicit button actions: **Show waypoint** replaces the shared user waypoint and enables its navigation indicator; **Target & mark** changes your current target and, subject to game permissions, its raid marker. These are not graphics, audio, layout or keybinding settings resets. No such actions run automatically at login or during reference indexing.

Provider map strings now use a numeric-data-only parser instead of Lua execution. The build also refuses known binding/configuration-writing APIs, executable data loaders or a Bindings.xml file. Offline tests replace game-settings mutation APIs with failing guards, including UIParent scale and minimap mutations, and exercise the startup, search, settings, reset and combat paths. This is a source/package audit, not a guarantee about unrelated addons or client-side behaviour; live-client verification remains necessary.

## Opening and closing

**`/find`** opens and focuses the search box. Entering it again keeps the window open and selects the current search text. **`/find search text`** runs a search directly. The addon has no keyboard shortcut integration. The minimap button can still open or close the window. Previously assigned keys are not edited or cleared by the addon.

**Escape** closes the entire search window, including when an addon text field has focus. With no edit field focused, it participates in WoW's normal Escape handling. Combat entry closes the window through its secure visibility handler. Native Escape registration is temporarily removed during combat and restored afterwards; ordinary window-opening/closing controls remain blocked until combat ends.

The dialog footer displays **By junglistloydee** and the GitHub profile URL. Click the URL and press **Ctrl+C** to copy it.

For the NPC catalogue, install the current **QuestieDB** release alongside this addon. Questie itself is not required. Use the packaged release, not GitHub's source archive, and ensure its active database is **Forever**. The integration requires QuestieDB API contract 4; older versions show an update message. Without QuestieDB, name targeting and your personal sightings still work.

Version 0.1.1 fixed packaged QuestieDB Forever releases being incorrectly rejected as the wrong expansion. The selected database flavour is read from the provider's shared flavour descriptor, since its mode indicator only reports an expansion in source mode. Failed or premature catalogue loads can be retried by closing and reopening the dialog.

- [QuestieDB releases](https://github.com/Questie/QuestieDB/releases)
- [Public API](https://github.com/Questie/QuestieDB/blob/master/docs/api.md)
- [Forever dataset and coordinate notes](https://github.com/Questie/QuestieDB/blob/master/docs/forever.md)

## Use

1. Browse the catalogue with an empty search, or search by NPC name, purpose, zone, or ID. Results are paged six at a time, with the nearest first by default. Each row shows the role, zone, coordinates, and estimated distance. Select a row for its details.
2. Cycle the raid icon selector, then click **Target & mark**. With no row selected, the typed text is used as an exact NPC name. This deliberately clears the previous target so a failed search cannot mark it.
3. Click **Show waypoint** on a selected NPC to navigate to its recorded location. This replaces the game's single shared user waypoint and activates native super tracking. Blizzard controls its map/minimap display and navigation indicator.
   Forever Searching also shows its own movable direction arrow beside the minimap. Use its X to dismiss it, or disable it in the addon's settings.
4. Click **I'm here, where are they?** to compare location evidence and inspect practical checks. Select a report and click **Waypoint to selected report** to try an alternate location. Use **Refresh** after moving, and **Back** to return to the catalogue.

## Faction filter

**My faction + neutral** is checked by default in the main window, including after upgrading. It excludes NPCs recorded by QuestieDB as friendly exclusively to the opposing player faction. Shared-faction NPCs and unclassified creatures remain searchable; an unclassified creature is not labelled neutral or assumed friendly. The player's current character determines Alliance/Horde, so switching characters uses that character's faction. This applies to NPC results and the linked NPC sources in item and quest searches.

Untick it to include all faction sources. The choice is saved account-wide and also appears in Settings. It does not reset other settings or remove records, and changes are blocked during combat. This is a database affiliation filter, not a live reputation or quest-eligibility check.

## Items, quests and vendor listings

Click the mode button at the right of the search field to cycle **NPCs → Items → Quests → All**. **All** is the default and is restored every time the closed window is opened, including for existing installations. You can choose another mode while the window remains open; refocusing it with `/find` preserves that active choice. Item and quest indexes are built only when needed, in background work slices, and stay in memory for the session. While those indexes load, All can show available NPC results; the footer identifies which catalogues are still loading. An empty All search browses NPCs rather than expanding every item/quest relationship.

All results share one nearest-first (or name) sort and the same faction/zone filters. Rows are labelled **NPC**, **Item**, or **Quest** to identify their origin. Related item sources from a quest result remain labelled as quest-search results. Reference-only rows without known NPC sources remain informational and cannot target an NPC.

- **Items:** shows known vendors, NPC drops, quest rewards, related quest givers/turn-ins, and quests started by the item. Each result identifies the recorded relationship and NPC where known; a related quest is not automatically a quest that awards the item. Results with locations retain nearest-first sorting. Selecting a result prepares targeting for the source NPC, never for the item's name.
- **Quests:** shows recorded quest givers, turn-in NPCs, NPC objectives, and sources for required, quest-provided or quest-starting items. Quest-provided items are labelled separately from requirements. These are reference links, not a claim that your character can accept the quest or needs to buy a provided item. Related reward quests can appear as item sources.
- **Vendor items:** select an NPC source and click this button in the details panel. The list combines QuestieDB's item-to-vendor links with your recorded vendor visits. Hover an item for the game's item tooltip, or click it to search for its sources.

QuestieDB provides item names, vendor NPC IDs, NPC-drop links, quest-reward links and quest relationships. Database entries alone do not provide stock or prices. Personal visits can supplement them with dated stock and buying-price observations, which may have changed since the visit. Inventories are not guaranteed complete. Unknown and unmapped sources are labelled instead of receiving invented NPCs or coordinates. Object-only sources are not mapped by these NPC-source views. Rows without an identified NPC cannot trigger targeting or NPC waypoints. Faction and current-zone filters can hide otherwise-known sources.

## Search tools added in 0.7.0

Items and quests appear **once per matched entity** by default. Click **+** to expand the result into labelled **Vendors**, **NPC drops**, **Quests** and other-source sections; click the header again to collapse it. A quest's required-item links stay under the quest you searched for. The collapsed row uses its closest eligible source for sorting and the location preview. Select a specific source before targeting or placing a waypoint. Group headers and section headings never prepare NPC targeting macros. Settings can restore the flat source list.

The toolbar's source button cycles **All sources → Vendors → NPC drops → Quest rewards → Quest givers**. **Known spots** keeps only sources with usable recorded locations. These filters combine with your existing faction and zone choices, including in All mode. The detail panel explains whether the match came from a name, ID, NPC purpose, zone, or cached item description/type. Empty results distinguish loading, unavailable QuestieDB, discarded source/location matches and limited description coverage; missing data is not proof that an item or NPC is absent.

**Favourites:** select a result and click Favourite, then open Favourites from the toolbar to search it again by its canonical ID and type. Click × to remove it. Up to 200 favourites are saved account-wide.

**Recent:** pressing Enter, choosing a result, running a direct slash search or opening a saved entry records the query and mode. Live keystrokes are not recorded. The latest 20 distinct query/mode pairs are retained; click an entry to rerun it, or × to remove it.

**Shopping:** select an item or a quest's linked item and click Shopping +1. In the Shopping panel, select an entry to adjust its quantity, mark it done/undo, find its sources or remove it. Completion is manual; the addon does not purchase items or inspect inventory to mark them complete. Up to 100 entries are saved, with quantities from 1 to 9,999. Shopping searches retain the active faction, zone and source filters.

**Requirements:** select a quest result or linked quest source and click Requirements. The scrollable panel shows recorded minimum level, class/race restrictions and prerequisite quests, with your readable level/class/race and completion status where the client exposes them. Profession/reputation tuples and special prerequisite conditions are displayed as recorded rather than assumed satisfied. Missing restrictions mean “none recorded”, not guaranteed eligibility. Event, phase and other availability conditions can remain unknown. No quest is accepted, completed or rewarded automatically.

**Visited vendors:** with Remember visited vendor stock enabled, opening a merchant outside combat records readable item IDs/names, buying prices, purchase-bundle size, stock, extended-cost flags, timestamp and observing character name. Buyback lists are excluded. Indexing is batched and cancelled when the merchant closes or changes. Prices are shown per item when bundle size is known; other currency costs are flagged rather than assigned an invented value. A dated observation is historical, even while the merchant is currently open. Stock may differ by character, reputation, phase or later restocks.

Vendor items includes observed entries missing from QuestieDB, and those entries can also be searched for their observed seller. The addon saves up to 200 vendor snapshots and inspects at most 300 slots per visit. Unreadable, unavailable or unlinked entries are skipped; this is not a complete inventory guarantee. QuestieDB remains separate and unchanged. All personal tools and preferences stay in **ForeverSearchingDB**; none of these features writes game settings or keybindings.

## Item description searches

Items and All accept player-readable names, IDs, item types/subtypes and available descriptions. For example, **food that restores health** can match a cached food tooltip describing restored health. Simple keyword matching ignores a few common English filler words; it does not infer arbitrary synonyms or use an AI service. Item IDs remain the lookup keys for vendor, drop and quest relationships, regardless of which text matched. Hover an item result for its game tooltip.

QuestieDB does not supply full item tooltip descriptions. The addon uses the client's instant type information, and reads tooltip/flavour text only when `C_Item.IsItemDataCachedByID` reports the item cached. It never mass-requests uncached item data. Description coverage therefore depends on the game cache, available APIs and client language. After inspecting an item, re-run the search to include newly cached descriptions. If tooltip APIs are unavailable, names and IDs continue working. Description indexes live in memory and are reused for the session, not saved in SavedVariables.

- [QuestieDB item schema](https://github.com/Questie/QuestieDB/blob/master/src/meta/itemMeta.lua)
- [QuestieDB public API](https://github.com/Questie/QuestieDB/blob/master/docs/api.md)

Targeting requires a real player click, the exact localized name, and the game's targeting range. It cannot find or target an arbitrary NPC anywhere in the world. Search and window changes pause during combat. Applying raid markers follows normal group permissions; a selected icon is not proof the game applied it. Set **No marker** to target without applying an icon. It does not remove an existing icon.

## NPC purposes and locations

With QuestieDB installed, the catalogue lists every valid named NPC returned by its active Forever database. Roles come from titles, service flags, quest start/turn-in links, and rare rank. Multiple purposes are displayed together; unknown purposes are explicitly labelled. A quest giver label does not mean your character can currently accept its quests. The list can include hidden, event-only, obsolete, or unavailable creatures; coverage and accuracy follow the source database.

The addon also remembers NPCs you target, mouse over, or see on nameplates outside combat. Merchant, trainer, taxi, and quest interactions add observed purposes. Up to 2,000 personal sightings are saved account-wide through normal SavedVariables. Position is **your position when you saw the NPC**, never an exact measurement of the creature's position, and is labelled **Last seen nearby**. Sightings can become stale and remain separate from database evidence.

The default waypoint uses the closest comparable eligible location across personal sightings and unphased database spawns. Database locations are labelled **Database spawn (may vary)**. Spawn coordinates are already converted in the Forever dataset; this addon does not convert them again. Unknown maps, unsupported waypoints, instance sentinels, and phase-specific points are skipped for navigation. These are static destinations, not live tracking of a moving NPC. The waypoint uses Blizzard's native pin; the chosen raid icon is placed on the NPC separately.

## Nearest-first results and settings

Search for a service such as **Meat Vendor** to list matching NPCs from closest to furthest. If an NPC has several eligible locations, its closest one is used for the result row and default waypoint. Location evidence still lets you inspect and navigate to other reports explicitly.

Distances are approximate straight lines in yards to the recorded position, not walking routes, travel times, or proof that an NPC is currently present. World coordinates allow comparison across zone boundaries on the same continent. When those are unavailable, physical map dimensions can measure distances within the same map. Normalized coordinates from different maps are never compared directly. Unmeasurable locations appear after measured results, followed by NPCs without eligible positions. If your position is unavailable, sorting falls back to names.

Open **Settings** at the top of the dialog to change:

- **Sort:** closest to furthest (default), or NPC name.
- **Show estimated distances:** hide or show distance labels without changing the chosen sort.
- **Refresh order while moving:** refresh when your map position changes, checked every two seconds while the catalogue is visible outside combat. It pauses while any evidence, settings, vendor or personal-tools panel is open.
- **Current zone only:** restrict locations to the player's current map. This can hide all results if the player's map position is unavailable.
- **My faction + neutral:** exclude known opposing-faction NPC sources; uncheck to search all factions.
- **Remember NPC sightings:** turn off future recording without deleting existing sightings or disabling the database.
- **Remember visited vendor stock:** record future readable merchant listings; turning it off preserves existing records.
- **Group item / quest sources:** show one expandable result per matched item or quest, enabled by default.
- **Show minimap button:** `/npcs` and `/npcsearch` remain available if it is hidden.
- **Window scale:** 80% to 120%, in 5% steps.

Changes save automatically in account-wide SavedVariables. **Reset defaults** restores these preferences without erasing sightings, favourites, history, shopping entries or vendor records, or changing the chosen target marker. Settings changes pause during combat.

## Loading performance

Version 0.3.1 spreads catalogue import, location indexing, filtering and result sorting across cooperative work slices targeting 3 ms, with an additional operation limit per slice. A single QuestieDB or game API call cannot be interrupted, so this is a scheduling target rather than a hard frame-time guarantee. Work pauses in combat. The catalogue progress remains visible; nearest-first searches show a searching message until a complete result snapshot is ready.

The import triggers one final ranking pass instead of repeatedly sorting the growing catalogue. Distance sorting builds a compact position index instead of formatting and sorting every NPC's full evidence list. Map names and map waypoint capabilities are cached; individual NPC position indexes are reused in memory. Pagination and selection reuse completed search results. New queries cancel obsolete searches, repeated refresh requests are coalesced, and closing the dialog cancels a pending search. No extra database copy is saved in SavedVariables.

`tests/performance.lua` benchmarks a synthetic 3,000-NPC catalogue. It checks scheduling and API call counts, not in-game FPS or actual QuestieDB decompression time. QuestieDB's own addon initialization and individual decode calls are outside ForeverSearching's ability to time-slice.

## Location evidence and missing NPCs

The location evidence panel keeps sources separate, including differing reports for the same NPC:

- **Personal sighting:** when you targeted, moused over, or saw the NPC on a nameplate. Its timestamp and observation method are shown.
- **Interaction confirmed:** when a merchant, trainer, taxi or quest interaction identified that NPC. This confirms the NPC was present at that time; coordinates still describe the observer's position.
- **QuestieDB spawn:** every distinct recorded spawn location, rather than only the default waypoint. These have no observation timestamp and do not prove the NPC is currently present.

Up to eight recent personal reports per NPC are saved. Repeated reports of the same kind within 0.5 coordinate percentage points on the same map replace older nearby reports. Older version 0.1.x sightings remain usable and are labelled **Earlier sighting**, never retroactively upgraded to confirmed interactions. If an observation has no map position, it remains evidence of a sighting/interaction without receiving invented coordinates or updating an older location's timestamp.

Reports are paged three at a time. Duplicate database points are combined; different phases remain separate. Phase-tagged reports and unmapped locations can be inspected but cannot be used as waypoints. Invalid coordinates and instance-presence sentinels are omitted. Evidence is presented with recent personal reports first; the default search waypoint uses the nearest comparable eligible report, and you can choose a different report explicitly.

**I'm here, where are they?** explains the selected source's limits, flags a different map and personal reports over a day old, and offers alternate reports and entrance/floor checks. Its suggestions are not NPC-specific directions. Entrance, floor, respawn, patrol, event and quest/phase conditions are explicitly unknown; it does not infer absence, death, respawn timers or phase access from a failed target search.

## Data integration

QuestieDB is an optional, separately installed provider read through `LibQuestieDB`. ForeverSearching does not download data in game, scrape Wowhead, copy QuestieDB tables into its distribution, or change the provider's data. Its catalogue indexes are built in batches outside combat and kept only in memory. QuestieDB's own licensing and provenance remain with that project. No claim of complete coverage is made.

The integration is based on the public QuestieDB contract and Forever API research. The author has tested core flows in the live Forever client, including loading saved transmog sets; broader compatibility and combat/taint checks remain necessary. Check the running client's interface version with `/dump select(4, GetBuildInfo())` when updating to a new patch.

## Policy review for public release

Reviewed on **15 November 2026** against Blizzard's [UI Add-On Development Policy](https://eu.forums.blizzard.com/en/wow/t/wow-user-interface-add-on-development-policy/1642/1) and published [EULA](https://www.blizzard.com/en-gb/legal/08b946df-660a-40e4-a072-1fbde65173b1/blizzard-end-user-license-agreement). This is a code review, not approval from Blizzard or a guarantee against enforcement.

The reviewed runtime uses in-client Lua APIs and an optional installed database. Targeting/marking requires a player click on a secure action button; timers only process reference data or inspect the result of that click. No movement, combat, purchases, quest acceptance, button presses, transmog commits or chat messages are automated. Restricted/secret data is skipped, combat locks are respected, and uncached item data is not mass-requested. Personal sightings stay in SavedVariables; no telemetry, account credentials, network client, or external executable is shipped. Blizzard textures are referenced in the client rather than copied into the archive. The map table decoder parses numeric data without executing Lua strings.

The package contains readable Lua/XML, without paywalls, advertisements or donation prompts. For publication, keep the addon free and its code publicly readable; do not add paid functionality or in-game monetization prompts. Blizzard retains discretion over permitted functionality. Its policy lists WoWUI@blizzard.com for questions; no message has been sent on your behalf.

Live-client performance, combat/taint checks and functionality testing remain required before a public release. Review your own code's licence and third-party dependency/attribution obligations separately; this review does not settle those rights. QuestieDB remains separately installed and is not bundled here. There is no claim of Blizzard endorsement or certification.

## Validation

Run the offline regression checks from this directory with Lua 5.1+:

```text
lua tests/run.lua
```

Or install a local JavaScript-hosted Lua runner with `npm install --prefix .tools fengari-node-cli`, then run `node .tools/node_modules/fengari-node-cli/src/lua-cli.js tests/run.lua`.

In game, enable Lua errors with `/console scriptErrors 1`, then `/reload` and check:

- Open, drag, close, and reopen the dialog; paginate and search with and without QuestieDB.
- Select a nearby NPC and try each icon, including No marker. Search for a nonexistent name while another target is selected; it should leave no target and should not mark the previous one.
- Enter combat with the window open and closed; click controls, leave combat, and confirm normal operation resumes without blocked-action errors. Also test a `/reload` during combat.
- Place a waypoint from a sighting and one from QuestieDB, checking both the world map and minimap; test a map that does not support user waypoints.
- Interact with a merchant/trainer/flight master, then relog and check that its sighting and purpose remain.
- Open location evidence on an NPC with personal and database reports. Select each report, paginate, refresh, and place alternate waypoints. Check that phase-tagged and unmapped reports cannot place waypoints.
- Check an old saved sighting, a report without coordinates, and an NPC with no evidence. Open the panel during normal play, enter combat, and confirm its controls pause until combat ends.
- Search for Meat Vendor or Innkeeper, move to another area, and check that rows reorder by estimated distance and the default waypoint matches the displayed location. Check adjacent maps and other continents.
- Change sorting, distance labels, movement refresh, current-zone filtering, recording, minimap visibility and scale. Relog to verify persistence, then reset defaults and check that sightings remain intact.
- During a first catalogue load, keep moving and type different searches. Check loading progress, that only the latest query is displayed, and that work pauses and resumes across combat. Close and reopen during a pending search.
- Check the default faction checkbox on Horde and Alliance characters, then untick it and verify opposite-faction NPCs return. Search for items and quests, inspect their NPC/item sources, and open a vendor's known item list. Confirm item tooltips and source targeting in game.
- Choose All and verify mixed result labels, global distance ordering and filters. Search an item by its cached tooltip text, then inspect an uncached item and re-run the search. Confirm vendors, rewards and related quests are labelled as distinct relationships.
- Check `/find`, `/find meat vendor`, repeated opening/focusing and combat restrictions. Verify that login, settings resets, search and reloads do not change unrelated bindings, and that the installed addon folder contains no Bindings.xml. Never test binding recovery without first preserving copies of the original files.
- Expand an item/quest result, inspect each source section, select a real NPC source and confirm targeting. Cycle every source filter and Known spots, including searches that become empty.
- Favourite an item and a quest, rerun them from Favourites, and remove an entry. Commit queries with Enter and confirm typing alone does not fill Recent. Add shopping quantities, manually mark done/undo and rerun item-source searches; relog to check persistence.
- Inspect quests with level, class/race and prerequisite restrictions. Compare recorded facts to the quest's actual availability; unknown or special conditions must not be presented as satisfied.
- Visit a vendor with limited stock, inspect the dated price/quantity labels, close the merchant and reopen its saved item list. Check bundle prices, extended currency flags and observations on another character. Disable recording and confirm existing records stay intact. Ensure no purchase or quest action occurs automatically.

Offline tests cover macro input validation and ordering, combat guards, secret values, role classification, optional catalogue data, map conversion, and native waypoint requests. They cannot prove protected action behavior, visual rendering, or live database compatibility; those require the client checks above.

Transmog regressions in `tests/transmog.lua` are included by the same runner. They check saved-profile operations and limits, slot/option mapping, collected-only browsing, private model operations, cancellation, combat guards, preservation of pending edits (including illusions and secondary shoulders), unavailable/secret data, complete preflight before staging, and stopping on a refused pending write. Final-commit and native collection-settings APIs fail the tests if called. In-game, compare the model to the vendor preview, verify the selected native outfit and displayed price, and apply only through Blizzard's own button. Check that cancelling the native preview leaves the actual look unchanged and that profiles persist after relogging.
