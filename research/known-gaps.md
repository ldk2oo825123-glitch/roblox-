# Known gaps, decisions and unverified items

## Decisions made (so nobody has to guess)
- **Jump cap:** a Jump upgrade of 100 would let a player jump out of a pit into the wall. Jump now goes 50 -> 65 (step 1.5/level) and total JumpPower (including potions) is hard-capped at 70.
- **Wall warning:** LIGHTSPEED gets 8 s warning, INSANE 7 s, others 5 s.
- **Wall tier odds:** SLOW 30, MEDIUM 28, FAST 22, EXTREME 12, INSANE 6, LIGHTSPEED 2 (out of 100).
- **Variant odds:** Normal 80.5%, Gold 10%, Diamond 5%, Emerald 3%, Rainbow 1.5% (the original "80%" left 0.5% unaccounted for).
- **Daily Wheel:** 24 h cooldown, potions last 15 min and stack up to 60 min; the 67 Brainrot is 0.4% (40 / 10000) and the only permanent reward.
- **Shop prices:** base 25-50 per upgrade, +60% per level.
- All of the above are editable numbers in `framework/src/ReplicatedStorage/Config.lua`.

## What is NOT finished
See the task table in `framework/STATUS.md`. In short: anything marked "placeholder" there is an empty file with a header comment.

## What is NOT verified
- Nothing has run in Roblox Studio or on Roblox servers.
- UI scripts have never been displayed.
- DataStore saving is tested only against a fake in-memory store.
- Multiplayer (5 players) is untested.
- Geometry constants (zone sizes) are placeholders that must be matched to the real map.

## Relationship to the existing `.rbxl`
`brainrots wall game.rbxl` (uploaded by the repo owner) is the playable version built interactively in Studio. Its scripts could not be read from this environment, so the code in `framework/` was written from the design conversation (`chat-log.txt`) and the spec, **not** copied from the `.rbxl`. Expect differences.
