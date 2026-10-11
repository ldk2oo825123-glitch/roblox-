# Remote Contracts

| Name | Class / direction | Payload / response | Server validation |
|---|---|---|---|
| `SpinWheel` | RemoteFunction, client → server → requesting client | No arguments. Success: `{ok=true, rewardName, outcome, state, serverNow}`. Cooldown: `{ok=false, reason="cooldown", remainingSeconds, state, serverNow}`. Other rejection: `{ok=false, reason}`. `outcome` is `"granted"` or `"already owned"`. | Roblox-supplied caller must still belong to Players and have an initialized profile; rejects all arguments. Uses `os.time()` for cooldown and server `Random` for weighted reward. Check, cooldown consumption and grant contain no yields. Owned 67 is excluded from the reward pool. |
| `WheelUpdate` | RemoteEvent, server → owning client | Two arguments: `state`, `serverNow` (Unix integer seconds). Published on Init/setState, successful spin and potion expiry. | Only `FireClient` to the owning active Player, detached state copy. No client → server handler. |
| `GetWheelState` | RemoteFunction, client → server → requesting client | No arguments. `{ok=true, state, serverNow}`, otherwise `{ok=false, reason="not ready"}`. Initial snapshot prevents missing the join-time event. | Active initialized caller; rejects arguments. Does not roll, grant or consume a spin. Returns detached state with expired potions removed. |

Wheel state: `{lastSpinAt: integer, potions: {[potionName]: Unix expiry integer},
owns67: boolean}`. `lastSpinAt=0` means never spun. The six potion names and
ordered reward weights are in Config.Wheel. Timers are absolute expiry times:
remaining time after rejoin is `max(0, expiresAt-serverNow)`, including offline
elapsed time. Client clock offsets/countdowns are display-only.

T3 integration: after a successful load, call
`Wheel.Init(player, profile.wheel, profile)`; save `profile.wheel` or
`Wheel.getState(player)` before removing wheel state. `Wheel.setState` validates
and copies replacement state; `Wheel.getProfile` exposes the live server profile
for Saving. Never initialize defaults following a failed load. Main loads through Saving, claims a v2 session, and reads v1 only when v2 is absent. See COMPATIBILITY.md.

Shop integration: store levels under `profile.upgrades[Config upgrade Name]` and
call `Wheel.Refresh(player)` after purchasing. This sets humanoid WalkSpeed,
JumpPower (UseJumpPower=true), MaxHealth and authoritative player attributes
`IncomeMult`, `RagdollReduction`, `KnockbackReduction`, `OwnsBrainrot67`.
MaxHealth increases add the increase to current health; respawns refill. Decreasing MaxHealth clamps
current health. Wall must consume the reduction attributes when applying hits.

Bases integration: each income tick call
`Wheel.getIncome(player, currentOrdinaryPedestalValues, ordinaryIncome)`.
The result includes the current maximum pedestal value when owns67 is true,
then applies upgrade and potion income multipliers. Do not include 67 in the
ordinary values or add its bonus again. Ownership is a flag only: no inventory,
variant, Index or droppable model is created, and no cached value is saved.
Bases and Saving are wired in Main; the real game supplies its own wall and shop. Do not mix the two sets.

## T2 — Inventory contracts

| Name | Class / direction | Payload / response | Server validation |
|---|---|---|---|
| `DropItem` | RemoteFunction, client → server → caller | Exactly `(itemId: string)`. `{ok=true}` or `{ok=false, reason: string}`. | Active initialized Player, living current character, shared 0.15s mutation cooldown, nonempty ID within Config maximum length. Removes only the matching owned inventory ID; carried/pedestal IDs are refused. Position comes from server character. Allowed in either zone. |
| `PlaceItem` | RemoteFunction, client → server → caller | Exactly `(itemId: string, slot: integer)`. Same result shape. | Same caller, character, cooldown and ID checks. Slot 1..Config.Bases.PedestalCount, own assigned base, distance ≤Config.Bases.InteractionRange to that pedestal, current position inside Config.Map.SafeZone. Slot must be empty and exact item ID must be in inventory. Sixth player: `no base available`. |
| `PickUpItem` | RemoteFunction, client → server → caller | Exactly `(slot: integer)`. Same result shape. | Same caller, character, cooldown, slot, ownership, safe-zone and pedestal range checks. Slot must contain an ordinary item. Returns it to inventory and marks its Index key. 67 has no Item and cannot be picked up. |
| `InventoryUpdate` | RemoteEvent, server → owning client | `(snapshot)` containing `carried: Item[]`, `inventory: Group[]`, `indexFound: {["Tier\|Variant"]: true}`, `index: {found, total}`. Group = `{tier, variant, count, items: Item[]}`. Item = `{id, tier, variant, value}`. | FireClient only to the owning active initialized player after state changes. Snapshot and item tables detached from server state. No client → server listener. |
| `GetInventoryState` | RemoteFunction, client → server → caller | No arguments. `{ok=true, state: snapshot}` or `{ok=false, reason}`. | Active initialized Player, no arguments, separate Config.Inventory.RemoteCooldownSeconds snapshot cooldown. Shared InventoryClient module performs one startup fetch for both panels to recover a missed Init update. No mutation. |

All mutation checks and state changes execute without yields. Client prompts and
selected IDs only request actions; the server independently checks ownership,
range and inventory contents. Refusals include `invalid slot`, `occupied slot`,
`item not in inventory`, `empty slot`, `not your base`, `no base available`,
`too far from pedestal`, `outside safe zone`, `invalid arguments`, `not ready`
and `please wait`. There is no client safe-zone conversion or pickup remote.

`Inventory.getState(player)` is the live authoritative T3 state:
`{carried, inventory, indexFound, pedestals}` (pedestals are sparse numeric slots).
Saving must copy it before lifecycle cleanup. `Init(player, saved)` and
`setState(player, state)` validate and detach the supplied tables; they reject
unknown variants/tiers, wrong calculated values, invalid slots, and duplicate
IDs. T3 must migrate legacy profiles and decode sparse slot keys from its own
save representation, load successfully, initialize Wheel then Inventory, and
assign the base. Main initializes successfully loaded state through Saving.
On leave T3 must save before Wheel/Inventory removal and Bases clearing, and
replace the current session lifecycle ordering as necessary. Carried state is
supported by this API; Saving deliberately omits carried items.

`Inventory.onDeath(player)` / `Inventory.onRagdoll(player)` drop only carried
items at the current server root position (last sampled position if unavailable).
Death is wired to Humanoid.Died. Wall must call onRagdoll **before** fling at the
hit position; The framework has no wall runtime. Ground drops retain the same ID and value,
expire after 40s, and reject their owner's touch for 2s; other players can touch
immediately. Living initialized players must be within PickupRange. Touch adds
to **carried first**, even inside the safe zone. A server Heartbeat poll later
converts carried items after checking the player's current safe-zone position
and living/non-ragdolled state (`Ragdolled` attribute contract for Wall).

`Brainrots.SetPitRects(rects)` is the world geometry integration point. Call before
`Brainrots.Start(Inventory)` and whenever pit geometry changes. Rects are a dense
array of world-space `{MinX, MaxX, MinZ, MaxZ}` with finite ordered bounds,
including rims. The setter copies inputs and relocates existing spawns inside
new rectangles. Each tier has Config.Brainrots.SpawnsPerTier[tier] spawn nodes; a
server Random selects coordinates in that tier's distance band and rolls the
variant with Config odds. No valid location after SpawnAttempts means retry
after RespawnSeconds, never spawn over a pit. Taken nodes respawn the same tier
with a new ID and newly rolled variant after 8s. Actual pit exclusion requires an adapter supplying real rects.
Config.Map.SafeZone and base/spawn positions are explicitly marked placeholder
TODO(T4-geometry); world adapter/Studio geometry must match them.

`Bases.SetCashHandler(fn)` installs `fn(player, amount)` for Shop/Saving to credit
its authoritative cash profile once per Config.Bases.IncomeIntervalSeconds.
No handler means no cash credits; the base sign still previews income. Bases
passes ordinary values and unmultiplied ordinary income to Wheel.getIncome,
then floors the final payout once like the real base; wheel applies both upgrades/potions
and 67 exactly once. Base signs use Config.Bases.IncomeDisplayDecimals. Bases
assigns five plots in join order, returns nil for a sixth player, teleports new
characters to their plot spawn and frees plots/clears labels on departure.
Prompts are enabled locally only for their owner, with E opening the inventory
picker for Place or requesting Pick Up; server validation is independent.

`Bases.Show67(player, owns67)` is the minimal permanent-reward display hook.
It calls WheelLogic.brainrot67Value with only ordinary pedestal values and shows
`67 Brainrot $value` on the first empty pedestal label, or alongside the ordinary
item on slot one's label if all six are occupied. This display consumes no
ordinary slot and is refreshed after mutations and every income tick. All six
ordinary slots remain usable. 67 has no ID, variant, inventory record or Index
entry and is never passed to Item operations or ordinary income a second time.

Client controls: Inventory button; grouped tier/variant rows selecting an exact
owned item ID; per-row DROP and G; owner E Place picker / Pick Up; Index button
and I; All/variant filter counts; progress text/bar only under the open Index
panel. Rainbow text cycles on the client in inventory, Index, and world labels.
All client interaction, visuals and replication require Studio verification.
