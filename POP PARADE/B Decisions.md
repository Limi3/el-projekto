# B Decisions

Back to [[POP PARADE]]

- **No foundation from A yet** (checked 2026-11-01): built B-owned parts in isolation; provisional types live in `src/shared/content/ContentTypes.luau` and will be swapped for A's contract types.
- **Paths requested from A:** `ReplicatedStorage.PopParade.Content`, `ServerScriptService.PopParadeWorld`, `StarterPlayerScripts.PopParadeClient`.
- **Wood is design-only**, so Rubber's `nextStageId` is nil (last available stage) rather than pointing at an unbuilt world.
- **No sound IDs invented**: all sounds fall back to visual cues until real, licensed assets are supplied.
- **Secrets** live only in server code (`src/server/world/SecretsLayout.luau`); spoilers in `docs/b/SECRETS.md`.
