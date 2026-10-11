# Task Tracker

| Task | Scope | State |
|---|---|---|
| T0 | Foundation | Implemented; local checks passed; Studio verification pending |
| T1 | Daily Wheel | Implemented; local checks passed; Studio and T2/T3/T5 integration pending |
| T2 | Inventory completion | Implemented; Lua/mock checks passed; Studio and MapBuilder/Wall/T3 integration pending |
| T3 | Save-schema audit | Implemented; Lua/fake-store checks passed; Studio/DataStore verification pending |
| T4 | Balance and edge audit | Implemented; Lua/JSON checks passed; Studio verification pending |
| T5 | Hardening | Not started |
| T7 | Wall, Home, HUD, Warning (currently empty placeholders) | Not started |
| T8 | MapBuilder and Shop (currently empty placeholders) | Not started |
| T6 | Optional polish | Not started |

## T0 — Foundation

Created Config, Remotes, BrainrotData, the remaining server/client placeholders,
the Rojo project, and the remote-contract document header. MapBuilder is included
as the server module explicitly required by the closing sentence of section 7.
Main and client placeholders are scripts; other server placeholders are modules.
The remote allowlist is intentionally empty until feature contracts are defined.

Verified locally:

- `python3 -m json.tool default.project.json` succeeds.
- Every source file is mapped exactly once, with no missing or additional paths.
- Numeric code literals occur only in Config; all placeholders have task headers.
- Executed Config unchanged and the helpers with type annotations removed in Lua:
  all tier/variant combinations pass, including the specified Sigma Frog examples.
  Unknown lookups return nil and invalid value requests raise errors.
- Mocked remote setup creates/reuses its folder, rejects unknown remote names,
  and rejects client-side setup.
- Inspected the written files against the exclusions in the spec.
- The protected binary and chat log retain their original SHA-256 hashes.

Unverified: Roblox Studio execution/playtesting, native Luau type checking,
Rojo build/sync, actual Roblox remote replication, and all later feature behavior.
Studio, native Luau, and Rojo are unavailable here. Lua tests remove type
annotations and mock Roblox services; they do not establish engine correctness.

Unresolved spec inputs: numerical wall weights, precise colour RGB values,
fling magnitudes, shop starting prices/price curve, unspecified movement/health
baselines, and geometry dimensions/boundaries. Config preserves the stated
qualitative values and marks missing values nil with TODOs rather than inventing
balance choices. Approximate variant odds are preserved without normalization;
their total leaves a probability remainder for the balance audit. Wheel settings
remain TODO(T1). Placeholder task headers identify the closest later task; the
MapBuilder implementation and shop completion still require explicit assignment.


## T4 — Balance and edge decisions

Resolved all T4 nil/TODO fields in Config using the delegated decisions:
movement/health baselines, five equal rarity bands, exact wall and variant RGB
colours, integer wall weights, horizontal/upward fling endpoints, shop base
prices and exponential price curve. Config comments document the jump step
reduction and potion-inclusive hard cap, longer INSANE/LIGHTSPEED warnings,
intentional upper-LIGHTSPEED lethality at maximum health, client-side Rainbow
label/inventory-dot cycling, and one-decimal base sign income.

Added engine-independent Balance helpers and the explicit Rojo module mapping.
Usage in Roblox: `require(Balance).new(require(Config))`; dependency injection
keeps the helpers free of Roblox APIs. `pickWallTier` takes an integer roll from
1 through 100 and returns its tier record. Scaling helpers clamp out-of-range
speeds to the configured endpoints. The price helper takes the Config upgrade
name and a non-negative integer purchase count. All helper numeric constants
come from Config; test literals are independent expected-value fixtures.

Verified locally with real output:

```text
$ lua tests/test_balance.lua
PASS: 269 balance checks
$ python3 -m json.tool default.project.json >/dev/null
(exit 0; no output)
$ python3 [Config/Rojo assertion check]
PASS: JSON valid; Balance mapped; no T4 nil/TODO fields (T1 wheel nils retained)
```

Tests cover all integer wall rolls against tier weights, damage/ragdoll linearity
and endpoints, fling endpoints/midpoint, all initial shop prices, Speed's second
price, K/M/B formatting, jump level 10, maximum health, variant odds summing to
1.0, warning durations, and invalid helper inputs. Color3 is stubbed only while
loading Config; Balance runs unchanged in plain Lua.

Unverified: Roblox Studio execution/playtesting, native Luau strict type checking,
Rojo build/sync, character geometry and collision clearance under actual gravity,
and runtime application of jump/potion clamps, warnings, fling direction,
Rainbow cycling, and income formatting. The clamp is Config policy for future
runtime consumers; this task does not implement those placeholder systems.
The T0 unresolved-input notes above are historical and superseded by these T4
choices. Wheel nil/TODO(T1) fields remain intentionally untouched: interpreting
"zero nil" literally would require out-of-scope T1 reward decisions. No .rbxl,
chat-log.txt, or unrelated source files were changed. No commits/push/deploy.


## T1 — Daily Wheel

Implemented Config.Wheel policy: 24-hour cooldown, six 900-second potions,
3600-second remaining-time stacking cap, six weights of 1660 and Brainrot67
weight 40 (total 10000). Added pure injected WheelLogic, server Wheel authority,
client panel/animation/countdown/potion strip, three allowlisted/documented
remotes, and Rojo mapping. Main starts the wheel with fresh session profiles;
this small startup change makes T1 runnable without implementing other systems.

Wheel exposes Init/getState/setState/getProfile, owns67-only profile storage,
combined upgrade/potion stats, and a per-tick getIncome hook that recomputes 67
from supplied current ordinary pedestal values. Character spawn reapplies
potions; a single shared Heartbeat expiry scheduler removes expired potions,
reverts modifiers and publishes state. Player departure disconnects character
listeners and removes session state. The client fetches a snapshot to avoid
missing the initial event, and animates only a server-chosen result.

Verified locally with actual output:

```text
$ lua tests/test_balance.lua
PASS: 269 balance checks
$ lua tests/test_wheel.lua
PASS: 187 wheel checks (all 10000 rolls enumerated)
$ lua tests/test_wheel_server.lua
PASS: 51 wheel server mock checks (not Roblox replication)
$ python3 -m json.tool default.project.json >/dev/null
(exit 0; no output)
$ python3 [Config/Rojo assertion check]
PASS: JSON valid; every source mapped once; Wheel policy has no nil fields
```

Pure tests cover exact cooldown/expiry boundaries, every weighted roll,
stacking/remaining-time cap, all potion modifiers, combined reduction/jump caps,
changing/empty/sparse pedestal values, duplicate 67 and saved-state validation.
Server mocks execute Wheel.lua with only Luau type syntax removed: caller/readiness
and argument rejection, server RNG bounds, cooldown consumption, duplicate 67
without refund, live profile mutation, detached snapshots, expiry cleanup,
per-tick income, replacement state, respawn-listener cleanup and one scheduler
across repeated Start/Init. These mocks do not establish Roblox engine behavior.

Unverified/pending: Studio execution/playtesting, native Luau strict type checking,
Rojo build/sync, actual engine replication, UI appearance/animation and actual
character respawn/health/physics. Studio, Luau and Rojo are unavailable here.
Bases, Shop, Wall and Saving are still pre-existing placeholders. Actual income
ticks must call getIncome, Shop purchases must call Refresh and Wall must consume
reduction attributes. T3 must replace Main's fresh Init with successful profile
load and save profile.wheel before cleanup. Consequently cross-session saving
and the physical 67/income presentation are pending integration, not verified
acceptance. 67 currently exists only as a protected ownership flag, with no
inventory/Index/variant/drop/death-loss path or cached saved value. Absolute
expiry timestamps deduct offline elapsed time on restore.

No .rbxl or chat-log.txt edits; no commits, pushes, deployment or Replit access.


## T2 — Inventory v2, pickups, bases and Index

Implemented injected pure InventoryLogic and BrainrotLogic; authoritative
Inventory, Brainrots and Bases adapters; shared world labels; Inventory/Index
clients and their shared snapshot bootstrap. Registered/documented all five T2
remotes and mapped every new module in Rojo. Main initializes these systems with
fresh session state; no persistence is claimed. Config now owns interaction,
spawn, ground-drop and UI constants, plus clearly marked TODO(T4-geometry)
safe-zone/base/danger coordinates that MapBuilder/Studio must match. Wall only
received the requested onRagdoll integration TODO. No binary/chat-log edits,
commits, pushes, deployment, messages or Replit connection were performed.

Inventory state has unique item IDs, unlimited safe inventory, carried drops on
death/ragdoll, exact-ID drop, pedestal round trips, variant groups and persistent
Index keys. Safe-zone conversion is server-only and position-checked. Ground
drops preserve items, expire after 40s and have a 2s owner-only pickup lock.
Brainrots use tier bands, server variant rolls, 8s same-tier respawns and pit-rect
exclusion. Bases assigns five plots, rejects a sixth player, uses owner-only
client prompts plus independent server access checks, clears departing plots,
and computes rounded income through Wheel.getIncome. SetCashHandler is the
explicit future Shop/Saving cash-credit hook; without a handler it credits no
cash. Show67 overlays an empty pedestal label (or shares slot one's label when
full), recomputing WheelLogic.brainrot67Value without creating an Item, consuming
an ordinary slot, or unlocking Index entries.

Verified locally with actual final outputs:

```text
$ for test in tests/*.lua; do lua "$test" || exit; done
PASS: 269 balance checks
PASS: 71 base server mock checks (not Roblox geometry/prompts)
PASS: 43 brainrot spawn checks
PASS: 119 inventory checks (10000 inventory items; all 25 Index entries)
PASS: 49 inventory server mock checks (not Roblox replication)
PASS: 187 wheel checks (all 10000 rolls enumerated)
PASS: 51 wheel server mock checks (not Roblox replication)
$ python3 -m json.tool default.project.json >/dev/null
(exit 0; no output)
$ python3 [source/Rojo mapping assertions]
PASS: JSON valid; every source mapped exactly once
```

Acceptance coverage:

- Pure and actual Inventory adapter mocks: carried-only Index stays locked;
  safe-zone position outside refuses conversion and inside converts; death and
  ragdoll empty carried while preserving inventory; 10,000-item transfer retains
  all items with no capacity limit. Touch pickup is always to carried first.
- Pure and Inventory adapter mocks: pedestal round trip preserves all four item
  fields; invalid/occupied/empty slots and missing inventory IDs fail; non-owner,
  no-base, out-of-range requests fail. Inventory drop removes one exact ID while
  another identical tier/variant survives. Malformed arguments and cooldown fail.
- Pure: first inventory entry and pedestal pickup mark Index, carried-only death
  does not mark it, all 25 combinations unlock exactly 25 entries; variants have
  separate groups; multiplier income rounds to one decimal; best value changes
  after removal. Saved-state validation rejects duplicates/invalid items/slots;
  copied state and snapshots do not alias the caller's tables.
- Inventory adapter mocks: death hookup, removal cleanup, ground expiry, owner
  pickup lock, immediate other-player pickup, repeated-touch consumption guard,
  event-position drop, no-character touches, snapshot bootstrap and readiness.
- Pure spawn tests: all five rarity bands, variant odds boundaries, pit edges,
  retry after obstructed samples, fully obstructed bands skip rather than spawn
  over pits. Actual Brainrots scheduling and touch adapter remain unverified.
- Actual Bases adapter mocks: five assignments, sixth rejection, six configured
  prompts, owner attributes, freed plot reuse, label cleanup, income interval
  callback, rounded multiplier income and live/removed/duplicate-call 67 label
  updates. Prior balance/wheel tests all still pass.

Unverified / integration still required:

- **No Studio/engine/replication testing; UI never rendered.** Native Luau strict
  type checking and Rojo build/sync are unavailable here. Lua service mocks do
  not prove engine behavior or replication and do not type-check Luau.
- Actual safe-zone entry/touch timing, ragdoll/death physics and event positions,
  world-part pickup/expiry, spawn respawn scheduling, pit relocation, character
  spawning/teleport and five/six real-player lifecycle behavior require Studio.
- MapBuilder is intentionally untouched and remains a placeholder. It must
  supply real pit rectangles to Brainrots.SetPitRects before Start and match the
  Config TODO geometry. Main currently supplies no pit rectangles/floor map.
- Wall remains a placeholder; actual wall ragdoll integration must call
  Inventory.onRagdoll before fling and own the Ragdolled attribute lifecycle.
- Shop/Saving must install Bases.SetCashHandler for actual cash credits. Saving
  must load/migrate profiles, initialize Wheel then Inventory, encode/decode
  sparse pedestal keys and save snapshots before session cleanup. Persistence,
  rejoin recovery and actual DataStore failure behavior belong to T3.
- Inventory/Index appearance, grouped item selection, G and DROP, E picker/pickup,
  owner-only prompt visibility, refusal popups, rainbow cycling, Index I/button,
  filtering counts, closed-panel progress visibility and the large full snapshot
  payload at 10,000 items have not been tested in an engine/client.


## T3 — Profile and saving

Implemented version-2 ProfileLogic with an injected Config/BrainrotData/ID factory,
detached table serialization, string-keyed disk pedestal slots, strict finite
cash validation, sane defaults for absent/invalid levels, individually discarded
malformed/duplicate items, sanitized wheel/Index state, and future-version refusal.
Legacy v1 migration keeps cash/levels, recomputes known-tier values, defaults
variants to Normal, assigns fresh GUIDs at runtime, and moves overflow past the
six pedestals into inventory. Unknown legacy tiers retain their finite legacy
value; Inventory enables the explicit legacy-tier policy and never counts those
unknown tiers in Index. Ordinary InventoryLogic callers retain strict known-tier
validation. Carried items are excluded from persistence.

Added injected Profile economy/stat authority: non-yielding cash additions and
atomic overspend rejection, validated upgrade setters, Config upgrade formulas,
WheelLogic potion modifiers and clamps, Cash/effective-stat attributes, and
character reapplication without free healing. Bases credits Profile.addCash.
Wheel shares the loaded profile's upgrades and retains its potion expiry scheduler.

Saving uses an injectable UpdateAsync store, configured exponential retries,
per-session token/JobId/timestamp locks renewed on autosave, failed-load kicking
without initializing/saving defaults, and future-version/changed-lock write refusal.
Studio API-disabled errors warn and use ephemeral state; other failures still kick.
Main starts managed Wheel/Inventory handlers and Bases first; successful join
initializes Profile, Wheel, Inventory, then Bases. Saving owns departure ordering:
snapshot/save/release before Bases, Inventory, Wheel, Profile cleanup. Standalone
Wheel/Inventory startup retains its original cleanup behavior for earlier mocks.
Autosave ticks every configured 60 seconds. BindToClose queues player saves in
parallel and waits within the configured 25-second budget; in-flight DataStore
calls cannot be cancelled, and failed saves retain their lock until lease expiry.

Verified locally with real output:

```text
$ for f in tests/test_*.lua; do lua "$f" || exit; done
PASS: 269 balance checks
PASS: 71 base server mock checks (not Roblox geometry/prompts)
PASS: 43 brainrot spawn checks
PASS: 119 inventory checks (10000 inventory items; all 25 Index entries)
PASS: 49 inventory server mock checks (not Roblox replication)
PASS: 188 profile/economy/stat checks
PASS: 153 saving fake-store/lifecycle checks
PASS: 187 wheel checks (all 10000 rolls enumerated)
PASS: 51 wheel server mock checks (not Roblox replication)
$ python3 -m json.tool default.project.json >/dev/null
(exit 0; no output)
$ python3 [mapping/strict/numeric-literal assertions]
PASS: JSON valid; all 27 source files mapped exactly once; new T3 modules strict with no numeric literals
```

New tests execute ProfileLogic, Profile and Saving unchanged in plain Lua.
Coverage includes the cash-120/Speed-3/Cash-2/eight-item legacy fixture, sparse
pedestal round trips, full upgrades/Index/wheel round trips, carried omission,
corrupt/partial data, retired tiers, invalid cash and spend/upgrade inputs,
potion-inclusive formulas and jump cap, failed load/no write, retry success,
UpdateAsync transform reentry, lock conflicts/expiry/replacement, future-version
refusal at load and save, departure during load, missing-state save refusal,
retryable save failure, autosave cadence, five parallel shutdown saves, shutdown
time budget, and Studio API-disabled versus generic-error behavior.

Unverified: Studio playtesting, actual DataStore API access/serialization/network
retries and cross-server lock contention, actual BindToClose engine scheduling,
Roblox character/potion replication, native Luau strict type checking, and Rojo
build/sync. No Studio, Luau or Rojo executables are available. Existing datastore
name/key compatibility with the binary game's previous scripts cannot be checked
without Studio; Config exposes StoreName/KeyPrefix for review. No remotes were
added; docs/REMOTES.md, the .rbxl, and chat-log.txt were left untouched. No
commits, pushes, deployment, Replit connection, or external messages.
