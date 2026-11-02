# B test results

Last automated run: **2026-11-02** (43 passed). Last Studio session: **2026-11-02**, branch `feature/world-ui`. Command: `tests/b/tools/check.sh` (see `tests/b/README.md`).

**Honesty rule:** "EXECUTED" means it actually ran and the result is recorded as observed. "PENDING" means it has **not** been done. Roblox Studio *was* used on 2026-11-02 (single client, mock transport, keyboard + mouse, desktop window). Real phones, controllers, two-client sessions, A's server and real purchases were **not** tested.

## EXECUTED (automated, outside Studio)

| Check | Tool | Result |
|---|---|---|
| Static type analysis, all B Luau (`src/client`, `src/server/world`, `src/shared/content`, `tests/b/mock`, `tests/b/preview`) against current Roblox API definitions | luau-lsp 1.70.1 `analyze` (definitions from luau-lsp main, Oct 2026), strict mode | **0 errors, 0 warnings** |
| Lint: every literal string key exists; dynamic key families complete; no hardcoded `rbxassetid://` numbers; production code never references test-only code; no "100× earnings" claims; no prices/odds/product IDs/secret data in shared content | `tests/b/tools/lint.py` | **ok** (128 keys used, 280 defined) |
| Unit tests (pure logic, Luau CLI) | `tests/b/tools/bundle.py` + `luau` | **43 passed, 0 failed** |

### What the 43 unit tests cover
- **Palette:** 1,000 in-range colours, ≥ 900 distinguishable, minimum luminance > 0.25, spread < 0.4, smooth interpolation, wrap, even sampling. Every material supports every step; gold keeps its frame.
- **Rubber stage:** passes the validator (unique IDs, exactly 100 required, ordered checkpoints, hazard/boss links, finite transforms, every required balloon over floor within reach). **Every platform is reachable from the start with base movement** (gap ≤ 4, rise ≤ 4). Deterministic. Branches into 1/2/3 lanes. 10 optional balloons only on bonus routes. 6 checkpoints. Arena after the last checkpoint. `nextStageId = nil`. Sweeper can't reach the side lanes.
- **Parkour:** main path reaches the finish and every checkpoint with base movement; the shortcut needs the normalised extra jump (0 shortcut ledges reachable without it); side balloons never sit on or in platforms.
- **Hub:** first balloon within 9 studs in front of spawn; 5 kiosks, displays, wheel, rewards, both gates, free and premium AFK; IDs unique across hub/stage/parkour.
- **Secrets:** 3 secrets, one per buff, ID format; both hub secrets and the under-bridge secret are reachable with free movement (surface graph); no secret data in the public hub layout.
- **Protocol:** only contract actions; request-ID length bound; stale/older/wrong-schema states rejected; sequence gaps force a snapshot; pop/inflate once per generation.
- **ServerAdapter:** sends intents only (no balance in payloads), has no client-side grant/detection methods, spin retry with the same request ID returns the same stored outcome.
- **GameClient + mock server:** listeners connected before the first request; pops update authoritative state and fire once; a dropped world update triggers a snapshot that carries the missed pop; timeout reports `TIMEOUT` and a retry with the same request ID returns the same spin without spending a second ticket; an unavailable server yields `NOT_READY` and no state; a required slot counts once even after respawn.
- **Selectors:** XP line equals the spec example; upgrade current/next/cost/max/affordable; missing balance shows unavailable; wheel slices exactly proportional (0.1% = 0.36°), landing stays in the middle 60%; odds not summing to 100% are flagged; owned permanent offers suppressed and unconfigured products disabled; skip-token rules including last stage; daily track never resets and playtime milestones; stage progress/hearts/boss visibility.
- **Feel:** damage-number merging and capping; one-objective-at-a-time onboarding.
- **Strings:** key families; catalog names; exact spec sentences; no invented sound IDs.


## EXECUTED in Roblox Studio (2026-11-02, single client, TEST PREVIEW mock)

Place built from `preview-b.project.json` with `tests/b/tools/build_place.py` (Rojo was not installed), opened in Studio, Play (F5). Teleports were done from the command bar to reach each area; walking was done with the keyboard.

| Check | Result (observed) |
|---|---|
| World build, Output | **Pass.** `world built in 0.04–0.05s: 773 parts, 126 balloons, 6 checkpoints, 6 hazards, 3 secrets`; stage + parkour validation `ok=true`; no errors or warnings from B code |
| Spawn order (world before character) | **Pass** after fix (`CharacterAutoLoads=false` + spawn after build) |
| Balloon popping, coins/XP gain, damage numbers, onboarding hints | **Pass** (mock auto-attack) |
| Panels: Needle/Speed/Attack upgrades, Sound, Inventory, Shop, Wheel, Rewards claim, Journal, Settings, More popup | **Pass** after fixes (More popup was laid out by the grid; sound names showed "Mystery Item"; Speed header icon; wheel spokes; toasts overlapped the hint; journal had no progress) |
| Section identities: name signs "1 · WARM-UP WAY" … "KING PUFFER'S DRUM", per-section lane colours | **Pass** (signs readable at the arches, sections 2/3 visibly different hues) |
| Checkpoint arrival (stage cp 02, parkour cp 01–04): arch turns green/neon, confetti, "Checkpoint!" toast | **Pass** (banner colour verified via command bar: cp 02 → Neon green) |
| Sweeper Street: test-only rotating sweeper costs a heart, side-lane tack mats visible | **Pass** (hearts 3 → 2) |
| Tack mats ×3 → defeat banner "POPPED!" → respawn at last checkpoint, hearts restored | **Pass** after fix (mock hit volume did not reach a standing character) |
| King Puffer: intro banner, boss bar, wind-up/pulse/knot telegraphs, HP drops in knot phase, VICTORY banner, boss pops | **Pass** after fixes (banner moved below the HUD; eyes/crown/knot now vanish with the body) |
| Golden secrets: Big Top, Fizzy Falls, Under the Bridge discovered (mock proximity), gold toasts, Journal 1/3 with description | **Pass** (reached by teleport, so the *walking* routes are still pending) |
| Ribbon Run finish banner | **Pass on the first pass** after fixing the test-only re-arm logic |

### Second Studio session (2026-11-02, evening)

| Check | Result (observed) |
|---|---|
| Extra jump (parkour) | **Bug found and fixed.** Quick double taps were ignored because `FloorMaterial` still reads the floor for several frames after take-off (logged: still "SmoothPlastic" 3 studs up). Holding Space also repeats `JumpRequest` every frame. Now airborne = humanoid state Jumping/Freefall, and only a *new* press fires. Verified: a mid-air press fires once (`fired`), a second press in the same airtime is refused (`used`), measured upward velocity +39 studs/s |
| Puff vents (test-only animator) | **Pass:** standing on a vent lifts the player 19 studs when it fires; the rim flashes before each puff |
| King Puffer approach | **Bug found and fixed.** The body's lowest point was level with a player's head, so players walked under it and the camera went inside the boss. An invisible pedestal now stops players at the front; verified the player stops below the glowing knot and HP drops |
| Phone layout (Studio Device Simulation, iPhone XR landscape) | **Bug found and fixed.** Panels were taller than the phone screen (Shop cut off at the bottom). Panels now take at most 84 % of the screen height. Verified Shop fits; menu, More pop-out, thumbstick and jump button don't overlap. Text size on a *real* phone still needs checking |
| Gamepad (Studio Controller Emulator) | **Not completed.** The emulator opened, but its key mapping couldn't be read reliably from here. Still pending (real controller preferred) |
| Tooling | Found that re-sending a file to the PC under the same path could deliver the previous copy. `tests/b/tools/stage_for_device.sh` stages under a unique name, and each build was checked by md5 on the PC before testing |

## PENDING: needs Roblox Studio / devices / A's systems

| Check | Why pending | How to run |
|---|---|---|
| Walk the 100-slot route end to end with a default R15 at speed 16 (all gaps/ramps, catch-floor returns, bonus ledges) | needs Studio | play test; tick each section |
| Walk all 3 secrets (headroom under the bridge, waterfall pass-through, crate → roof hop) | needs Studio | see `SECRETS.md` |
| Parkour Kite Line shortcut jumped on foot | extra jump verified mechanically; the full shortcut run wasn't walked (input latency from here) | play it with keyboard |
| Hazard behaviour with A's real server logic (vents push, sweeper knockback) | **A runs behaviour**; the preview uses a test-only animator (`tests/b/preview/PreviewHazards.server.luau`); vent push not observed yet | after integration |
| Boss with real A events; Reduced Effects on/off during the fight | needs A's boss system | mock telegraphs checked visually (above) |
| Two clients: personal balloon state, nobody steals progress, others' cosmetics visible | needs Studio multi-client + A | Studio "Test → Clients: 2" |
| Real-phone readability and touch feel (text size, touch targets ≥ 44 px) | layout checked in Device Simulation only | a real phone |
| Controller navigation (Y focuses menu, B closes, D-pad between buttons, focus ring visible) | needs a gamepad (Studio emulator attempt not completed) | plug in a controller and Play |
| Readable text contrast in all panels | visual check | |
| Purchases: live price fetch, denied/unavailable, prompt-closed ≠ grant | needs real pass/product IDs from the owner + A's receipt handling | |
| Network errors: server missing → "Server unavailable"; reconnect → resync | needs Studio (remove A's remotes, or the mock with `available=false`) | |
| Every fixture state in the preview UI | needs Studio | set `FIXTURE` in `tests/b/mock/MockTransport.luau` to each name in `Fixtures.LIST` |
| Long session (30–60 min) pool and connection profile: no growth in `PopParadeBalloons`, effects or connections | needs Studio MicroProfiler/Memory | |
| Performance targets (30 FPS modest phone, 60 FPS capable) | needs hardware | |
| Real sounds | **no assets supplied yet** (`ASSET_MANIFEST.md`) | |
