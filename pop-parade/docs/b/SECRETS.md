# Golden secrets: FULL SPOILERS (developer only)

> Do not copy this into player-facing UI. Placements are defined server-side in
> `src/server/world/SecretsLayout.luau` and never sent to clients as a list.

All three secrets can be reached with **free basic movement**: no wings, no double jump, no purchases and no help from another player. Each one grants a permanent +1% to one stat, once per account (A validates proximity and grants).

| ID | Name | Buff key | Where |
|---|---|---|---|
| `secret.rubber.waterfall` | Behind the Fizzy Falls | `buff.secret.speed_1pct` | Hub, north-east |
| `secret.hub.big_top` | Big Top Peek | `buff.secret.attack_1pct` | Hub, south-west of spawn |
| `secret.rubber.underbridge` | Under the Rainbow Bridge | `buff.secret.needle_1pct` | Rubber stage, section 2 |

## 1. Behind the Fizzy Falls
- **Landmark:** a lilac candy-rock wall at the plaza's north-east edge, with a translucent "soda" waterfall pouring over its middle.
- **Clue:** a trail of seven small fizzy bubbles on the ground runs toward the falls, shrinking as it goes, and disappears into the water.
- **Solution:** walk straight through the waterfall; it has no collision. Behind it is a small cave with the golden balloon at about (75, 4.5, −52).
- **Trigger radius:** 5 studs.

## 2. Big Top Peek
- **Landmark:** the red-and-white striped circus tent near spawn (centre about (−30, 0, 82)).
- **Clue:** on the plaza side of the tent there's a short stack of wooden crates (1, 2 and 3 high). The lowest crate has a small glowing gold star sticker.
- **Solution:** climb the crates (3-stud steps), hop 2 studs up onto the tent's lowest roof ring, then climb the stepped roof rings to the flat cap. The golden balloon floats above the cap at about y = 22.
- **Trigger radius:** 5 studs.

## 3. Under the Rainbow Bridge
- **Landmark:** Rubber stage, section 2 (the first two-lane split). The first lane-to-lane bridge is 25 studs into the section.
- **Clue:** three diamond-shaped arrow tiles on the safety (catch) floor below section 2 point toward that bridge.
- **Solution:** drop off a lane onto the catch floor 7 studs below and walk to the spot under the first bridge. The golden balloon sits low (2.5 studs above the catch floor); the trigger radius reaches it from beside the bridge. To get back up, step onto the previous checkpoint plaza (one 2-stud step) or follow the "Missed one? Hop back up!" sign.
- **Trigger radius:** 6 studs.

## Verification
- `tests/b/unit/Secrets.spec.luau` checks that each secret sits within reach of a surface connected to the start by base-movement jumps (gap ≤ 4, rise ≤ 4).
- **Pending (needs Studio):** actually walk each path with a default R15 character, including headroom under the bridge, the waterfall pass-through and the crate-to-roof hop. See `TEST_RESULTS.md`.

## Expansion budget
The spec allows up to 15 secrets (5 per stat, capped at +5% per stat). Ideas already designed into themes:
- **Wood:** inside the hollow of the carved sculpture.
- **Candy:** a reachable roof behind a candy sign.
- **Ice Cream:** under the waffle-cone tower's brim.

New secrets need a stable ID, a clue, a written solution here, and an access test.
