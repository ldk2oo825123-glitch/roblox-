# Framework task tracker

`game-scripts/` is the real playable game's extracted script set and the source
of truth. `framework/` is a separate tested logic library. Do not mix the two
script sets in one place. See [COMPATIBILITY.md](docs/COMPATIBILITY.md).

| Task | Scope | State |
|---|---|---|
| T0 | Foundation and isolated Rojo mapping | Implemented; local mapping checks pass |
| T1 | Daily Wheel | The real Wheel already existed; framework version is a tested mirror, updated by T9 |
| T2 | Inventory, Index, spawn/base adapters | Implemented; local checks pass; adapter limitations below |
| T3 | Profiles and saving | Implemented; T9 real v1 migration and read-only fallback verified with fake stores |
| T4 | Balance | Earlier guessed decisions superseded by T9 real-script values |
| T5 | Additional hardening | Not started |
| T6 | Optional polish | Not started |
| T7 | Wall, home and associated HUD/warning UI | Superseded by game-scripts/; empty framework modules removed |
| T8 | Map and shop runtime/UI | Superseded by game-scripts/; empty framework modules removed |
| T9 | Align tested library with real game | Implemented; all local tests pass; no Studio verification |

## T9 changes and changed expectations

- Config cites real source files. Normal is weight 80, normalized alongside
  10/5/3/1.5 by 99.5; it no longer receives an invented probability remainder.
  Tier/variant base RGB, materials and label RGB follow BrainrotServer/catalog.
- Wall weights are 22/22/20/15/12/9 and warning time is always 5 within the 20s
  wait. Damage is floor(60+t*340), ragdoll is 2+t*7, horizontal fling magnitude
  is 60+t*300 toward the safe zone, and vertical fling is 50+t*150. Hit cooldown
  is 2.5s. Balance.wallSpeed samples the inclusive one-decimal tier grid from a
  uniform supplied roll. Wall speed/tier helpers are pure library functions.
- Both resists use max(.1,1-.08*(level+(activePotion and 5 or 0))). Convenience
  reduction attributes are one minus this multiplier. Tests check every level
  0..10 with and without potions. The previous reduction policy was removed.
- Exact ShopConfig.Items rows and WheelConfig.Rewards rows are retained. Shop
  helpers use per-row growth 1.6/1.7/1.7/1.8/1.8/1.8 and the real base prices,
  levels and effects; tests compare all purchase levels 0..10 to real ShopConfig.
  Jump is 50+5*level, reaching 100, or 125 with a potion. The suggested 65–70
  jump cap is inactive. Cash display percents and resist display percents are
  translated into income bonus and resist levels in framework Upgrades.
- Wheel weights are 18/18/16/14/14/14/.67, scaled by 100 for exact integer RNG.
  Tests enumerate all 9467 unowned rolls and all 9400 owned rolls. Owned 67 is
  excluded from the pool. Potion effects are +8 speed, x2 money, +50 health,
  +5 ragdoll/knockback levels and +25 jump. Grants extend max(now,expiry)+900
  without a cap; cooldown remains 86400. Dynamic 67 value has the real minimum
  of 1 and considers supplied ordinary pedestal values only.
- Carry is limited to 3 with a `carry full` reason and unchanged state on refusal.
  Safe inventory remains unlimited. The 10,000-item test now uses authorized
  carry/deposit batches, not an impossible bulk carried fixture. All 25 Index
  combinations remain tested, depositing between pickups. Spawn counts are
  10/8/6/4/2; respawn is 8s, income interval 5s and pedestal count 6.
- Base payout tests now expect the floored multiplied sum, as real BaseServer
  does, while individual fractional item values remain intact. Health tests now
  expect ShopServer's added max-health difference and full health on respawn.
  Unrelated cash, invalid-input, lifecycle, lock, sparse-slot and cleanup checks
  remain in place. Snapshot copies retain appearance scalars.
- Saving writes BrainrotPlayerData_v2 only, with Player_<UserId> keys. Main passes
  BrainrotPlayerData_v1 separately for GetAsync-only first-load fallback. Failed
  reads create no default save; concurrent v2 data wins over the v1 read. Existing
  retries, failed-load refusal, future-schema refusal, autosave, session claims,
  departure ordering and shutdown-budget checks remain tested.
- ProfileLogic migrates the real flat v1 fields, parses variant name prefixes,
  expands stacks into fresh IDs, preserves RGB/material, converts discoveries
  and cooldown timestamps, and drops expired boosts. Six stored items become
  pedestals; overflow is kept in inventory. 67 entries become ownership only.
  Unknown discovered names are retained for diagnostic reverse export.
  toLegacyV1 exports real-shaped records without writing them to any store.
- The new synthetic fixture has three Gold Sigma Frogs, two Diamond Turbo
  Toasts, eight stored items, 67 ownership and active/expired boosts. It verifies
  all 13 ordinary items, fresh unique IDs, all six levels, cash, discoveries,
  nextSpin, active expiry times and appearance survive migration, v2 codec,
  inventory copy and reverse export. Expired boosts are intentionally removed.
- Removed seven empty framework server/client placeholders and their mappings.
  Main's remaining geometry note now refers to an adapter. README and remote
  contracts describe the library accurately; COMPATIBILITY maps all nine real
  remotes, flat save fields, real attributes and deliberate adapter differences.

## Verification (actual final local output)

```text
$ cd framework && for t in tests/*.lua; do lua "$t" || exit; done
PASS: 555 balance checks
PASS: 71 base server mock checks (not Roblox geometry/prompts)
PASS: 44 brainrot spawn checks
PASS: 125 inventory checks (10000 inventory items; all 25 Index entries)
PASS: 49 inventory server mock checks (not Roblox replication)
PASS: 122 real v1 migration checks (13 ordinary items preserved; 8 stored; stacked variants; 67; boost expiry; RGB/material round trip)
PASS: 189 profile/economy/stat checks
PASS: 186 saving fake-store/lifecycle checks
PASS: 195 wheel checks (all 9467 rolls enumerated)
PASS: 51 wheel server mock checks (not Roblox replication)
$ python3 -m json.tool default.project.json >/dev/null
(exit 0; no output)
$ python3 [mapping/hash/obsolete-source assertions]
PASS: JSON valid; all 20 framework source files mapped exactly once
PASS: all 20 extracted Lua scripts retain their before-task SHA-256 hashes; script file set unchanged
PASS: deleted sources unmapped; obsolete policy identifiers absent from framework sources
```

All 10 test files pass, with 1,587 reported checks plus exhaustive wheel loops.
Before-task script hashes were captured in /tmp/t9-game-before.sha256; no git
commands were used. game-scripts/ was never edited. The two non-Lua files there
were not edited; their before-task hashes were not captured. No .rbxl or chat-log
changes, commits, pushes, deployment, external messages or Replit access.

## Still unverified and known adapter limits

- No Roblox Studio execution, playtesting, rendering or real replication.
  Native Luau type checking and Rojo build/sync were not run. Lua tests execute
  pure modules or remove type syntax and use fake Roblox services.
- Actual DataStore API serialization, network failure timing, cross-server lock
  contention, v1-to-v2 migration of live players and BindToClose engine scheduling
  remain unverified. No real player data was accessed and no DataStore was used.
- Binary map geometry, safe-zone coordinate orientation/bounds, spawn/pit
  clearance, real touch timing, carry/drop physics, wall ragdoll/fling lifecycle,
  character health/respawn order and five/six-player engine lifecycle need Studio.
- All framework clients' appearance, input, prompts, bootstrap delivery, Rainbow
  animation and large inventory payloads remain unverified in the engine.
- The framework's isolated world adapters still use placeholder geometry (Z-axis
  corridor versus real X-axis). Its obstructed spawn retry is an existing safe
  adapter rule; real sampling may keep an obstructed final sample. The ownership
  flag for 67 is the requested library abstraction: its adapter credits/displays
  ownership, whereas the real game requires placing 67 in one of six slots.
  These are documented differences, not a claim of playable runtime parity.
  Actual wall/shop/home/map runtime is provided by the real script set only.
