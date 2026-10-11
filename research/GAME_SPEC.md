> **Note (read first):** this spec was written from the chat log *before* the real scripts were extracted. Where its numbers differ from `game-scripts/`, the real game wins. See `known-gaps.md` for the list of corrections and `framework/docs/COMPATIBILITY.md` for the mapping. Sections 5 (tasks T7/T8) are superseded: the wall, shop, map and HUD already exist in `game-scripts/`.

# Escape Wall for Brainrots — Refined Build Spec & Orchestration Frame

Single source of truth for finishing the game. Distilled from `chat-log.txt` (the full prompt history) and the shared repo file `brainrots wall game.rbxl` (`ldk2oo825123-glitch/roblox-`). Where this file and the chat log disagree, **this file wins** (the log contains superseded designs).

---

## 0. How to use this file

1. Every agent reads this file first, then only the files its task touches.
2. Work happens in `src/` (Rojo-style tree, see §7). Never binary-edit the `.rbxl`.
3. The manager (Claude) assigns one task from §5 at a time, reviews the diff against the acceptance criteria, and sends corrections as a new brief. Done = acceptance criteria met, not "code written".

## 1. Orchestration protocol

**Manager (Claude)** — perfectionist reviewer, minimum model/effort that can judge the work:
- Plans, writes briefs, reviews diffs. Does not write feature code unless a delegate fails twice.
- Review checklist per task: matches §3 numbers exactly; server-authoritative (no client trust); no duplicated constants (one `Config` module); no dead code from §4; every acceptance bullet verified by reading code or a test, not assumed; reports honestly what is unverified (cannot run Studio here).
- Use `low`/`medium` effort for briefs and routine reviews; `high` only for architecture decisions or a task that failed review twice.

**Worker 1 — Codex (default).** Launch per task via:
```
<local Codex launcher> --project <path to this repo> --task-file <brief.md> [--effort low|medium|high]
```
Brief = task text from §5 + "read GAME_SPEC.md §3, §6, §7" + acceptance criteria. Run in background, one task at a time (no overlapping files).

**Worker 2 — Claude subagents (automatic fallback).** Switch when the launcher output shows quota/usage/rate-limit/token exhaustion, or it fails the same way twice. Then:
- Implementation: `general-purpose` subagent on Sonnet; trivial/mechanical edits on Haiku.
- Review of risky systems (data saving, economy): a second subagent or the manager, fresh context.
- Same briefs, same acceptance criteria. Record the switch in `STATUS.md`. Probe Codex again at the start of each later session; return to it when quota is back.

Never claim Codex finished work if the launcher failed. No commits/pushes without the user's say-so.

## 2. Core concept (keep)

Round-based 5-player co-op survival-collection game. Players leave a **safe zone**, run through a long **danger zone** collecting **brainrots** (more valuable farther out), and hide in **pits** while a **wall** sweeps the zone at a random speed. Brainrots are brought home, placed on a personal **base**, and earn passive income, which is spent on **shop upgrades**. Progress is saved.

## 3. Final design (authoritative numbers)

**Map** — "T" layout: wide safe zone + 800-stud danger corridor. Green studded grass floors, brown-orange walls 46 studs tall with green top trim, tan stripes at rarity boundaries (4), invisible end barrier. Blue-white checker base plots with a player-colour border. Floating-void sky is optional/low priority.

**Bases** — 5 plots along the back wall of the safe zone; first 5 joiners get one, respawn there; sign shows owner/FREE and income per 5 s; 6 pedestals each; freed on leave. Only the owner can use their base.

**Pits** — 14 random fixed pits, 24 wide × 28 long, 14 deep, ramp on the west side, ≥30 studs apart, yellow rim markers, no brainrot spawns over them, walls continue down into them.

**Brainrots** — 5 tiers by distance (values per 5 s): Noodle Goblin $1, Sigma Frog $3, Turbo Toast $8, Cosmic Banana $20, Golden Gigarot $60. Touch to pick up. Respawn same tier after 8 s. Variants (any tier): Normal ~80% (+0), Gold 10% (+10%), Diamond 5% (+20%), Emerald 3% (+30%), Rainbow 1.5% (+40%, colour-cycling). Value = base × (1+bonus), one decimal. Name label coloured by variant.

**Carry vs Inventory (v2, current intent)** — Two states. *Carried*: picked up in the danger zone, shown on the player, **at risk**: dropped on death **and on ragdoll**. *Inventory*: unlimited, **safe on death**; carried items convert to inventory automatically on entering the safe zone. Player can drop unwanted items (G key / small DROP button; ground item expires 40 s; 2 s owner re-pickup lock). Base pedestals: owner presses E to Place from inventory / Pick Up back to inventory.

**Wall** — Random speed per round, chosen at start of the 20 s wait, with a 5 s warning banner ("<TIER> WALL INCOMING", countdown, "Hide in a pit!"). Floats 2 studs above ground (pits are safe). Angry-face texture on the side facing bases.

| Tier | Speed (studs/s) | Colour | Odds |
|---|---|---|---|
| SLOW | 14–22 | green | common |
| MEDIUM | 22–32 | yellow | common |
| FAST | 32–45 | orange | fairly common |
| EXTREME | 45–60 | red | uncommon |
| INSANE | 60–85 | dark red | rare |
| LIGHTSPEED | 85–120 | purple | rarest |

Hit = damage + fling toward safe zone + ragdoll, all scaling smoothly with speed: damage 60→400, ragdoll 2→9 s, fling small→huge. One hit per pass (2.5 s debounce). Knockback/Ragdoll Resist reduce fling/ragdoll.

**Shop** — Physical red/white striped stall on a stone platform with floating "SHOP" sign (scales with distance, hides >140 studs). Step on the red pad to open, step off to close. Panel is semi-transparent with borders, ~35% larger than the compact version, header "Shop" + red X. Rows (10 levels each): Speed +2 walk, Jump +5 power (50→100), Health +25 max HP, Cash +25% income, Knockback Resist −8%/lvl (max 80%), Ragdoll Resist −8%/lvl (max 80%). Prices escalate, shown with K/M/B suffixes. Green/red/grey buy states. List scrolls.

**HUD** — Cash panel top-centre (reduced size), floating +$/−$ popups, "Carrying" line, Inventory button, Index button (I), Home button (H).

**Teleport Home** — H / button; works only inside the safe zone (server-validated position); blocked while ragdolled; 2 s cooldown; goes to own base spawn.

**Index** — 25 entries (5 brainrots × 5 variants), "???" until first reaching inventory; left filter sidebar (All/Normal/Gold/Diamond/Emerald/Rainbow with counts); progress bar "Collected N / 25" only visible inside the open Index.

**Daily Wheel** — see §5 T1.

**Saving** — DataStore: cash, all upgrade levels, base pedestal contents (with variant), inventory (v2), index progress, wheel state. Save on leave, every 60 s, and BindToClose. Failed load ⇒ kick with "rejoin" (never overwrite with blank).

## 4. Discard (do not rebuild, do not reference)

Obby template; yellow shop button/UI; gold-roof shop; hold-E grab prompt; one-brainrot-carry limit and 3-slot hotbar cap; instant cash-in at safe zone and store-on-touch base plot; the 4-tier wall table and yellow→red-only wall colours; full-width trenches and 36 small pits; glass side barriers; always-visible Index mini-bar; the dead `Escape Tsunami` wording (it is a *wall*).

## 5. Tasks (unfinished / unverified work)

**T0 — Foundation.** Create `src/` tree (§7), one `Config` ModuleScript holding every number in §3, a `Remotes` setup, and a `STATUS.md` task tracker. Acceptance: no magic numbers outside Config; tree maps 1:1 to a Rojo `default.project.json`.

**T1 — Daily Wheel (was cut off mid-build; treat as not started).** Spin once per 24 h (server clock, persisted). Server picks the reward; client only animates. Rewards (weighted, sum to 100%):
- Timed potions, 15 min each: Speed Boost, Double Money, Health Boost, Ragdoll Resist, Jump Boost, Knockback Resist (6 × ~15.8%).
- **67 Brainrot**: extremely rare (~0.1–0.5% — pick and put in Config), **the only permanent reward**. Its value is always equal to the highest-value brainrot currently placed on that player's base (recomputed each income tick; 0 if base empty). Not tradeable/droppable, exempt from variants and death loss, saved, never counted in Index.
Active potions stack by extending the timer of the same type (cap in Config), show a HUD timer strip, and persist across rejoin by remaining time. Acceptance: re-spin blocked before cooldown with a countdown; potion effects apply and revert exactly at expiry; 67's value updates when the best pedestal brainrot is removed/added; all state saved.

**T2 — Inventory v2 completion.** Verify/finish: carried→inventory on safe-zone entry, carried drop on death and ragdoll, inventory survives death, drop button/G, pedestal Place picker / Pick Up, Index unlock on first inventory entry, save/restore of inventory. Acceptance: each bullet traceable to code; no path loses an inventory item.

**T3 — Save-schema audit.** One versioned profile table covering every persisted field in §3 with migration from the old schema (cash, speed, cash lvl, pedestals). Acceptance: join with old-format data loads without loss; new keys default sanely.

**T4 — Balance & edge audit.** Resolve known conflicts: max Jump vs. wall clearance over pits (cap jump or lift wall clearance — choose and document); LIGHTSPEED vs. 800-stud corridor and 5 s warning fairness; Health cap vs. wall damage tiers; Rainbow dot colour in inventory list; base sign income rounding. Acceptance: each conflict has a documented decision in Config comments.

**T5 — Hardening.** All client→server remotes validated (ownership, range, cooldown, type); no client-authoritative cash/inventory/teleport; cleanup on PlayerRemoving; 5-player/6th-player behaviour. Acceptance: remote-by-remote table in `docs/REMOTES.md`.

**T7 — Wall, Home, HUD & Warning (added after review).** The placeholders for Wall, Home, HUD, Warning stayed empty after T0; implement them from §3 so the repo no longer depends on scripts hidden in the binary `.rbxl`. Acceptance: round loop (20 s wait, tier chosen at wait start, per-tier warning, sweep), damage/fling/ragdoll via Balance + resist upgrades, 2.5 s hit debounce, calls Inventory.onRagdoll/onDeath, Home rules (safe zone only, server-checked, not while ragdolled, 2 s cooldown), HUD cash/popups/carry line.

**T8 — MapBuilder & Shop (added after review).** Build the map from Config (safe zone, corridor, 14 pits via Brainrots.SetPitRects, walls, stripes, 5 plots, shop stall + pad) and the Shop server logic/UI (six upgrades, price curve, MAX state, K/M/B). Acceptance: geometry constants in Config only; shop purchases server-validated.

**T6 — Optional polish (only after T1–T5 pass):** sounds (pickup, hit, buy, wheel), void sky, rebirth system.

## 6. Engineering rules

Luau, `--!strict` where practical. Server-authoritative economy. Modules over monoliths; one responsibility each. Constants only in Config. No emoji-dependent UI without text fallback. Comments only where intent is non-obvious. Every task ends with a short `STATUS.md` entry: what changed, what is verified, what is **unverified** (no Studio access in this environment — say so, never imply a playtest happened).

## 7. Target layout

```
src/
  ReplicatedStorage/{Config.lua, Remotes.lua, BrainrotData.lua}
  ServerScriptService/{Main.server.lua, Wall, Brainrots, Bases, Inventory, Shop, Wheel, Saving, Home}
  StarterPlayerScripts/{HUD, ShopUI, InventoryUI, IndexUI, WheelUI, Warning}
default.project.json
docs/REMOTES.md
STATUS.md
```
Map geometry is built by a `MapBuilder` server module from Config so it is reproducible without Studio.

## 8. Refined master prompt (paste into any worker)

> You are implementing task `<Tn>` of *Escape Wall for Brainrots* in `~/Work-Projects/escape-wall-for-brainrots`. Read `GAME_SPEC.md` §3, §4, §6, §7 first. Implement only `<Tn>`; touch no unrelated files. Use `Config` for every number. The server is authoritative. Do not reintroduce anything in §4. Finish by appending a `STATUS.md` entry listing changes, what you verified, and what you could not verify. Stop and report if the spec is ambiguous or contradicts itself; do not guess silently.
