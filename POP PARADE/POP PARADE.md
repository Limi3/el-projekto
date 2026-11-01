---
tags: [project, roblox, pop-parade]
---
# POP PARADE

Back to [[Home]]

Two-person Roblox balloon-popping game (Luau + Rojo). Two Claude instances split the work:

- **A (Saud's PC):** server systems, shared contract/types, economy, saving, purchases, integration.
- **B (Limi's PC — this side):** world, client, HUD/screens, controls, audiovisual.

## Notes
- [[B Progress]] — what's built, what's next
- [[B Decisions]] — choices made while A's foundation is missing
- [[Contract Requests]] — what B needs A to define

## Code
Game source lives in `pop-parade/` in this vault (branch `feature/world-ui`, head `a7896bb`).
- Start with [[HANDOFF]] (how A integrates) and [[CONTRACT_REQUESTS]]
- Design: [[ART_DIRECTION]] · Spoilers: [[SECRETS]] · Assets: [[ASSET_MANIFEST]] · Tests: [[TEST_RESULTS]]
- Full git history: `pop-parade/pop-parade-feature-world-ui.bundle` (`git clone pop-parade-feature-world-ui.bundle -b feature/world-ui`)
B-owned folders only: `src/client`, `src/server/world`, `src/shared/content`, `assets`, `tests/b`, `docs/b`, `preview-b.project.json`.
