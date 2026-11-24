# 0004 — Cabinet, riffle and hand: how they're built

- **Status:** Accepted (on-device timings pending: see "Measuring")
- **Date:** 2026-11-24
- **Issue:** #148

## Context

"Savour by hand" (`docs/design/INTERACTION.md`, epic E16) replaces list picking with three
physical surfaces: a **turning cabinet** of collections, a **riffle** of keepsakes inside a
drawer, and a **hand** of blank keepsakes drawn from the savour pill. The owner settled the
product questions on 24 Nov 2026 (§13): the cabinet **wraps around**, it is the default
Collections view, the hand keeps a **fixed order**, and on the pill **hold draws** while
**tap opens the sheet**.

This spike decides how each surface is built in SwiftUI on iOS 26, how gestures are
arbitrated, how VoiceOver and Reduce Motion are served, and how performance is measured.
Budget: 120 fps on ProMotion (8.3 ms a frame) and at least 60 fps on the oldest iOS 26
iPhone (A13 class); nothing animates when idle.

Cloud sessions can build and run tests on CI simulators but cannot run a device or
Instruments, so the measurements are a separate owner-only task. Every choice below has a
fallback that keeps the same public shape, so a bad measurement changes an implementation,
not the screens built on it.

## Options considered

### The turning cabinet

1. **Custom physics: `CabinetDrum` + `DrawerGeometry`.** A value type holds a continuous
   position (in drawers) and velocity; a drag sets the position 1:1, release projects the
   landing drawer (`Motion.project`, at most ±3, `Motion.landingIndex`) and a spring
   (`Motion.roll`) animates the position there. Positions wrap modulo the drawer count.
   `DrawerGeometry(offset:)` turns a drawer's signed distance from the front into a y-axis
   rotation, offset, scale, z-index and shade: pure maths, unit-tested.
   *Pros:* wraps around (the owner's choice), supports the lucky-dip spin, one model for
   drum ↔ chest morphing, testable without UI. *Cons:* we own momentum and accessibility.
2. **Horizontal `ScrollView` + `.viewAligned` + a cylinder transform in `visualEffect`.**
   *Pros:* native momentum, laziness and VoiceOver order for free. *Cons:* no wrap-around,
   no spin, and the chest morph must cross containers.

### The riffle

1. **Vertical `ScrollView` + `LazyVStack(spacing: −overlap)` + `.scrollTargetLayout()` +
   `.viewAligned` + `visualEffect`** reading each card's distance from the lip.
   *Pros:* native momentum, rubber-banding, laziness for 1,000 films, VoiceOver order;
   pure transforms with no per-frame state writes. *Cons:* `viewAligned` with negative
   spacing has quirks.
2. **A custom pager** like the drum. *Pros:* full control. *Cons:* re-implements scrolling
   for long lists.

### The hand on the savour pill

1. **SwiftUI gestures:** `LongPressGesture(minimumDuration: 0.17)` sequenced into a
   `DragGesture(minimumDistance: 0, coordinateSpace: .global)` on the pill, driving a root
   overlay on `AppShellView` (the hand must draw over the whole screen).
2. **`UILongPressGestureRecognizer` via `UIGestureRecognizerRepresentable`** with unlimited
   `allowableMovement`, for continuous window-space locations even if the system
   intercepts the SwiftUI gesture inside `tabViewBottomAccessory`.

## Decision

- **Cabinet: option 1, custom physics, wrapping.** `CabinetDrum` (state + `release`,
  `settle`, wrap-around maths) and `DrawerGeometry` live in Features as plain types with unit
  tests. The view draws at most five drawers (front ± 2); everything else is not in the
  hierarchy. A `TimelineView` is not needed: SwiftUI springs animate the drum's position
  through an `Animatable` modifier, so the drum costs nothing when idle.
- **Riffle: option 1, `ScrollView` + `visualEffect`,** with a fixed card pitch. If the
  `viewAligned` quirks bite, swap in the drum's physics as a vertical pager; the riffle's
  public view does not change.
- **Hand: option 1 first, option 2 as the fallback.** The hand's layout (`HandLayout`:
  N blanks on an arc, selection by `atan2` of the finger from the pill with a 46 pt dead
  zone) and its selection maths are plain types with unit tests, independent of which
  recogniser feeds them. If a UI test or the owner's device run shows the accessory
  swallowing the long press, swap the recogniser; the tap path (sheet) always works.
- **Gesture arbitration.**
  - Roll is horizontal, pull is vertical: a single `DragGesture` locks to an axis after
    10 pt of travel (`|dx|` vs `|dy|`), then drives either the drum position or the pull.
  - Pinch (`MagnifyGesture`) runs simultaneously and scrubs the drum ↔ chest morph.
  - Tab-bar swipes don't conflict: the shell has no swipeable pages.
  - If simultaneous recognition misbehaves on device, move the pull to a
    `UIPanGestureRecognizer` via `UIGestureRecognizerRepresentable` with
    `gestureRecognizerShouldBegin` checking `|vy| > |vx|`.
- **Accessibility.** The drum is never exposed in 3D: `accessibilityRepresentation` swaps in
  an ordered list of drawer buttons with Open, Move earlier, Move later, Put away and Share
  actions. The riffle reads cards in scroll order with Lift out / Re-duel / Share actions.
  The pill is a button (tap = sheet) with custom actions "Savour a café", "Stamp a country"…
  Reduce Motion draws the drum flat with crossfades, the riffle without rotation, the hand
  in place; haptics stay. From AX3 the chest is the default and drawers open into spreads.
- **Haptics.** One detent per drawer/card/blank crossing the centre, throttled to 30 ms by
  `DetentThrottle` (`.detentHaptic(trigger:)`); clunk on open/shut, lift on carry, the tear
  pattern on tear-off (motion and haptics kit II).
- **Wrap-around** is kept (owner decision). With one or two drawers the drum does not wrap
  (it would show the same drawer on both sides); it rubber-bands at the ends instead.

## Measuring

The owner-only task "Measure the cabinet, riffle and hand on device" (#149) runs this procedure on
an A13-class iPhone (e.g. iPhone 11 / SE 2nd gen) and a ProMotion iPhone, with the sample
data plus 500 extra items (`-sampleData -stressItems 500`, added with the cabinet):

1. Release build, Instruments **SwiftUI** template (View Body, Hitches) and the **Animation
   Hitches** template.
2. For each gesture, five repetitions: a slow drum roll across 6 drawers, a hard fling,
   pull-to-open and back, pinch to the chest and back; later a riffle fling through 100
   cards and the hand fan with a slide across all blanks.
3. Record the hitch-time ratio (target < 5 ms/s, Apple's "good") and the worst frame time,
   in a table appended to this ADR.

If the budget is missed: first the keepsake raster cache (E16, promote to P0), then
reduce the drum to front ± 1 drawers, then the riffle's custom-pager fallback.

## Consequences

- E16 tickets build on these types: `CabinetDrum`, `DrawerGeometry`, `HandLayout`; the
  motion and haptics kit II tokens (`Motion.roll`, `.pull`, `.morph`, `.fan`,
  `rubberBand`, `project`, `landingIndex`; `Haptic.detent`, `.clunk`, `.lift`, `.tear`).
- The physics and geometry are unit-tested on CI; the feel and frame rate are judged on
  device by the owner, with screenshots from UI tests in every PR meanwhile.
- The two-column cabinet grid (#113) becomes the chest rather than being deleted, so its
  reorder and hide logic and VoiceOver actions carry over.
