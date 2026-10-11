# framework/ — the game as plain-text code

This is the functional code. It is a **Rojo project**: ordinary `.lua` files that Rojo turns into a Roblox place. It exists because the `.rbxl` file is binary and can't be edited, diffed or reviewed as text.

## What works (and is tested)
| Feature | Files | Tests |
|---|---|---|
| All numbers in one place | `src/ReplicatedStorage/Config.lua` | used by all |
| Balance maths (wall damage, ragdoll time, fling, shop prices, price formatting, wall tier odds) | `Balance.lua` | `tests/test_balance.lua` |
| Brainrot values and variants (Gold +10%, Diamond +20%, Emerald +30%, Rainbow +40%) | `BrainrotData.lua` | in balance tests |
| **Daily Wheel** (6 timed potions + the rare permanent "67 Brainrot") | `WheelLogic.lua`, `Wheel.lua`, `WheelUI.client.lua` | `test_wheel*.lua` |
| **Inventory**: carry in the danger zone (at risk), safe inventory (unlimited), drop, place on base | `InventoryLogic.lua`, `Inventory.lua`, `InventoryUI.client.lua` | `test_inventory*.lua` |
| Brainrot spawning, 5 bases, passive income, Index (25 entries) | `Brainrots.lua`, `Bases.lua`, `WorldItems.lua`, `IndexUI.client.lua` | `test_brainrots.lua`, `test_bases_server.lua` |
| **Saving**: versioned profile, old-save migration, session lock, autosave | `ProfileLogic.lua`, `Profile.lua`, `Saving.lua` | `test_profile.lua`, `test_saving.lua` |

Also in `src/ReplicatedStorage/`: `BrainrotLogic.lua` (spawn rules) and `InventoryClient.lua` (client helper for the inventory menu).

## What is still empty (placeholders)
`Wall.lua`, `Shop.lua`, `Home.lua`, `MapBuilder.lua`, `HUD.client.lua`, `ShopUI.client.lua`, `Warning.client.lua`. Each has a one-line comment saying what will go there. See `STATUS.md` (tasks T5, T7, T8).

## Run the tests (no Roblox needed)
You only need Lua 5.x installed.
```sh
cd framework
for t in tests/*.lua; do lua "$t"; done
```
Every line should start with `PASS`.

## Run it in Roblox (needs Windows or Mac)
1. Install [Rojo](https://rojo.space) and its Studio plugin.
2. In this folder run `rojo build -o game.rbxl`, or `rojo serve` and connect from Studio.
3. Press Play. Turn on *Game Settings -> Security -> Enable Studio Access to API Services* to test saving.
Because the wall, shop and map are still placeholders, the built place will not be a complete game yet.

## How the code is organised
- `src/ReplicatedStorage/` — shared code and settings (both server and player).
- `src/ServerScriptService/` — the server decides everything that matters (money, items, hits). Players can't cheat by editing their own client.
- `src/StarterPlayerScripts/` — what each player sees (menus, inventory, wheel).
- `docs/REMOTES.md` — every message players can send to the server, and how each is checked.
- `STATUS.md` — task list, what was verified, and what was not.

## Rules the code follows
- No numbers hidden in code: change `Config.lua` to rebalance.
- Logic that doesn't touch Roblox is kept separate so it can be tested.
- The server validates everything a player sends.

## Not verified
No Roblox Studio, Rojo or Luau type checker was available when this was written. See `STATUS.md` for the exact list.
