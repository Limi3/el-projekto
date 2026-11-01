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
`rojo serve preview-b.project.json` → Studio → connect → Play. You'll see the hub, the Rubber route and the parkour course, with the mock auto-pop, HUD and all screens under a yellow TEST PREVIEW banner. Change `FIXTURE` in `tests/b/mock/MockTransport.luau` to preview other states.

## Known gaps and next steps (B)
1. All Studio, device and two-client checks are **pending** (`TEST_RESULTS.md`).
2. Sounds: no assets yet (`ASSET_MANIFEST.md`).
3. Expansion: Wood stage 001, then Candy stage 001, only after the first slice integrates (`ART_DIRECTION.md`).
4. Once A's contract lands: replace `ContentTypes.luau` with A's types, swap the fixtures for A's, then re-run the checks.
