# Compatibility with the extracted real game

Do not mix the two script sets in one place.

`game-scripts/` is the authority, extracted from `brainrots wall game.rbxl`.
`framework/` remains a tested logic library with isolated Roblox adapters. Its
Rojo project is not a replacement for the playable game. The remote names below
remain unchanged; matching names do not imply matching payloads or paths.

## Remotes

Real remotes are directly under ReplicatedStorage; framework remotes are in
ReplicatedStorage.GameRemotes. Source: real InventoryServer, ShopServer,
WheelServer, HomeServer, and the corresponding clients.

| Real remote | Framework equivalent | Contract difference |
|---|---|---|
| BuyUpgrade | none | Profile setters and Balance prices are helpers, with no purchase remote |
| DropBrainrot | none | Real event drops one carried item; framework has death/ragdoll carry-drop helpers only |
| DropFromInventory | DropItem | Real event selects a name/stack; framework function selects one unique item ID |
| IndexUpdate | InventoryUpdate | Framework combines Index keys and inventory in one snapshot |
| InventoryUpdate | InventoryUpdate | Real sends name/value/color/count rows; framework sends tier/variant groups with unique IDs, carried list and Index |
| Notify | none | Framework mutation functions return rejection reasons to their callers |
| PlaceBrainrot | PlaceItem | Real selects name/base index/slot; framework selects ID/slot and validates its assigned base |
| SpinWheel | SpinWheel | Real returns `(success, rewardIndexOrMessage)`; framework returns a structured state/reward response |
| TeleportHome | none | Real HomeServer owns teleporting |

Framework-only remotes: PickUpItem (real pedestal ProximityPrompt invokes a server
handler), GetInventoryState, GetWheelState and WheelUpdate (real wheel UI uses
player attributes). See [REMOTES.md](REMOTES.md) for full framework contracts.

## Saves

Source: real SaveServer.server.lua, BrainrotInventory.serializeStored and
BaseServer.snapshot. The real store is `BrainrotPlayerData_v1`, key
`Player_<UserId>`, with a flat table and no schema-version field.

Framework writes **only** `BrainrotPlayerData_v2`, with the same key prefix.
Main passes a separate v1 store exposing only GetAsync usage. Saving first reads
v2; only absent v2 triggers a read of v1. Reads happen before the non-yielding v2
UpdateAsync transform; a concurrent v2 value takes precedence. Failed reads
refuse initialization and writing defaults. Session locks are v2-only.
`ProfileLogic.toLegacyV1` is a diagnostic/export helper, never a v1 write path.

| Real v1 field | Framework v2 field / conversion |
|---|---|
| cash | cash |
| speed | upgrades.Speed |
| cashBoost | upgrades.Cash |
| health | upgrades.Health |
| knockback | upgrades["Knockback Resist"] |
| jump | upgrades.Jump |
| ragdollRes | upgrades["Ragdoll Resist"] |
| inventory: `{name,value,r,g,b,mat,count}[]` | inventory: unique `{id,tier,variant,value,r,g,b,mat}` records; expand count, generate fresh IDs |
| stored: `{name,value,r,g,b,mat}[]` | pedestals numeric slots 1..6; overflow preserved in inventory; string slot keys on disk |
| discovered: names | indexFound["Tier\|Variant"]; unknown and 67 names retained in legacyDiscovered for export |
| nextSpin | wheel.lastSpinAt = nextSpin - 86400; zero means never spun |
| has67 | wheel.owns67; any `67 Brainrot` record also sets ownership and creates no ordinary item |
| boostSpeed | wheel.potions.SpeedBoost |
| boostMoney | wheel.potions.DoubleMoney |
| boostHealth | wheel.potions.HealthBoost |
| boostRagdoll | wheel.potions.RagdollResist |
| boostJump | wheel.potions.JumpBoost |
| boostKnockback | wheel.potions.KnockbackResist |
| none | version=2, savedAt, _session (token/jobId/at) |

Boost values are absolute Unix expiries; migration retains only expiries > now.
Name prefixes Gold/Diamond/Emerald/Rainbow become variants; no prefix becomes
Normal. Known values come from the catalog; unknown named tiers keep finite
legacy values. Invalid fields default safely. RGB/material scalars survive the
codec, inventory copy, v2 saving, and reverse export. Reverse export stacks
identical records, converts keys to names, and emits one protected 67 inventory
record for ownership. It preserves ordinary item counts, values and appearance;
it cannot reconstruct original IDs, stack order or pre-overflow placement.
Expired boosts are deliberately discarded, not revived.

## Attributes and profile state

| Real attribute / value | Framework source or equivalent |
|---|---|
| leaderstats.Cash | profile.cash; player Cash attribute |
| SpeedLevel, CashLevel, HealthLevel, JumpLevel | profile.upgrades.Speed/Cash/Health/Jump |
| KnockbackLevel, RagdollLevel | profile.upgrades["Knockback Resist"/"Ragdoll Resist"] |
| BoostSpeed/Money/Health/Ragdoll/Jump/Knockback | wheel.potions fields above; expiry is absolute os.time |
| NextSpin | WheelLogic.nextSpinAt(profile.wheel) |
| Has67 | profile.wheel.owns67; OwnsBrainrot67 attribute |
| DataLoaded | readiness after successful Saving initialization; no identically named attribute |
| BaseIndex | Bases.getBase(player) / assigned adapter base |
| base model OwnerUserId | adapter owner and OwnerUserId on pedestal prompts |
| CarryValue, CarryName | inventory.carried and InventoryUpdate snapshot |
| character Ragdolled | same character attribute checked by inventory adapter; real wall owns the lifecycle |
| workspace WallSpeed, WallTier, WallColor, WallCountdown | Balance helpers / Config only; no framework wall runtime |
| humanoid WalkSpeed, JumpPower, MaxHealth | Profile/Wheel effective stats using the real formulas |
| none | IncomeMult, RagdollReduction, KnockbackReduction convenience attributes; each reduction = 1 - real resist multiplier |

ShopConfig's exact Items rows are retained in Config.Shop.Items. Framework
Upgrades translates Cash's percent display (100 + 25*level) into an additive
income bonus (0 + .25*level), and resist percent display into levels. Prices use
each row's own growth. Wheel weights are scaled by 100 into exact integer RNG
weights; owned 67 removes 67 weight units, leaving 9400. Potion grants extend
`max(now,currentExpiry)+900` with no cap. Resist multipliers are
`max(.1,1-.08*(level+(activePotion and 5 or 0)))`. Jump is uncapped; the suggested
65–70 cap is explicitly inactive. Damage and final base payouts are floored.

The real 67 is an inventory record placed on a pedestal and counts toward the
six slots; its dynamic value is max(1, highest non-dynamic placed value). The
requested framework ownership-only representation preserves this value helper
but its existing adapter displays/credits ownership without a placement item.
This is a documented library abstraction, not playable placement parity.
Similarly, framework world coordinates, safe-zone bounds and pit sampling are
isolated adapter assumptions, not verified copies of binary map geometry. Real
spawns run along X; the framework mock corridor runs along Z. The framework
retries fully blocked spawn bands; the real script samples 30 times and may
retain its final obstructed sample. These adapter differences require an explicit
integration decision before any standalone Studio use.
