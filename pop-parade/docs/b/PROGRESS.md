# B progress log

## 2026-11-02: playable preview in Roblox Studio

**Done**
- [x] Built and played the preview place in Studio (no Rojo: `tests/b/tools/build_place.py`).
- [x] Fixed Studio-found bugs: spawn before world, More popup layout, sound names, Speed header icon, wheel spokes, toast/hint overlap, journal progress, journal icon, banner over HUD, boss parts left after defeat.
- [x] World polish: section name signs + per-section lane colours on Rubber 001.
- [x] WorldFeedback + Banner: checkpoint arches turn green with confetti; boss intro, VICTORY, POPPED!, FINISH banners.
- [x] Test-only preview: hazard motion (sweeper, vents), mock checkpoints, hazard hearts + respawn, secret discovery, parkour finish.
- [x] Docs: client architecture, adapter interface, remotes, missing server ops, temporary code (`HANDOFF.md`); `UI_DESIGN_SYSTEM.md`; Studio results (`TEST_RESULTS.md`).
- [x] Checks: luau-lsp clean, lint ok, 42 unit tests passing.

**Next**
- [ ] A: foundation + server ops listed in `HANDOFF.md` → integrate and replay with real remotes.
- [ ] Walk every secret and the full route on foot; vents push; parkour extra-jump shortcut.
- [ ] Phone emulator, gamepad, two clients, purchases (pending in `TEST_RESULTS.md`).
- [ ] Sounds from the owner; Figma library if Figma gets connected.


## 2026-11-01: first B slice (isolated; A's foundation pending)

**Done**
- [x] Checked for A's foundation: none found (no shared repo or commit). Built only B-owned paths and documented the dependency (`CONTRACT_REQUESTS.md`).
- [x] Shared content: 1,000-step OKLCH palette, material treatments (rubber/wood/steel/gold/diamond), themes (Rubber playable; 8 expansion themes design-only), VisualCatalog, AudioCatalog, Branding, localization-ready Strings.
- [x] World: `WorldBuilder.Build/Destroy`, hub (all stations, AFK free/premium, gates, aspirational boss), Rubber stage 001 (100 required slots, branching lanes, catch floors, hazards, 6 checkpoints, King Puffer arena), Parkour 001 "Ribbon Run" (4 checkpoints, optional extra-jump shortcut, end marker), 3 golden secrets (server-only).
- [x] Validator: IDs, 100-slot count, links, reachability with base movement.
- [x] Client: single bootstrap, GameClient adapter (real/mock), protocol rules, balloon renderer, effects, damage numbers, audio, cosmetics, extra jump, boss presenter, world prompts, purchases.
- [x] HUD and all screens: XP line, coins, stage progress, hearts, boss bar, boost timer, status, onboarding; menu (6 one-word buttons + More); Upgrades, Sound, Inventory, Shop, Wheel, Rewards, Settings, Journal, Skip Token.
- [x] Checks: luau-lsp clean, lint ok, 42 unit tests passing.

**Next**
- [ ] A: foundation + answers to contract requests → B rebases and adapts.
- [ ] Integrate hub → route → boss with A's real systems; then parkour, secrets, rewards/wheel, inventory and monetization screens.
- [ ] Studio playtests and device checks (`TEST_RESULTS.md`, pending list).
- [ ] Sounds from the owner.
- [ ] Wood 001, then Candy 001 (after first integration).
