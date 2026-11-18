# Mortal Enemy

A small WoW Forever addon for remembering rivals and mortal enemies, on either
faction. Mark a player, keep a note, and recognize them when you meet again.
The other player does not need the addon. Version 0.3.1 targets interface 16001.

## First run

The addon is already installed when this folder is at
`_forever_/Interface/AddOns/MortalEnemy/`.

1. Restart WoW if it was running when the addon files were added. Enable **Mortal
   Enemy** in the character selection AddOns list. Subsequent Lua edits need only
   `/reload`.
2. Enter the game. Look for the Mortal Enemy loaded message.
3. Type `/mortal` to open the book. Target another player and click **Target:
   Rival** or **Target: Mortal Enemy**.
4. Enable the appropriate friendly/enemy nameplates in WoW's own settings. The
   addon does not change your nameplate settings.
5. Look for an **amber sword + Rival** or **red skull + Mortal Enemy** badge above
   their nameplate. Your selected rival also gets a status line near the top
   center of the screen.

The book lets you select an entry, edit its note, change its status, remove it,
and customize displays separately for rivals and mortal enemies. It is draggable
and closes with Escape.
Type `/mortal preview` to preview the encounter alert without adding anyone.

## Commands

`/mortalenemy` is an alias for `/mortal`. `/me` remains WoW's emote command.

| Command | Action |
| --- | --- |
| `/mortal` or `/mortal list` | Open/close the book |
| `/mortal rival [note]` | Mark the targeted player as a rival |
| `/mortal enemy [note]` | Mark the targeted player as a mortal enemy |
| `/mortal note <text>` | Update the saved target's note; omit text to clear |
| `/mortal remove` | Remove the targeted saved player |
| `/mortal remove First Last` | Remove an entry by name |
| `/mortal add enemy First Last [note]` | Manually add an enemy |
| `/mortal add rival First Last [note]` | Manually add a rival |
| `/mortal badges [rival\|enemy]` | Toggle badges for one status or both |
| `/mortal glow [rival\|enemy]` | Toggle nameplate glow for one status or both |
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

Open `/mortal` and use the **Open World Display** section. Each row controls
one status independently, using amber for rivals and red for mortal enemies:

- **Badge:** sword/skull icon above a recognized nameplate. Also controls the
  existing target status line.
- **Glow:** a static, layered colored outline around the nameplate. It uses
  addon-owned borders and does not recolor or replace the underlying health bar.
- **Tooltip:** adds your relationship to the normal player mouseover tooltip.
- **Badge text:** show the relationship label next to the nameplate icon, or
  keep only the icon.
- **Note:** include the personal note in the tooltip, or show only the relationship.

All five options start enabled for each status. An existing disabled badge
preference stays disabled when upgrading. Settings are saved per character.
Changes apply to currently recognized nameplates and an open player tooltip;
removing a saved player also clears their tooltip annotation. Switching the
underlying tooltip to an unrelated player, item, or NPC clears the extra lines.
Encounter alerts and sounds remain separately configurable below the matrix.

Nameplates must be enabled in WoW. A tooltip can still work without nameplates
when the hovered player's identity is accessible. Third-party nameplate layouts
may affect the outline's placement; visual compatibility needs live testing.

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
- [ ] A same-faction player's rival badge appears without targeting them.
- [ ] An opposing-faction player's enemy badge appears without targeting them.
- [ ] Repeat outside combat and during open-world PvP; capture diagnostics if restricted.
- [ ] Notes/status survive `/reload` and a full logout/login.
- [ ] Recycled nameplates do not display a previous player's badge.
- [ ] Toggle Badge, Glow, and Tooltip separately in each relationship row.
- [ ] Icon-only mode hides the badge label; Note hides only the tooltip note.
- [ ] Rival settings do not change enemy settings, and vice versa.
- [ ] Removing an entry clears its badge, glow, and open tooltip annotation.
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
independent display settings, glow cleanup, and tooltip annotation/rebuilds,
and saved-data preservation. It cannot verify rendering, protected-frame rules,
or live PvP identity availability. Tests are not loaded by the addon's TOC.
