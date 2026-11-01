# B → A contract requests

Status: **open**. Written 2026-11-01 by B (world/client/UI) before A's foundation commit existed.
Everything below is a *request*, not a decision. A owns the contract (`docs/CONTRACT.md`, `src/shared/contracts/**`). Accept, change or reject each item. B will adapt its own files to whatever A decides and will not edit A's files.

Where B had to pick a shape to keep working, it lives in **one** B-owned file so a change touches one place:

| B file | Holds |
|---|---|
| `src/shared/content/ContentTypes.luau` | provisional layout + manifest field types |
| `src/server/world/WorldBuilder.luau` | provisional `WorldManifest` shape |
| `src/client/GameClient/Actions.luau` | provisional action payloads |
| `src/client/State/Selectors.luau` | which `ClientState` fields the UI reads |
| `tests/b/mock/Fixtures.luau` | provisional fixtures (replace with A's) |

---

## 1. Rojo layout (A's `default.project.json`)

| Instance path | Source | Note |
|---|---|---|
| `ReplicatedStorage.PopParade.Content` | `src/shared/content` | B's shared presentation content (ModuleScript with children) |
| `ReplicatedStorage.PopParade.Remotes` | created by A | the four RemoteEvents |
| `ReplicatedStorage.PopParade.Balance` *or* `BalanceView` | A | client-readable balance accessor (see §5) |
| `ServerScriptService.PopParadeWorld` | `src/server/world` | **server-only**: contains secret placements |
| `StarterPlayer.StarterPlayerScripts.PopParadeClient` | `src/client` | contains the single production client bootstrap |

If A prefers other paths, only `src/client/Paths.luau` and the `content()` helper at the top of `src/server/world/WorldBuilder.luau` need to change.

## 2. WorldBuilder interface

Implemented exactly as the contract says: `WorldBuilder.Build(parent, options) -> WorldManifest` and `WorldBuilder.Destroy(manifest)`.

- `BuildOptions = { seed: number, enabledStageIds: {string}, testMode: boolean }`
- Build validates layouts **before** creating Instances and errors with a readable report on: duplicate IDs, wrong 100-slot count, checkpoint order gaps, hazard/boss links to missing checkpoints, non-finite transforms, required balloons over no floor or out of reach, and required slots/boss arena unreachable with base movement.
- `enabledStageIds` may only contain stages B has actually built (`stage.rubber.001` today). Design-only themes error instead of silently building nothing.
- Optional helper: `WorldBuilder.ApplyLighting(Lighting)`. **Request:** A's bootstrap calls it once after `Build` (or tells B it doesn't want B touching Lighting).

### Proposed `WorldManifest` fields

```
schemaVersion: number            seed: number           testMode: boolean
root: Model                      spawn: CFrame
stages:      { StageDef }        routes: { RouteDef }   checkpoints: { CheckpointDef }
balloons:    { BalloonDef }      bosses: { BossDef }    hazards: { HazardDef }
secrets:     { SecretDef }       -- PRIVATE, server only
afkStations: { AfkStationDef }   parkourCourses: { ParkourDef }
decor:       { DecorMarkerDef }  validation: { [id]: Report }
```

Field-level types are in `WorldBuilder.luau` (top of file). Highlights:

- `BalloonDef.position` is the logical centre (Vector3). Cosmetic bob is client-only and never applied here.
- `BalloonDef.tierKey` values B uses: `hub.practice`, `rubber.t1`, `rubber.t2`, `rubber.t3`, `rubber.bonus`, `parkour.side`. **Request:** A maps these to HP/rewards in balance (first balloons = one hit).
- `BalloonDef.required = false` for hub practice, bonus ledges and parkour side balloons. They never count toward a stage objective.
- Hub practice balloons use `stageId = "stage.hub"` and parkour side balloons use `stageId = "parkour.001"`. **Request:** confirm A is fine with those zone IDs, or give B the IDs to use.
- `CheckpointDef.volume` is an invisible non-colliding Part with attributes `PopParadeCheckpoint`, `Order` and `StageId`. Detection is A's job, ideally server-side spatial checks rather than `Touched`.
- `HazardDef.instance` is a Model with attributes `PopParadeHazard`, `BehaviorKey` and `CheckpointId`. Its parts are non-colliding, and A animates them and applies effects. Behaviour keys and suggested params:
  - `sweeper`: `{ armLength=18, rpm=9, height=2, knockback=30 }`. Model has `PrimaryPart = Pivot`; rotate it with `PivotTo`.
  - `tack_mat`: `{ damageHearts=1, invulnSeconds=1.5 }`
  - `puff_vent`: `{ period=4, telegraph=1, active=1.2, push=40, phase }`. Has a `Nozzle` attachment for telegraph particles.
- `BossDef` (`boss.king_puffer`): `params = { windup=1.2, ringSpeed=18, ringMaxRadius=38, ringHeight=3, knotPhase=6, bodyRadius=11 }` are **suggested defaults only**. A owns real values and bounds. `weakPointOffset` is relative to `anchor`.
- `StageDef.nextStageId` is `nil` for Rubber, because Wood is design-only and Rubber is the last available stage. **Request:** A's skip logic treats `nil` as "last available stage" (Skip Token disabled, tokens kept).
- `SecretDef.buffKey` values: `buff.secret.speed_1pct`, `buff.secret.attack_1pct`, `buff.secret.needle_1pct`. **Request:** A registers these in its server buff registry, capped at +5% per stat.
- `ParkourDef`: start/finish CFrames, a finish volume, ordered checkpoints `cp.parkour.001.01..04`, bounds (fall below `bounds.min.y = -25`), shortcut `shortcut.parkour.001.kite_line` (needs the normalised extra jump), and `jumpExpectations` (main path: max gap 3, max rise 3, no extra jump needed).

## 3. Network: envelopes and events

B uses the four contract remotes and envelopes exactly. `GameClient` connects listeners first, ignores stale `revision`s, requests `GetWorldSnapshot` on sequence gaps, and dedupes Pop/Inflate per `(slotId, generation)`.

**Requests / clarifications:**

1. **`WorldUpdate.snapshot`.** B treats any truthy value as "full snapshot of the relevant balloon states for this player; replace local belief". **Request:** confirm, or define the shape.
2. **`GetState` result.** B expects `data = { revision, serverTime, state }` so it can be applied like a `StateUpdate`.
3. **`GetWorldSnapshot` result.** B expects `data` to be a full `WorldUpdate` message (`v, sequence, stageId, snapshot=true, balloons, events={}`).
4. **Generation semantics.** B assumes `Pop{slotId, generation=g}` means generation `g` was popped, and `Inflate{slotId, generation=g+1}` means a new active generation. Please confirm.
5. **BalloonState fields B reads:** `slotId, generation, state ("Active" | "Popped" | "Respawning"), hp, maxHp, respawnAt`. B does **not** need A to send BalloonDefs to clients: positions, colours and materials come from B's public shared layouts by stable ID. This saves bandwidth. **Request:** confirm A won't send defs per player.
6. **Event payloads B renders** (proposed):
   - `Damage { sourceUserId, slotId, generation, amount }`. Boss damage reuses `slotId = bossId`; AFK station damage uses `slotId = afkStationId` and drives the giant station numbers.
   - `Pop { slotId, generation, sourceUserId }`
   - `Inflate { slotId, generation }`
   - `BossTelegraph { bossId, kind = "windup" | "pulse" | "knot", startsAt (serverTime), duration, params? { ringSpeed, ringMaxRadius } }`
   - `BossState { bossId, hp, maxHp, phase = "idle" | "windup" | "pulse" | "knot" | "defeated" }`
   - `Checkpoint { checkpointId }`
   - `SecretFound { secretId, stat = "speed" | "attack" | "needle" }`
   - `WheelResult { requestId, itemId, rarity, duplicate, coins }`
7. **Coin/XP gain popups** are derived from `ClientState` deltas, not from a reward event. No `Reward` event is needed.

## 4. Action payloads (provisional, in `Actions.luau`)

| Action | Payload B sends | Result `data` B reads |
|---|---|---|
| GetState | `{}` | `{ revision, serverTime, state }` |
| GetWorldSnapshot | `{ stageId? }` | a WorldUpdate |
| BuyUpgrade | `{ upgradeId }` | (state update) |
| SetMoveSpeed | `{ speed }` | (state update) |
| EquipItem | `{ slot, itemId? }` (`itemId=nil` to unequip) | — |
| SetSetting | `{ key = "music" \| "sfx" \| "reducedEffects" \| "shake", value }` | — |
| EnterMode | `{ mode = "hub" \| "parkour" }` | — |
| EnterStage | `{ stageId }` | — |
| RestartRun | `{}` | — |
| ClaimDaily | `{}` | `{ claimIndex, tickets, coins, itemId? }` |
| RequestSpin | `{}` | `{ spinId, itemId, rarity, duplicate, coins, founderGranted }` |
| ConsumeItem | `{ itemId }` | `{ remainingSeconds }` (Double XP) |
| UseSkipToken | `{ stageId }` | `{ skippedStageId }` |
| RequestPurchase | `{ offerId }` | `{ purchaseType = "GamePass" \| "DeveloperProduct", id: number }` |
| RequestExtraJump | `{ t = serverTime, pos = {x,y,z} }` (intent only) | `{ granted }` |

Idempotency: B retries `RequestSpin` with the **same requestId** after a timeout and expects the same stored outcome. B also treats `ClaimDaily`, `ConsumeItem`, `UseSkipToken`, `BuyUpgrade` and `RequestPurchase` as idempotent by requestId.

## 5. ClientState fields the UI reads

(Exact list in `Selectors.luau`; example values in `tests/b/mock/Fixtures.luau`.)

`coins, xp` (progress **within** the current level), `xpNeeded` (nil or 0 = max level), `level, upgrades[Id].level, stats{damage, attacksPerSecond, moveSpeedMax, reach, targets, maxHearts}, selectedSpeed, mode ("hub" | "stage" | "parkour" | "afk"), currentStageId, stageProgress{stageId, done, total}, completedStages[], skippedStages[], isLastAvailableStage, equipped{slot→id}, owned{id→true}, consumables{id→count}, accessoryBonuses{id→display text}, daily{claimIndex, canClaim, nextResetAt, activeSeconds, milestones{speed,attack,needle}, tickets{t15,t30}}, secrets{found[], total, buffs{speed,attack,needle}}, spinTickets, spinsCompleted, founderSpinsRequired, pendingSpin{spinId,...}, wheel{table[{itemId,rarity,probability}], duplicateCoins{rarity→coins}}, boost{remainingSeconds, paused, capSeconds}, shop{rotationId, refreshAt, featured[offerId], collection[offerId]}, offers{offerId→{itemId, kind="pass" | "product", available, permanent, owned?, productId?}}, settings{music, sfx, reducedEffects, shake}, run{hearts, maxHearts, checkpointId, stunned?, boss{id,hp,maxHp,phase}}`.

Notes:
- `offers[].productId` is the pass/product ID A authorises **for price display**. B fetches the live price with `MarketplaceService:GetProductInfoAsync`. With no ID, the card shows "Price unavailable" and the Buy button stays disabled.
- `accessoryBonuses` should be display text A computes from its own stats (for example `"+3% speed"`). B never computes stat values.

### Balance accessor (A-owned, client-readable)

```
upgradeMaxLevel(id) -> number?
upgradeCost(id, level) -> number?        -- cost from level -> level+1
upgradeValueText(id, level) -> string?   -- e.g. "8 dmg"
speedRange(state) -> { min, max }?
```

Without it, the upgrade screen shows "Unavailable" rather than invented numbers.

## 6. Other players' cosmetics

**Request:** A sets these Player attributes from the server whenever equipment changes: `PopParade_NeedleSkin`, `PopParade_Trail`, `PopParade_Wings`. B renders them for everyone nearby.

## 7. Item IDs B proposes (A owns the final list)

Spec IDs are used verbatim (`skin.rubber_twist`, `skin.candy_swirl`, `skin.chrome_spiral`, `skin.neon_helix`, `skin.prism_crown`, `skin.wheel_founder`). B also proposes:

- `skin.default`
- `trail.rainbow`, `trail.rainbow_deluxe`, `trail.rocket`, `trail.rocket_deluxe`, `trail.neon`, `trail.neon_deluxe`
- `wings.basic` (free, first legit boss), `wings.ornate` (paid; same double jump)
- `popfx.confetti`, `popfx.streamers` (7th daily claim cosmetic), `popfx.starburst_deluxe`
- `accessory.zoom_sneakers`, `accessory.focus_goggles`, `accessory.sharp_glove`
- `consumable.skip_token`, `consumable.double_xp`
- `sound.classic_pop`, `sound.soft_bubble`, `sound.rubber_snap`, `sound.squeak`, `sound.tiny_firework`
- pack sounds `sound.arcade_blip` (`soundpack.arcade`), `sound.kazoo_toot` and `sound.drum_hit` (`soundpack.party`)

Unknown IDs render with a neutral placeholder, never an error.

## 8. Things B deliberately did NOT do (A's side)

No DataStores, no receipts, no reward grants, no combat loop, no hazard/boss damage, no checkpoint validation, no secret granting, no product creation, no balance values. The test-only mock in `tests/b/mock` imitates contract shapes so screens can be exercised. It is never in a production build, and the client shows a permanent TEST PREVIEW banner while it runs.
