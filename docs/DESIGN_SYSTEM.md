# Design system

**Light premium (2026-11-02, owner):** light by default (Dark and Adaptive in
You → Appearance). Paper ground #F3F2F7 / white cards by day, #0E0D14 /
#1A1822 by night; ONE accent, deep violet (default seed #8466FF, drawn in its
deep ink by day); type is Inter Tight (bundled), big and tight for headings.
Cards are tactile: a raised surface with a top-lit 1 px edge and a two-layer
neutral shadow (`Neon.halo` / `Neon.lift` / `Neon.cardShadow`) — no coloured
glow, no neon rims, no night-sky background. `GlowCard` is a raised tinted
card; `NeonPill` is a soft filled pill. Home: the violet Next card, the day in
numbers, one mixed "Later today" feed with Play my day, Assistants tiles.

Where it lives: tokens in `lib/design/neon_tokens.dart` (`Neon.*`,
`NeonTone`), widgets in `lib/design/neon_widgets.dart` and
`lib/design/neon_scaffold.dart`, motion in `lib/design/motion.dart`, and the
theme in `lib/theme/app_theme.dart`. The `Neon*` names are historical; they
draw the light design.

## Rules
- Use tokens, never raw `Colors.*` (the camera view's blacks are the exception).
- Everything tappable dips under the finger.
- Leave colours to the theme: it covers menus, dropdowns, date/time pickers,
  dialogs, sheets, chips, switches, tooltips, snackbars and FABs.
- With Remove animations on, every widget shows its final state and nothing ticks.

## Primitives

| Widget / API | Use |
|---|---|
| `NeonScaffold({..., bool sky = true})` | Every pushed page. The background sits outside a transparent `Scaffold`, so the keyboard doesn't re-layout it. `sky: false` = plain `Neon.bg`. |
| `Tappable({onTap, onLongPress, scale = 0.97, semanticLabel, tapHint, haptic})` | Press dip + light tick, announced as a button. No callbacks = returns the child unchanged. |
| `PressScale({child, scale = 0.97})` | The dip alone. Instant outside lists; keeps the 80 ms wait inside a `Scrollable`. Full-width rows use 0.985. |
| `GlowCard(..., onTap, onLongPress, heroTag, semanticLabel)` | With a callback it wraps itself in `Tappable`; with `heroTag` it flies to its page. |
| `cardHeroTag(id)` / `cardFlight` / `cardFlightFor({cardRadius, pageRadius})` | Card → page flight. The target page needs `Hero(tag: cardHeroTag(id), flightShuttleBuilder: cardFlight)`; tags must be unique on the screen. |
| `NeonSuccess({size = 72, label})` | Animated tick, `NeonSuccess.duration` = 700 ms. Announces itself; stops asking for frames once settled. |
| `NeonLoader.inline()` / `NeonLoader.page({label})` | Replace every raw `CircularProgressIndicator`. |
| `NeonEmptyState(..., actionLabel, actionIcon, onAction, tone)` | Empty pages, with an action as a `NeonPill` where one exists. `NeonErrorState` uses the danger tone. |
| `Motion.sheetSpring` / `Motion.sheetIn` (360 ms) / `Motion.sheetRise` / `SpringCurve(spring, settle:)` | Sheets rise on a spring damped to 0.9 (0.15% overshoot). `showAppSheet` uses it. |
| `FeedbackTone.warning` | Amber toast, lasts 5 s like an error. |
| `Neon.scrim` | The dark overlay behind dialogs and sheets. |
| `ToneTile(icon, tone)` · `RimCard({tone, onTap, heroTag, ...})` · `NeonSection({icon, title, tone, lit})` · `cardHero(...)` | `lib/widgets/neon_cards.dart`: icon tiles, toned cards, titled sections. |
| `GlowCta({label, onPressed, icon, busy})` · `BrandMark()` | `lib/widgets/glow_cta.dart`: full-width primary button and brand tile (first-run pages, consent, recorder). |
| `ChatBubble({mine, child})` · `ChatComposer({controller, onSend, sending})` · `ChatUnreadBadge` · `ChatAvatar` | `lib/widgets/chat_bubble.dart`. Sent bubbles use the brand gradient darkened to reach 4.5:1. |

`NeonPill` (0.95) and `AppleRow` (0.985) dip too.

## Voice orb moods
`enum OrbMood` in `lib/widgets/voice_orb.dart`; `orbMoodFor(engine)` picks it
and `orbMoodColor(mood)` gives the colour, taken from the `NeonTone` rims
(tip, info, action, success). One GPU shader draws it
(`shaders/voice_backdrop.frag`).

| Mood | Light | Movement |
|---|---|---|
| Idle | tip, dim | slow breath, under 2% |
| Listening | tip → info | rings pushed by the user's mic |
| Thinking | info | breath rolling outward, 4.5% |
| Responding | action | a light running round the inner ring + the tool's words ("Checking your calendar…") |
| Speaking | pink → action | rings pushed by the assistant's voice; ribbons sway only here |
| Done | success | one outward pulse, then rest |
| Connecting | info → tip | a quick ripple out through the rings |
| Paused | idle's light, still | while the user types, so nothing redraws under the keyboard |

The status line and the dock button's halo take the mood's colour. With Remove
animations on, each mood is its colour and words only.
