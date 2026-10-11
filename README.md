# Escape Wall for Brainrots

A Roblox game where up to 5 players run out into a long danger zone to grab **brainrots** (collectible meme creatures), hide in **pits** while a giant **wall** sweeps past, then bring them home to earn money and buy upgrades.

This repo has three parts. They are kept apart on purpose so you always know what is real code and what is just notes.

| Folder / file | What it is | Does it run? |
|---|---|---|
| `brainrots wall game.rbxl` | The playable game, built interactively in Roblox Studio. | **Yes.** Open it in Roblox Studio and press Play. |
| [`framework/`](framework/) | A rebuild of the game as plain text code (a "Rojo project") with automated tests. **Partly finished.** | The tested logic runs; the rest needs Studio. See its README. |
| [`research/`](research/) | The game design, the original chat that built it, decisions and tooling notes. | No. It is documentation only. |

## I just want to play it
1. Install **Roblox Studio** (free, Windows or Mac) and sign in.
2. File -> Open -> `brainrots wall game.rbxl`.
3. Press **Play** (F5). For several players: Test -> Clients and Servers.

## I want to work on the code
Read [`framework/README.md`](framework/README.md). You can run all the tests with just Lua, no Roblox needed.

## I want to understand the design
Read [`research/GAME_SPEC.md`](research/GAME_SPEC.md) first, then [`research/known-gaps.md`](research/known-gaps.md).

## Honest status
- The `.rbxl` is the version that worked in Studio.
- `framework/` has about 1,130 passing automated checks, but those run on plain Lua with Roblox faked. **Nothing in `framework/` has been run inside Roblox yet.**
- Still empty in `framework/`: the wall, shop, map builder, home teleport, HUD and warning banner.
