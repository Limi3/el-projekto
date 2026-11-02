# POP PARADE UI design system (native Roblox UI)

Figma was **not connected** in this session, so the UI was built directly in Roblox (`src/client/UI`) and this file is the Figma-ready spec. Tokens live in code: `Theme.luau` (colours, sizes, z-order), `Branding.luau` (brand colours), `Icons.luau` (procedural icons). If Figma is connected later, build the library from these tokens so design and code stay one source.

## Tokens
| Token | Value / source |
|---|---|
| Fonts | Display: FredokaOne (titles, numbers); Bold: GothamBold (labels); Body: Gotham |
| Ink / ink soft | `Branding.ink` / rgb(100,94,130) |
| Paper / paper dim | `Branding.paper` / rgb(240,233,250) |
| Primary / secondary | rgb(255,92,140) / rgb(80,170,255) |
| Status | good, warn, hurt (`Branding.status`) |
| Currency | Coins, XP, Tickets (`Branding.currency`); golden `Branding.golden` |
| Upgrade colours | Needle, Speed, Attack, Hits, Life (`Branding.upgrade`) |
| Rarity | Common → Legendary (`Branding.rarity`) |
| Corners | panels 18, cards 14, buttons 12, banner 22 |
| Strokes | panel 4 (panel colour), card 2, banner 5 |
| Touch target | ≥ 44 px (`Theme.size.touchMin`) |
| Z-order | hud 1, menu 5, panel 20, modal 40, toast 60, banner 80 |
| Scale | UIScale = viewport height / design height, clamped; compact layout under 500 px high or touch |

## Components
- **Button** (`Kit.button`): solid/outline, icon + one word, disabled state greys out and blocks clicks, gamepad selection ring.
- **Panel** (`Panel.luau`): coloured header with icon + title, X close (Esc / gamepad B), scrolling body, pop-in animation; `setTitle(text, icon)`.
- **Card** (`Panel.card`, `ItemCard`): swatch/icon, name, honest status line, one action button.
- **Bar** (`Kit.bar`): XP, boss HP, journal progress.
- **Toast** (`Toasts`): bottom-centre stack above the hint line; kinds good/bad/gold.
- **Moment banner** (`Banner`): centre card under the HUD for boss intro, victory, defeat, finish; one at a time.
- **Menu**: 2-column grid desktop / 3-column compact; "More" pop-out (Wheel, Rewards, Journal, Settings) with badges.

## Screen states (every panel)
Loading ("Loading…") · Server unavailable (disabled actions, no fake numbers) · Pending (button disabled while a request is in flight) · Error (toast with the server's code) · Disabled with reason (MAX, can't afford, locked, last stage) · Empty (Inventory category empty).

## Accessibility
Reduced Effects and Screen Shake settings; every effect has a non-motion cue; text never relies on colour alone (labels + icons); gamepad: Y focuses the menu, B closes.
