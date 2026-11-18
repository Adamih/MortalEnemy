# Mortal Enemy

A small WoW Forever addon for remembering rivals and mortal enemies, on either
faction. Mark a player, keep a note, and recognize them when you meet again.
The other player does not need the addon. Version 0.2.0 targets interface 16001.

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
and toggle badges, alerts, or sound. It is draggable and closes with Escape.
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
| `/mortal remove Name` | Remove an entry by name |
| `/mortal add enemy Name [note]` | Manually add an enemy |
| `/mortal add rival Name [note]` | Manually add a rival |
| `/mortal badges` | Toggle nameplate and target badges |
| `/mortal alerts` | Toggle encounter banners and chat alerts |
| `/mortal sound` | Toggle alert sounds |
| `/mortal preview` | Preview a five-second alert |
| `/mortal diagnose` | Print client version and identity availability |
| `/mortal help` | Show command help |

Only players on your current realm can be added or recognized. Commands take a
plain player name; realm suffixes are not accepted.
Notes are limited to 240 bytes when saved. Marking the same player again keeps
their note unless you provide a replacement.

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
name match. If realm information is restricted, recognition is skipped.

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
- [ ] Removing an entry or disabling badges hides its badges immediately.
- [ ] Repeated target changes do not spam encounter alerts.
- [ ] Check badge position with your preferred nameplate addon, if any.

## Local verification

Run from this folder:

```sh
lua5.1 tests/run.lua
luac -p Core.lua Display.lua Window.lua MortalEnemy.lua tests/run.lua
```

The standalone simulated client covers initialization, player/NPC/self filtering,
current-realm filtering, GUID matching, character isolation, restricted and failing API reads, CRUD commands, nameplate
reuse, forbidden plates, world transitions, encounter cooldowns, window actions,
and saved-data preservation. It cannot verify rendering, protected-frame rules,
or live PvP identity availability. Tests are not loaded by the addon's TOC.
