# B Progress

Back to [[POP PARADE]]

## Done (2026-11-02 evening), head `e5147e2`
- [x] One clean "server adapter" (`ServerAdapter.luau`) that every menu and controller now uses to talk to Saud's server, with a test proving it can't grant anything
- [x] Extra jump fixed: quick double taps and holding Space no longer break it (found while playing in Studio)
- [x] King Puffer: players can't walk under him any more; they stop in front of the glowing knot
- [x] Phone layout: menus fit a landscape phone (tested with Studio's iPhone XR simulation)
- [x] Puff vents verified (they lift you ~19 studs); Ribbon Run finish banner fires first time
- [x] Checks: type-check clean · lint ok · **43 unit tests passing**

## Done (2026-11-02) — playable Studio preview, head `fc8db67`
- [x] Preview place built and **played in Roblox Studio** (`pop-parade/build/PopParade-PreviewB.rbxlx`, open it and press Play)
- [x] Fixed the bugs found while playing: spawn order, More menu, sound names, panel icons, prize wheel drawing, toast overlap, journal, banner position, boss leftovers after defeat
- [x] Rubber stage sections now have names on the arches (1 · WARM-UP WAY … KING PUFFER'S DRUM) and their own lane colours
- [x] Checkpoint arches turn green with confetti; big banners for KING PUFFER intro, VICTORY!, POPPED! and FINISH!
- [x] Test-only preview: moving sweeper + vents, hearts lost on hazards, respawn at last checkpoint, golden secrets found in the journal, parkour finish
- [x] Docs: [[HANDOFF]] (client architecture, adapter, remotes, server ops Saud must build), [[UI_DESIGN_SYSTEM]], Studio results in [[TEST_RESULTS]]
- [x] Checks: type-check clean · lint ok · **42 unit tests passing**

## Done (2026-11-01) — first slice, head `a7896bb`
- [x] Shared content, world builder (hub, Rubber stage 001, Ribbon Run, 3 secrets), client adapter, HUD + all screens

## Waiting on A (Saud's side)
- [ ] Foundation commit + answers to [[CONTRACT_REQUESTS]]
- [ ] Server ops listed in [[HANDOFF]]: checkpoints, hazards, secrets, boss loop, parkour finish

## Still pending — see [[TEST_RESULTS]]
- [ ] Walk every secret and the whole route on foot (today's secret checks used teleports)
- [ ] Gamepad with a real controller, text size on a real phone, two clients, real purchases
- [ ] Real sound files ([[ASSET_MANIFEST]]); Figma library if Figma gets connected
