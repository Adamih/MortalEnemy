# Mortal Enemy

A small WoW Forever addon for remembering rivals and mortal enemies, on either
faction. Mark a player, keep a note, and recognize them when you meet again.
The other player does not need the addon. Version 0.6.1 targets interface 16001.

## First run

The addon is already installed when this folder is at
`_forever_/Interface/AddOns/MortalEnemy/`.

1. Restart WoW if it was running when the addon files were added. Enable **Mortal
   Enemy** in the character selection AddOns list. Subsequent Lua edits need only
   `/reload`.
2. Enter the game. Look for the Mortal Enemy loaded message.
3. Click the **skull button on your minimap** to open the book. The target strip
   shows the full name of your selected player; click **Mark as Rival** or
   **Mark as Mortal Enemy**. The buttons are disabled for yourself, NPCs, and
   players whose identity or realm cannot be verified.
4. Enable the appropriate friendly/enemy nameplates in WoW's own settings. The
   addon does not change your nameplate settings.
5. Look for a **sword** (rival) or **skull** (mortal enemy) icon just left of
   their health bar. There is no separate persistent status badge at the top of
   the screen.

The book lets you select an entry, edit its note, change its status, and remove it.
Click **Settings** to open the addon preferences in WoW's Settings → AddOns →
Mortal Enemy page. Preferences remain separate for rivals and mortal enemies.
The book is draggable and closes with Escape.
Type `/mortal preview` to preview the encounter alert without adding anyone.

Click the minimap skull again to close the panel. Drag it around the minimap edge
to move it out of the way; the position is saved independently for each character.
Hover it for instructions. Uncheck **Show minimap button** on the AddOns settings
page to hide it. This preference is saved per character; use `/mortal settings`
to open the preferences and enable the button again.

## Book of Grudges

The main window uses Blizzard's native portrait frame, with a skull portrait,
standard title/close controls, native inset panels, and All / Rivals / Enemies tabs.
The left pane is a scrollable list; use the mouse wheel or drag the scrollbar.
Search matches full names and personal notes, combined with the active tab.
The right pane shows the selected player's relationship, last recorded sighting,
date added, and an editable grudge. Save the note or change/remove their relationship
from that pane. Adding a player clears search/filters and scrolls to their entry.
The target strip remains above both panes, and Add player uses matching native
window chrome. Settings stay on WoW's separate AddOns preferences page.

## Character information

The detail pane shows the last recorded **level, race, and class**, with a separate
observation time for each field. Its header uses a class icon plus a Horde or
Alliance emblem when faction has been observed. A question mark represents an
unknown class; an unknown or neutral faction has no emblem. Rival/enemy icons in
the list, nameplates, and encounter alerts keep their existing appearance. Unknown fields stay labelled unknown until the
game provides them. These are observed snapshots, not remote live lookups.

Marking your target captures the readable fields immediately. Marking from a
player menu captures them while the menu opens, so a later target change cannot
save another player's details. Name-only additions start without character data
unless that player is already your current target.

Targeting a saved player refreshes the snapshot immediately. The addon retries
every five seconds while they remain targeted and responds to target level/name
updates. This works without an available nameplate when the target's identity is
readable. Missing, restricted, invalid, or unknown fields never erase the previous
values or advance those fields' observation dates. Personal notes and relationship
status are not changed by these updates. There is no background lookup of offline
players or character-data polling of arbitrary nearby units.

## Adding players

- **Player right-click menu:** right-click a player portrait or supported player
  menu and choose **Mark as Rival** or **Mark as Mortal Enemy** under Mortal Enemy.
  The action uses the player whose menu you opened, even if you change targets.
  NPCs, yourself, off-realm players, restricted identities, and combat menus are
  left unchanged. Menu-only names require a complete name and same-server check.
- **Add by name:** click **Add player** in the list, enter first and last name,
  optionally add a note, then choose **Add Rival** or **Add Mortal Enemy**. This
  records a name on your current realm; it does not verify that the character exists.
- **Current target:** the named target strip provides both relationship buttons
  without opening another window. It updates when you change targets.

No keybindings are added. The main list has a separate Settings button; alert
previews and display controls live on the actual WoW addon settings page.

## Commands

`/mortalenemy` is an alias for `/mortal`. `/me` remains WoW's emote command.

| Command | Action |
| --- | --- |
| `/mortal` or `/mortal list` | Open/close the book |
| `/mortal settings` | Open WoW's Mortal Enemy AddOns settings page |
| `/mortal rival [note]` | Mark the targeted player as a rival |
| `/mortal enemy [note]` | Mark the targeted player as a mortal enemy |
| `/mortal note <text>` | Update the saved target's note; omit text to clear |
| `/mortal remove` | Remove the targeted saved player |
| `/mortal remove First Last` | Remove an entry by name |
| `/mortal add enemy First Last [note]` | Manually add an enemy |
| `/mortal add rival First Last [note]` | Manually add a rival |
| `/mortal badges [rival\|enemy]` | Toggle badges for one status or both |
| `/mortal tooltip [rival\|enemy]` | Toggle tooltip details for one status or both |
| `/mortal alerts` | Toggle encounter banners and chat alerts |
| `/mortal sound` | Toggle alert sounds |
| `/mortal preview` | Preview a five-second alert |
| `/mortal diagnose` | Print client version and identity availability |
| `/mortal help` | Show command help |

Only players on your current realm can be added or recognized. Commands take a
complete first and last name; realm suffixes are not accepted. For example,
`/mortal add enemy Bram Redfen Killed me while fishing`. Quoted names work too:
`/mortal add rival "Bram Redfen" A worthy opponent`.
Notes are limited to 240 bytes when saved. Marking the same player again keeps
their note unless you provide a replacement.

## Open-world display options

Open **Settings → AddOns → Mortal Enemy**, or use `/mortal settings`. Each row controls
one status independently, using amber for rivals and red for mortal enemies:

- **Badge:** a compact sword/skull icon just left of the visible health bar.
  On name-only plates it sits to the left of the player's name.
  Targeting the player does not create a second badge elsewhere on screen.
- **Tooltip:** adds your relationship to the normal player mouseover tooltip.
- **Note:** include the personal note in the tooltip, or show only the relationship.

All three options start enabled for each status. An existing disabled badge
preference stays disabled when upgrading. Settings are saved per character.
Changes apply to currently recognized nameplates and an open player tooltip;
removing a saved player also clears their tooltip annotation. Switching the
underlying tooltip to an unrelated player, item, or NPC clears the extra lines.
Encounter alerts, sound, the minimap button, and the alert preview are on the same settings page.

Nameplates must be enabled in WoW. A tooltip can still work without nameplates
when the hovered player's identity is accessible. Third-party nameplate layouts
may affect the icon's placement; visual compatibility needs live testing.

## Recognition and data

Each character has an independent list and settings, saved with WoW's
`SavedVariablesPerCharacter` as `MortalEnemyCharDB`. WoW writes these on normal
logout or `/reload`. The old development version's shared list is discarded;
there is no migration. No server, external requests, or messages to other players
are used.

Recognition checks available player identities from visible nameplates, your
target, and mouseover. Only your current realm is accepted. Badges require an
accessible nameplate. Names identify entries within that realm; a known player
GUID can also match a renamed character. A readable conflicting GUID prevents a
name match. Forever's `UnitName` surname is never interpreted as a realm. The
addon uses `GetUnitName` for the complete name and `UnitIsSameServer` to check
eligibility. If the full name or same-server result is restricted, recognition
is skipped. Targeting failures explain which check failed; `/mortal diagnose`
also reports the same-server check.

An encounter produces a five-second banner, a chat line, and an optional raid
warning sound. Continuous visibility does not repeatedly announce the same player.
A returning player can alert again after a two-minute cooldown. The book stores
last-observed zone and time, updated at most every ten seconds while recognized.
This is your observation history, not the player's current remote location.

## Forever restrictions and test status

**Actual in-game recognition and appearance are not yet verified.** In particular,
untargeted opposing players during world PvP must be tested in the live client.
Forever may restrict names, GUIDs, player flags, or access to nameplates depending
on context. Restricted identities are skipped; the addon does not infer or bypass
them. It does not detect hidden players, players outside the client's available
units, or players on another layer. Kill/death attribution is outside this MVP.

Implementation references are the `forever` branch of Blizzard's exported UI:

- [Unit APIs](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua)
- [Identity restrictions](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/SecretPredicatesDocumentation.lua)
- [Nameplate lifecycle](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_NamePlates/Blizzard_NamePlates.lua)

If a player is not recognized, target them and run `/mortal diagnose`. Repeat with
them untargeted but their nameplate visible, and during combat. The output reports
**restricted**, **missing**, or **readable** without printing restricted values.

### In-game acceptance checklist

- [ ] Loads without Lua errors; `/mortal` opens and closes the book.
- [ ] Native portrait frame, inset panes, and tabs render correctly.
- [ ] List scrolls with the wheel/scrollbar; search and status tabs combine.
- [ ] Selecting a row shows class, race, level, sighting history, and its editable note.
- [ ] Targeting a saved player updates readable character fields and their dates.
- [ ] Restricted/missing fields retain their previous values and observation dates.
- [ ] Settings button opens the actual WoW AddOns preferences page.
- [ ] Player right-click actions mark the clicked character after retargeting.
- [ ] Add-by-name form validates first/last name and saves optional notes.
- [ ] Target strip shows the selected full name and disables invalid targets.
- [ ] A same-faction player's rival badge appears without targeting them.
- [ ] An opposing-faction player's enemy badge appears without targeting them.
- [ ] Repeat outside combat and during open-world PvP; capture diagnostics if restricted.
- [ ] Notes/status survive `/reload` and a full logout/login.
- [ ] Recycled nameplates do not display a previous player's badge.
- [ ] Toggle Badge and Tooltip separately in each relationship row.
- [ ] Badge is icon-only, left of the bar; Note hides only the tooltip note.
- [ ] Rival settings do not change enemy settings, and vice versa.
- [ ] Removing an entry clears its badge and open tooltip annotation.
- [ ] Hover players, then NPCs/items: no stale or duplicate relationship lines.
- [ ] Tooltip details update after editing notes/status while it is open.
- [ ] Repeated target changes do not spam encounter alerts.
- [ ] Check badge position with your preferred nameplate addon, if any.

## Local verification

Run from this folder:

```sh
lua5.1 tests/run.lua
luac -p Core.lua Display.lua Window.lua MortalEnemy.lua tests/run.lua
```

The standalone simulated client covers initialization, player/NPC/self filtering,
Forever first/surname handling, current-realm filtering, GUID matching,
character isolation, restricted and failing API reads, CRUD commands, nameplate
reuse, forbidden plates, world transitions, encounter cooldowns, window actions,
independent display settings and tooltip annotation/rebuilds,
and saved-data preservation. It cannot verify rendering, protected-frame rules,
or live PvP identity availability. Tests are not loaded by the addon's TOC.
