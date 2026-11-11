# LootBeacon

A WoW Forever addon (formerly Shiny Things / Loot Lantern) that puts icons over lootable things around you and manages minimap tracking.

## Features
- Icons over chests, containers, herbs, ore, fishing pools, quest objects and corpses (uses the game's soft-target icons)
- Loot-only mode: benches, chairs, mailboxes and NPCs get no icon
- Quest objects are matched against your unfinished quest objectives and quest titles
- Ignore list and allow list you can edit in game
- Remembers your minimap tracking (herbs, ore, treasure, fish) and turns it back on after you die

## Commands
| Command | What it does |
|---|---|
| `/beacon` | Turn object icons on or off |
| `/beacon lootonly` | Turn loot-only mode on or off |
| `/beacon ignore [word]` | Ignore the object in front of you, or anything matching a word |
| `/beacon unignore <word>` | Remove a word from the ignore list |
| `/beacon allow [word]` | Always show the object in front of you, or anything matching a word |
| `/beacon unallow <word>` | Remove a word from the allow list |
| `/beacon herbs` / `ore` / `treasure` / `fish` | Set and remember minimap tracking |
| `/beacon off` | Stop remembering tracking |
| `/beacon status` | Show current settings |

## Install
Copy the `LootBeacon` folder into `World of Warcraft\_forever_\Interface\AddOns`.
