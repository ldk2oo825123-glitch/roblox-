# Known gaps, differences and unverified items

## How the three versions relate
1. **`brainrots wall game.rbxl` / `game-scripts/`** - the real, playable game (source of truth).
2. **`research/chat-log.txt`** - the conversation that built it. Some things in it were later changed or never saved into this `.rbxl`.
3. **`framework/`** - a tested logic library that mirrors (1). It was first written from the chat log alone, then corrected against the real scripts once they were extracted. Where they disagreed, the real game won.

## Corrections made after extracting the real scripts
- The Daily Wheel was **not** unfinished: it is complete in the game (`WheelServer`, `WheelConfig`, `WheelClient`). The chat log only *looked* cut off.
- Wall tier odds are 22/22/20/15/12/9 (not the guessed 30/28/22/12/6/2). Fling is 60-360 sideways and 50-200 up.
- Variant odds are weights (Normal 80, Gold 10, Diamond 5, Emerald 3, Rainbow 1.5) that are normalized, not forced to sum to 100%.
- Potions: Speed +8, Health +50, Jump +25, Ragdoll/Knockback count as +5 resist levels. The wheel odds are 18/18/16/14/14/14/0.67.
- Shop price growth is 1.6 to 1.8 depending on the item (not 1.6 for all). Jump goes 50 to 100.
- Carried brainrots are limited to **3** (stored inventory is unlimited).
- Saving uses DataStore `BrainrotPlayerData_v1` / key `Player_<UserId>`. `framework/` writes only to `BrainrotPlayerData_v2` and can read v1 to migrate; it never writes v1.

## Open issues in the real game (not fixed - your call)
- **Jump vs. the wall:** at max Jump (100, plus +25 from a potion) a player standing on a pit floor may be able to jump high enough to touch the wall passing over the pit (pit 14 deep, wall 2 studs above ground). A cap near 65-70 would prevent it. `framework/` has this as a suggestion that is switched off.
- **Warning time:** LIGHTSPEED (up to 120 studs/s) crosses the 800-stud zone in about 7 seconds with a 5-second warning. Longer warnings for the fastest tiers would be fairer.
- **The `.rbxl` may be older than the chat log.** Anything described in the chat after the file was saved will not be in `game-scripts/`. Check by playing it.

## What is NOT verified
- Nothing in `framework/` has been run inside Roblox. Its tests run on plain Lua with Roblox faked.
- DataStore saving in `framework/` is tested against a fake in-memory store only.
- The extractor reads only strings, booleans and integers from the `.rbxl`; map geometry (part sizes and positions) was not examined.
- 5-player multiplayer is untested.
