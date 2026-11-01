# B test results

Last run: **2026-11-01**, branch `feature/world-ui`. Command: `tests/b/tools/check.sh` (see `tests/b/README.md`).

**Honesty rule:** "EXECUTED" means it actually ran here and passed. "PENDING" means it has **not** been done. Roblox Studio, real phones, controllers and two-client sessions were not available in this environment, and nothing below claims they were.

## EXECUTED (automated, outside Studio)

| Check | Tool | Result |
|---|---|---|
| Static type analysis, all B Luau (`src/client`, `src/server/world`, `src/shared/content`, `tests/b/mock`, `tests/b/preview`) against current Roblox API definitions | luau-lsp 1.70.1 `analyze` (definitions from luau-lsp main, Oct 2026), strict mode | **0 errors, 0 warnings** |
| Lint: every literal string key exists; dynamic key families complete; no hardcoded `rbxassetid://` numbers; production code never references test-only code; no "100× earnings" claims; no prices/odds/product IDs/secret data in shared content | `tests/b/tools/lint.py` | **ok** (119 keys used, 261 defined) |
| Unit tests (pure logic, Luau CLI) | `tests/b/tools/bundle.py` + `luau` | **42 passed, 0 failed** |

### What the 42 unit tests cover
- **Palette:** 1,000 in-range colours, ≥ 900 distinguishable, minimum luminance > 0.25, spread < 0.4, smooth interpolation, wrap, even sampling. Every material supports every step; gold keeps its frame.
- **Rubber stage:** passes the validator (unique IDs, exactly 100 required, ordered checkpoints, hazard/boss links, finite transforms, every required balloon over floor within reach). **Every platform is reachable from the start with base movement** (gap ≤ 4, rise ≤ 4). Deterministic. Branches into 1/2/3 lanes. 10 optional balloons only on bonus routes. 6 checkpoints. Arena after the last checkpoint. `nextStageId = nil`. Sweeper can't reach the side lanes.
- **Parkour:** main path reaches the finish and every checkpoint with base movement; the shortcut needs the normalised extra jump (0 shortcut ledges reachable without it); side balloons never sit on or in platforms.
- **Hub:** first balloon within 9 studs in front of spawn; 5 kiosks, displays, wheel, rewards, both gates, free and premium AFK; IDs unique across hub/stage/parkour.
- **Secrets:** 3 secrets, one per buff, ID format; both hub secrets and the under-bridge secret are reachable with free movement (surface graph); no secret data in the public hub layout.
- **Protocol:** only contract actions; request-ID length bound; stale/older/wrong-schema states rejected; sequence gaps force a snapshot; pop/inflate once per generation.
- **GameClient + mock server:** listeners connected before the first request; pops update authoritative state and fire once; a dropped world update triggers a snapshot that carries the missed pop; timeout reports `TIMEOUT` and a retry with the same request ID returns the same spin without spending a second ticket; an unavailable server yields `NOT_READY` and no state; a required slot counts once even after respawn.
- **Selectors:** XP line equals the spec example; upgrade current/next/cost/max/affordable; missing balance shows unavailable; wheel slices exactly proportional (0.1% = 0.36°), landing stays in the middle 60%; odds not summing to 100% are flagged; owned permanent offers suppressed and unconfigured products disabled; skip-token rules including last stage; daily track never resets and playtime milestones; stage progress/hearts/boss visibility.
- **Feel:** damage-number merging and capping; one-objective-at-a-time onboarding.
- **Strings:** key families; catalog names; exact spec sentences; no invented sound IDs.

## PENDING: needs Roblox Studio / devices / A's systems

| Check | Why pending | How to run |
|---|---|---|
| Studio build of `preview-b.project.json` (Rojo) and world visual review | Rojo/Studio not available here | `rojo serve preview-b.project.json`, connect from Studio, press Play; Output should print the `[PopParade TEST PREVIEW] world built …` line |
| Walk the 100-slot route end to end with a default R15 at speed 16 (all gaps/ramps, catch-floor returns, bonus ledges) | needs Studio | play test; tick each section |
| Walk all 3 secrets (headroom under the bridge, waterfall pass-through, crate → roof hop) | needs Studio | see `SECRETS.md` |
| Parkour main path, shortcut with extra jump, fall → checkpoint | needs Studio + A's checkpoint handling | |
| Hazard behaviour (sweeper, tack mats, vents) | **A runs behaviour**; B only built geometry | after integration |
| Boss telegraph readability with real A events, Reduced Effects on/off | needs A's boss system | mock telegraphs exist for a visual check |
| Two clients: personal balloon state, nobody steals progress, others' cosmetics visible | needs Studio multi-client + A | Studio "Test → Clients: 2" |
| Narrow phone layouts (e.g. 667×375, 844×390): menu clears thumbstick, jump button clear, touch targets ≥ 44 px | needs device emulator | Studio Device Emulator + a real phone |
| Controller navigation (Y focuses menu, B closes, D-pad between buttons, focus ring visible) | needs a gamepad | |
| Readable text contrast in all panels | visual check | |
| Purchases: live price fetch, denied/unavailable, prompt-closed ≠ grant | needs real pass/product IDs from the owner + A's receipt handling | |
| Network errors: server missing → "Server unavailable"; reconnect → resync | needs Studio (remove A's remotes, or the mock with `available=false`) | |
| Every fixture state in the preview UI | needs Studio | set `FIXTURE` in `tests/b/mock/MockTransport.luau` to each name in `Fixtures.LIST` |
| Long session (30–60 min) pool and connection profile: no growth in `PopParadeBalloons`, effects or connections | needs Studio MicroProfiler/Memory | |
| Performance targets (30 FPS modest phone, 60 FPS capable) | needs hardware | |
| Real sounds | **no assets supplied yet** (`ASSET_MANIFEST.md`) | |
