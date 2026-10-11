# game-scripts/ - the real game's code

These files were **extracted from `brainrots wall game.rbxl`** with `tools/rbxl_dump.py`. They are the scripts that run when you press Play. They are a read-only copy: editing them here does **not** change the game. Edit in Studio (or use Rojo) and re-save the `.rbxl`.

## Where each script lives in the game
| File | Runs on | What it does |
|---|---|---|
| `ServerScriptService/WallServer` | server | The wall: random speed tier each round, damage, fling and ragdoll that scale with speed, warning attributes. |
| `ServerScriptService/BrainrotServer` | server | Spawns brainrots along the danger zone by rarity band, rolls Gold/Diamond/Emerald/Rainbow variants. |
| `ServerScriptService/BaseServer` | server | The 5 player bases, 6 pedestals each, passive income every 5 s, the permanent 67 Brainrot. |
| `ServerScriptService/InventoryServer` | server | Place / pick up / drop handling. |
| `ServerScriptService/ShopServer` | server | Buying the 6 upgrades and applying them. |
| `ServerScriptService/WheelServer` | server | The Daily Wheel (one spin per 24 h, 15-minute potions, rare 67 Brainrot). |
| `ServerScriptService/SaveServer` | server | DataStore saving: `BrainrotPlayerData_v1`, key `Player_<UserId>`. |
| `ServerScriptService/HomeServer` | server | Teleport home (safe zone only). |
| `ServerScriptService/RainbowServer` | server | Cycles the colour of Rainbow brainrots. |
| `ServerStorage/BrainrotInventory` | server module | Carried (at risk, max 3) vs stored (safe, unlimited) brainrots. |
| `ReplicatedStorage/BrainrotCatalog`, `ShopConfig`, `WheelConfig` | shared | The tier, variant, shop and wheel numbers. |
| `StarterGui/*Client` | player's screen | Cash HUD, shop, inventory, index, wheel, home button and wall warning menus. |

`instance-tree.txt` lists every object in the place (class and path), so you can see the map pieces (bases, pits, boundary, shop model) as well as the scripts.

## Not included
The six default `print("Hello world!")` scripts that Studio puts in new places were left out. Map geometry (parts) is not code, so it only appears in `instance-tree.txt`.

## Where the numbers are
Change a number in `ReplicatedStorage/*Config` or at the top of the relevant server script. The test-version of these numbers is in `framework/src/ReplicatedStorage/Config.lua` and should be kept in sync (see `framework/docs/COMPATIBILITY.md`).
