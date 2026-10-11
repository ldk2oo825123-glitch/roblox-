# framework/ — tested game logic library

`game-scripts/` contains the scripts extracted from the real playable game and is the authority for gameplay. `framework/` is a separate tested mirror with pure Lua helpers and Roblox adapters; it does not replace those scripts.

**Do not mix the two script sets in one place.** The Rojo project maps only the framework for isolated review. It is not a complete playable game: real map geometry, wall, shop, home and their UI live in the extracted script set.

Run locally:

```sh
cd framework
for t in tests/*.lua; do lua "$t"; done
```

The tests cover balance, wheel, carried/safe inventory, spawning helpers, bases, profiles, real v1 migration and saving with mock services. Framework saves use `BrainrotPlayerData_v2`; the real `BrainrotPlayerData_v1` store is read-only for first-load migration.

See [STATUS.md](STATUS.md) for verification and limitations, [COMPATIBILITY.md](docs/COMPATIBILITY.md) for save/attribute/remote mappings, and [REMOTES.md](docs/REMOTES.md) for the framework contracts. Studio, native Luau and Rojo checks remain outstanding.

## What is in here (plain English)
| Feature | Files in `src/` | Tests |
|---|---|---|
| All game numbers in one place (copied from the real game) | `ReplicatedStorage/Config.lua` | used by all |
| Wall damage / ragdoll / fling maths, shop prices, wall tier odds, resist formula | `Balance.lua` | `test_balance.lua` |
| Brainrot tiers and Gold/Diamond/Emerald/Rainbow values | `BrainrotData.lua`, `BrainrotLogic.lua` | `test_brainrots.lua` |
| Daily Wheel (potions + permanent 67 Brainrot) | `WheelLogic.lua`, `Wheel.lua`, `WheelUI.client.lua` | `test_wheel*.lua` |
| Carried (max 3, at risk) vs stored (unlimited, safe) inventory, Index | `InventoryLogic.lua`, `Inventory.lua`, `InventoryUI.client.lua`, `IndexUI.client.lua` | `test_inventory*.lua` |
| 5 bases, pedestals, passive income | `Bases.lua`, `WorldItems.lua` | `test_bases_server.lua` |
| Saving and moving old real-game saves forward | `ProfileLogic.lua`, `Profile.lua`, `Saving.lua` | `test_profile.lua`, `test_saving.lua`, `test_migration.lua` |

Folders: `ReplicatedStorage` = shared code, `ServerScriptService` = the server decides everything that matters, `StarterPlayerScripts` = what each player sees.
