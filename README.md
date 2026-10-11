# Escape Wall for Brainrots

A Roblox game where up to 5 players run out into a long danger zone to grab **brainrots** (collectible meme creatures), hide in **pits** while a giant **wall** sweeps past, then bring them home to earn money and buy upgrades.

This repo keeps **what runs**, **what is tested**, and **what is just notes** in separate places.

| Folder / file | What it is | Does it run? |
|---|---|---|
| `brainrots wall game.rbxl` | The playable game, built in Roblox Studio. | **Yes.** Open it in Studio and press Play. |
| [`game-scripts/`](game-scripts/) | The 20 scripts that are *inside* the `.rbxl`, pulled out as readable text. This is the real, running game code. | Same code as the `.rbxl` (read-only copy). |
| [`framework/`](framework/) | A separate, automated-test version of the game's rules (math, wheel, inventory, saving). It mirrors the real game and is **not** a replacement for it. | Tests run with plain Lua. Not tried in Roblox. |
| [`research/`](research/) | Game design, the original chat that built the game, decisions and tooling notes. | No. Documentation only. |
| [`tools/`](tools/) | A small script that reads a `.rbxl` file and extracts its scripts. | Python 3.14 (or any Python with `zstandard`). |

## I just want to play it
1. Install **Roblox Studio** (free, Windows or Mac) and sign in.
2. File -> Open -> `brainrots wall game.rbxl`.
3. Press **Play** (F5). For several players: Test -> Clients and Servers.

## I want to read or change the game's code
Read [`game-scripts/README.md`](game-scripts/README.md). To change the real game, edit it in Studio (or extract/rebuild with Rojo), then save the `.rbxl`.

## I want to test the game's rules without Roblox
Read [`framework/README.md`](framework/README.md).

## I want to understand the design
Read [`research/GAME_SPEC.md`](research/GAME_SPEC.md), then [`research/known-gaps.md`](research/known-gaps.md).

## Important: do not mix the two script sets
`game-scripts/` and `framework/` use different remote names and save structures. Putting both in one place would break the game. Details: [`framework/docs/COMPATIBILITY.md`](framework/docs/COMPATIBILITY.md).

## Honest status
- The `.rbxl` is the working game.
- Nothing in `framework/` has been run inside Roblox; its automated checks use plain Lua with Roblox faked.
- The `.rbxl` in this repo is a snapshot; check `research/known-gaps.md` for how it differs from the final design in the chat log.
