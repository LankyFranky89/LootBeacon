# Shiny Things

A WoW Forever addon that puts icons over lootable things around you and manages minimap tracking.

## Features
- Icons over chests, containers, herbs, ore, fishing pools, quest objects and corpses (uses the game's soft-target icons)
- Loot-only mode: benches, chairs, mailboxes and NPCs get no icon
- Quest objects are matched against your unfinished quest objectives and quest titles
- Ignore list and allow list you can edit in game
- Remembers your minimap tracking (herbs, ore, treasure, fish) and turns it back on after you die

## Commands
| Command | What it does |
|---|---|
| `/shiny` | Turn object icons on or off |
| `/shiny lootonly` | Turn loot-only mode on or off |
| `/shiny ignore [word]` | Ignore the object in front of you, or anything matching a word |
| `/shiny unignore <word>` | Remove a word from the ignore list |
| `/shiny allow [word]` | Always show the object in front of you, or anything matching a word |
| `/shiny unallow <word>` | Remove a word from the allow list |
| `/shiny herbs` / `ore` / `treasure` / `fish` | Set and remember minimap tracking |
| `/shiny off` | Stop remembering tracking |
| `/shiny status` | Show current settings |

## Install
Copy the `ShinyThings` folder into `World of Warcraft\_forever_\Interface\AddOns`.
