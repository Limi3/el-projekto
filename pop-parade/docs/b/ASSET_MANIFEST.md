# Asset manifest (B)

Rule: **no invented Roblox asset IDs, and no copyrighted sounds or art without permission.** Every row records the ID, source, licence and owner, or is clearly marked as a placeholder. `tests/b/tools/lint.py` fails the build if any `rbxassetid://<number>` appears in B's code without going through this manifest.

Current state: **zero uploaded assets.** The game is fully playable with procedural visuals. All sounds are missing and fall back to visual cues (`AudioCatalog.visualFallback`).

## Sounds (all MISSING: placeholders)

| ID | Purpose | Status | Fallback | Owner / licence |
|---|---|---|---|---|
| `sound.classic_pop` | free pop sound | MISSING | white ring | — |
| `sound.soft_bubble` | free pop sound | MISSING | bubbles ring | — |
| `sound.rubber_snap` | free pop sound | MISSING | ring | — |
| `sound.squeak` | free pop sound | MISSING | ring | — |
| `sound.tiny_firework` | free pop sound | MISSING | gold sparkle ring | — |
| `sound.arcade_blip` | optional pack `soundpack.arcade` | MISSING | ring | — |
| `sound.kazoo_toot` | optional pack `soundpack.party` | MISSING | ring | — |
| `sound.drum_hit` | optional pack `soundpack.party` | MISSING | ring | — |
| `sfx.inflate` | airy reinflate | MISSING | none (inflate tween is visible) | — |
| `sfx.boss_windup` | boss anticipation | MISSING | red ground warning (always shown anyway) | — |
| `sfx.boss_pulse` | boss air pulse | MISSING | ring | — |
| `sfx.boss_defeat` | boss defeat | MISSING | fireworks burst | — |
| `sfx.checkpoint` | checkpoint | MISSING | toast | — |
| `sfx.secret_found` | secret found | MISSING | celebration burst | — |
| `sfx.hurt` | lose a heart | MISSING | red flash | — |
| `ui.click`, `ui.reward`, `ui.wheel_tick` | UI | MISSING | none | — |
| `music.hub` | plaza music loop | MISSING | silence | — |

**How to fill one in:** the owner uploads a sound they made or have a licence for (Creator Hub → Audio), puts `assetId = "rbxassetid://…"` in `src/shared/content/AudioCatalog.luau`, and fills in this row: ID, source, licence, owner, date. Roblox's own licensed audio library is fine if its terms allow use in experiences; record which track.

## Visuals (procedural; no uploads needed)

| Thing | How it's made | Upload later? |
|---|---|---|
| Balloons | Part + SpecialMesh sphere, palette colour, knot, string | optional custom mesh |
| King Puffer | spheres + parts (eyes, crown, knot) | yes: a custom mesh would help |
| Needle skins (6 + default) | small welded parts | optional |
| Trails (3 + 3 deluxe) | `Trail` + optional `ParticleEmitter` (default texture) | optional textures |
| Wings (basic/ornate) | thin parts | yes: a proper wing mesh |
| Confetti / pop | `ParticleEmitter` default texture + neon ring | optional confetti texture |
| UI icons | procedural Frames (`src/client/UI/Icons.luau`) | optional image icons with the same keys |
| Fonts | Roblox built-ins: Fredoka One, Builder Sans | — |

## Placeholders to replace before launch
1. All 17 sound/music entries above.
2. King Puffer and wings meshes (nice to have; the procedural versions read fine).
3. Game icon and thumbnails (owner, outside this repo).
