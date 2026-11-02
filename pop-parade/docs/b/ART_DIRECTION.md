# Art direction: POP PARADE (B)

## Look in one line
A bright toy carnival: chunky rounded shapes, cream floors, candy-stripe trim, and balloons in a 1,000-step rainbow, under soft afternoon light.

## Principles
1. **Silhouettes first.** Every station has a shape you can name from far away: striped booth (upgrades), glass pedestal (styles), giant wheel, gift booth, gazebo (premium AFK), arches (route and parkour gates). King Puffer's giant pink silhouette sits on the route gate so players see where they're headed from spawn.
2. **Clear hierarchy.** Floors are calm (cream/pastel), the play path is coloured lanes with white edge bumpers, interactables are saturated, and balloons are the brightest thing on screen. Decoration never uses balloon-shaped poppable-looking props near routes. The only exception is the decorative arch balloons, which sit high above the path.
3. **Varied heights.** The route climbs 5 studs per section, with ramps, catch floors 7 studs below the lanes, bonus ledges 4 studs up, and an arena on top. Lollipop trees and the tent break the skyline.
4. **Colour never carries meaning alone.** Upgrade colours (Needle red-pink, Speed sky, Attack orange, Hits violet, Life green; see `Branding.luau`) always come with an icon and a word.

## Palette
- **1,000-step spectrum:** OKLCH at fixed lightness 0.76 and chroma 0.16 (reduced only where sRGB requires it). This keeps brightness even, so no step reads as "the dark one". Formations sample it evenly (`Palette.stepFor`), and each theme shifts the start hue (`paletteOffset`).
- **Animated drift:** near balloons drift slowly through the palette (4 updates/s, per-slot phase). Reduced Effects freezes them at their base colour.
- **Material identity survives colour:** rubber = smooth with a little shine; wood = 55% tint over warm wood with grain material; steel = 45% tint over metal; gold = rainbow body inside a gold frame/knot; diamond = 60% tint on glass with transparency.

## Lighting
Afternoon sun (ClockTime 14.5), soft shadows, light haze in the theme's horizon colour, +12% saturation. `WorldBuilder.ApplyLighting` is optional; A's bootstrap decides.

## Hub ("Pop Plaza")
Radius-100 plaza. Spawn faces north with practice balloons 7 studs ahead. A checkerboard promenade leads under a balloon arch to the Rubber gate. Upgrade booths on the west arc, style pedestals on the east, wheel and rewards flanking the gate, AFK garden south-east, parkour gate west, Big Top tent south-west.

## Rubber stage (`stage.rubber.001`)
Five 80-stud sections, each ending in a checkpoint plaza and a ramp:
1. One wide lane (intro, 20 balloons).
2. Two lanes with two bridges (first branch).
3. Three lanes with a centre sweeper and side tack mats.
4. Two lanes with small 3-stud hops.
5. Three lanes with timed puff vents.

Then the drum arena with a striped backdrop. Lanes are colour-coded (coral, lime, sky, violet). Optional bonus balloons sit on gold-starred ledges outside the lanes and have gold knots.

## King Puffer
Giant pink balloon with eyes, a smile and a gold crown, plus a visible knot underneath (the weak point).
- **Wind-up:** swells, and a red filled ground warning grows over the exact wind-up time.
- **Air-pulse:** a white ring expands at the server's ring speed.
- **Knot phase:** the knot glows yellow, with a "Attack now!" toast.
- **Defeat:** quick shrink, then confetti and fireworks.

Ground warnings stay on with Reduced Effects; only tremble and shake are removed.

## Effects budget (per client)
Up to 30 pop bursts/s, 24 pooled emitters and 16 pooled rings. Up to 8 audio voices, with an inflate limiter of 2 per 0.5 s. Up to 260 balloon views within a 240-stud render distance; bob and hue only within 90 studs. Damage numbers: up to 5 live, merged within 0.3 s.

## Premium vs free
Premium (deluxe trails, ornate wings, starburst confetti) means richer animation and particles only, never stats. Free versions are designed to look good on their own. The wheel-exclusive **Founder's Ticket Punch** has its own identity: a navy and gold ticket-punch needle with a star finial and a pennant.

## Expansion themes (design only, NOT built)
Each is a data entry in `Themes.luau` with `status = "design"`. None is enabled or presented to players.

| Theme | Kind | Route identity | Boss key |
|---|---|---|---|
| Wood | material | toy workshop: plank bridges, see-saws, hollow carved sculpture (secret idea) | `boss.timber_toad` |
| Candy | confection | winding candy-cane routes, striped rails, gumdrop stepping stones | `boss.sugar_swirl` |
| Steel | material | clockwork factory: conveyor lanes, pistons on readable timers | `boss.rivet_rex` |
| Chocolate | confection | breakable-looking chocolate shells, wafer bridges over caramel | `boss.cocoa_shell` |
| Gold | material | vault with coin-stack platforms; gold-framed rainbow balloons | `boss.gilded_gust` |
| Ice Cream | confection | slippery-*looking* scoops with normal grip, waffle-cone towers | `boss.sundae_supreme` |
| Diamond | material | crystal caverns, faceted light bridges, refracted beams | `boss.prism_prime` |
| Halloween | confection | friendly pumpkins and ghost balloons, no gore; placed by config, not calendar | `boss.pumpkin_puff` |

**Next build order (after the first slice integrates):** Wood stage 001, then Candy stage 001. Each gets a layout module like `RubberStage001`, is registered in `WorldBuilder.stageLayouts`, passes `LayoutValidator`, and is marked `playable` only after a Studio playtest.

## Post-processing (client, toggleable)

The "toy parade" look comes from a few light touches on top of the pastel palette. All of them are client-only, live in `GraphicsController.luau`, and can be switched off in Settings → Graphics:

| Effect | Values | Why |
|---|---|---|
| Depth of field | focus follows the character (smoothed), in-focus radius 38, far 0.22, near 0.05 | tilt-shift miniature feel; distant rides soften so the play space reads first |
| Menu blur | Blur 12 while a panel is open (tied to the DoF toggle) | keeps panels readable over a busy world |
| Bloom | intensity 0.45, size 24, threshold 2.4 (1.4 washed pale floors to white in Studio) | only neon/bright parts glow (golden secrets, knots, ribbons); pastels stay crisp |
| Sun rays | intensity 0.025, spread 0.55 | soft shafts toward the sun, never washes out UI |
| Clouds | cover 0.5, density 0.45, warm white | fills the sky without a texture asset |
| Shadows | `Lighting.GlobalShadows` | off is a big speed-up on weak phones |
| Atmosphere (server) | density 0.26, offset 0.15, haze 1.4 | distance haze for depth |
| Colour (server) | exposure −0.15, saturation 0.22, contrast 0.12 | richer pastels under Future lighting |

Reduced motion & effects forces DoF, menu blur and sun rays off.
