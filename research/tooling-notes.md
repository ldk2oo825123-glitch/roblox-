# Tooling notes: working on this game without Roblox Studio

These are observations, not code. Checked October 2026. Where I could not confirm something, it says so.

## The core problem
- Roblox Studio only officially runs on **Windows and Mac**.
- The `.rbxl` place file is a **binary** file (zstd-compressed chunks). It cannot be edited as text, so AI coding tools and git diffs can't work with it directly.
- Solution used here: keep the game's source as plain text files in `framework/src/` (a "Rojo project"), and build a `.rbxl` from them.

## Tools and how safe they are long-term
| Need | Tool | Notes |
|---|---|---|
| Text files <-> Studio | **Rojo** (7.x) | Open source, plain-JSON project file, so you can leave it any time. `rojo syncback` can turn an existing `.rbxl` into text files. |
| Installing tools at pinned versions | **Rokit** | Active under the rojo-rbx org (last push seen: Nov 2025; no 2026 activity confirmed). **Aftman is archived** (July 2025), avoid it. |
| Running logic tests outside Roblox | plain **Lua** (used here), or **Lune** | Pure logic modules have no Roblox calls, so they run anywhere. |
| Type checking / linting | luau-lsp, Selene, StyLua | Not set up yet. |
| Headless in-engine checks | **Open Cloud Luau Execution** | Official. Needs an API key and a published place. Tasks are capped at 5 minutes. Docs disagree on Beta vs stable. |
| Studio on Linux | **Vinegar** (Wine) | Unofficial. Can break after Roblox updates. Treat as a convenience. |
| Playing on Linux | **Sober** | Closed source, experimental, player only (no Studio). |

## Durable strategy
1. Source of truth = text files in git.
2. Keep game logic in modules that do **not** call Roblox APIs, and unit-test them.
3. Treat every Roblox-specific tool as replaceable.
4. Final playtesting happens on a Windows/Mac machine with Studio.

## Reading a binary .rbxl without Studio
The `.rbxl` format is a header plus compressed chunks (zstd in current files). `tools/rbxl_dump.py` reads the chunks and pulls out every script's source - this is how `game-scripts/` was made. Rojo's `rojo syncback` does the same job properly if you have Rojo.

## Limits of what was done so far
No Roblox Studio, Rojo, or Luau type checker was available in the environment where this code was written. All tests run on plain Lua with Roblox services mocked. **Nothing here has been run inside the Roblox engine.**
