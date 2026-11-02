# B handoff → A (and the two humans)

## TL;DR
B's side of POP PARADE is built in isolation because **A's foundation commit didn't exist yet** (checked 2026-11-01). Everything is in B-owned folders on branch `feature/world-ui`. Integration needs A to (1) answer `CONTRACT_REQUESTS.md`, (2) map B's folders in `default.project.json`, and (3) call `WorldBuilder.Build` once in the server bootstrap.

## Commits (branch `feature/world-ui`)
Run `git log --oneline feature/world-ui` for exact hashes. Milestones, oldest first:
1. Shared content and layouts (palette, materials, themes, catalogs, strings, hub, Rubber 001, Parkour 001, validator, test tooling)
2. WorldBuilder with hub, Rubber stage, parkour and server-only secrets
3. GameClient adapter, protocol rules, selectors, mock server and fixtures
4. Client bootstrap, controllers, HUD and every screen
5. B docs (this file and its siblings)

> The branch starts from an empty repo, **not** from A's foundation (it didn't exist yet). When A pushes the foundation, B rebases `feature/world-ui` onto it. Conflicts should be zero because B touched only B-owned paths.

## How A integrates (steps)
1. **Rojo:** map the paths in `CONTRACT_REQUESTS.md §1`. Do not map `tests/b/**` in `default.project.json`. It is preview-only.
2. **Server bootstrap (A's file):**
   ```lua
   local WorldBuilder = require(ServerScriptService.PopParadeWorld.WorldBuilder)
   local manifest = WorldBuilder.Build(workspace, { seed = 1, enabledStageIds = { "stage.rubber.001" }, testMode = false })
   WorldBuilder.ApplyLighting(game:GetService("Lighting")) -- optional
   -- validate manifest, register balloons/checkpoints/hazards/boss/secrets/afk/parkour in A's systems
   ```
   Keep `manifest.secrets` server-side.
3. **Remotes:** create the four RemoteEvents under `ReplicatedStorage.PopParade.Remotes`. The client finds them by name.
4. **Balance accessor:** expose `ReplicatedStorage.PopParade.Balance` with the 4 functions in `CONTRACT_REQUESTS.md §5`.
5. **State and events:** send the `ClientState` fields and event payloads listed in §3 and §5 (or tell B your shapes, and B will adapt `Actions.luau` and `Selectors.luau`).
6. **Other players' cosmetics:** set the `PopParade_*` Player attributes (§6).

## What B guarantees
- B never grants anything, saves anything, validates purchases, runs combat, or invents prices/odds/stats.
- The client renders only what A's state says. No server means a "Server unavailable" banner, never fake Coins.
- The test mock exists only in `tests/b`, is loaded only in Studio when `tests/b` is mapped, and shows a permanent TEST PREVIEW banner.
- Wheel: shows A's exact odds before spinning, animates A's already-resolved result, retries with the same request ID, and recovers rather than rerolls.
- Skip Token screen states exactly what is skipped and not awarded, and is disabled at the last available stage.
- Premium AFK shows big station-local damage numbers with an honest rate label ("1.5× the free station"), never "100× earnings".

## Run B's checks
See `tests/b/README.md`. Short version: `tests/b/tools/check.sh` (luau-lsp + Roblox definitions, lint, 42 unit tests).

## Preview in Studio (B only, before integration)
`rojo serve preview-b.project.json` → Studio → connect → Play. Without Rojo: `tests/b/tools/preview_build.sh` writes `build/PopParade-PreviewB.rbxlx`; open it in Studio and press Play. You'll see the hub, the Rubber route and the parkour course, with the mock auto-pop, HUD and all screens under a yellow TEST PREVIEW banner. Change `FIXTURE` in `tests/b/mock/MockTransport.luau` to preview other states.

## Known gaps and next steps (B)
1. Single-client Studio checks done 2026-11-02; device, gamepad, two-client and purchase checks are **pending** (`TEST_RESULTS.md`).
2. Sounds: no assets yet (`ASSET_MANIFEST.md`).
3. Expansion: Wood stage 001, then Candy stage 001, only after the first slice integrates (`ART_DIRECTION.md`).
4. Once A's contract lands: replace `ContentTypes.luau` with A's types, swap the fixtures for A's, then re-run the checks.

---

## Client architecture (B)

```
Bootstrap.client.luau ─ picks transport (RemoteTransport in production; MockTransport only in Studio when tests/b is mapped)
  └ GameClient (src/client/GameClient)            ← the server adapter; only door to A
       Protocol.luau   envelopes, revision/sequence/generation rules
       Actions.luau    one builder per contract action (payload shapes)
       RemoteTransport four RemoteEvents under ReplicatedStorage.PopParade.Remotes
       signals: StateChanged(state, prev) · WorldEvent(ev) · BalloonState · WorldSnapshot · StatusChanged · LateResult · SchemaMismatch
  └ App.luau  builds HUD, menu, panels, controllers; ctx = { client, Content, S, Actions, balance, toast, banner, openPanel, ... }
       Controllers: BalloonRenderer, EffectsController, DamageNumbers, AudioController, CosmeticsController,
                    PurchaseController, BossPresenter, ExtraJumpInput, WorldHints, WorldFeedback (new)
       UI: Hud, Menu, Toasts, Banner (new), Panel + 9 panels, ItemCard, Kit/Theme/Icons
       State: Selectors (pure reads of ClientState), Onboarding
```

### Adapter interface (what UI code may call)
`ctx.server` = `src/client/GameClient/ServerAdapter.luau`, the only way UI talks to A. One method per action, each returns its request ID and calls back once with `{ ok, code?, data? }`:
`requestState(), requestWorldSnapshot(), buyUpgrade(id, cb), setMoveSpeed(n, cb), equipItem(slot, id?, cb), consumeItem(id, cb), setSetting(key, value, cb), enterMode(mode, cb), enterStage(stageId, cb), restartRun(cb), useSkipToken(stageId, cb), requestExtraJump(pos?, cb), claimDaily(cb), requestSpin(cb, retryId?), requestPurchase(offerId, cb)`, plus read-only `onState(fn)`, `onWorldEvent(fn)`, `state()`.
Payload shapes live only in `Actions.luau`. The UI shows pending/disabled while a request is in flight and an error toast on failure; nothing in the UI mutates state locally. Unit-tested: no grant/detection methods exist, payloads never carry balances, spin retries are idempotent.

**Conflict with the brief, resolved on the safe side:** the brief lists client calls like "hit balloon", "discover secret", "reach checkpoint". B deliberately has **no** client ops for these. Balloon hits, damage, checkpoints, secret discovery and boss damage are **server-detected by A** (position/volume checks); the client only renders A's events. This keeps clients from claiming rewards or damage.

### Remotes
| Remote | Direction | Message |
|---|---|---|
| `ActionRequest` | C→S | `{ v=1, requestId, action, payload }` |
| `ActionResult` | S→C | `{ v=1, requestId, ok, code?, data? }` |
| `StateUpdate` | S→C | `{ v=1, revision, serverTime, state=ClientState }` |
| `WorldUpdate` | S→C | `{ v=1, sequence, stageId?, snapshot?, balloons[], events[] }` |
Payloads and `ClientState` fields: `CONTRACT_REQUESTS.md §3–§5`.

### HUD/world events B renders
`Damage, Pop, Inflate, BossTelegraph, BossState, Checkpoint, SecretFound, WheelResult` (contract §3.6) plus **new B proposal:** `ParkourFinished { courseId }` → FINISH banner. Moment banners are driven by state: boss intro (run.boss appears), defeat (run.hearts → 0), victory (`BossState phase=defeated`).

### Missing server operations (A to build)
1. Checkpoint detection from the tagged volumes (`PopParadeCheckpoint`, `Order`, `StageId`) → `Checkpoint` event + `run.checkpointId`.
2. Hazard behaviour by `BehaviorKey` (sweeper rpm, tack_mat damageHearts/invuln, puff_vent period/telegraph/active/push) using the layout params; hearts in `run.hearts`.
3. Secret detection from `SecretsLayout` (server-only) → `secrets.found`, `buffs`, `SecretFound` event.
4. Boss loop: telegraph events with `startsAt` in server time, damage only during the knot phase, `BossState`.
5. Parkour finish detection from `PopParadeFinish` → `ParkourFinished` (or tell B your event name).
6. Everything in `CONTRACT_REQUESTS.md` (balance accessor, offers with product IDs, daily, wheel, skip token).

### Temporary development code (never in `default.project.json`)
`tests/b/mock/*` (MockServer, MockTransport incl. mock checkpoints/hazard hearts/secret proximity/parkour finish, Fixtures), `tests/b/preview/PreviewServer.server.luau` (test world build + spawn), `tests/b/preview/PreviewHazards.server.luau` (test-only hazard motion), `tests/b/tools/build_place.py` (builds a .rbxlx when Rojo isn't installed), `tests/b/tools/stage_for_device.sh` (unique-name staging for the PC copy).
Studio-only QA breadcrumb in production code: `ExtraJumpInput` sets the LocalPlayer attribute `PopParadeExtraJumpGate` (why the last mid-air press did or didn't fire) **only when `RunService:IsStudio()`**. All are labelled TEST-ONLY and the preview shows a permanent TEST PREVIEW banner.

### Integration steps (updated)
1. Map paths per §1; keep `tests/b/**` out of `default.project.json`.
2. Call `WorldBuilder.Build` in A's bootstrap; register manifest items in A's systems; keep secrets server-side.
3. Create the 4 remotes and the Balance accessor.
4. Implement the missing server ops above; send events with the payloads listed.
5. Play `default.project.json` in Studio: the TEST PREVIEW banner must be **absent**; HUD should show A's real state.
6. Run `tests/b/tools/check.sh`, then the PENDING list in `TEST_RESULTS.md` (two clients, phone emulator, gamepad, purchases).
