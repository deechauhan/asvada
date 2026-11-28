# Artifacts · Savour by hand

*Interaction concept · 23 Nov 2026 · **approved by the owner 24 Nov 2026**, full plan (epic E16) with the recommended answer to every open question (§13). Builds on the approved Keepsakes design (`docs/design/CONCEPT.md`): it changes how you choose and browse, not what things look like.*
*Companion: `prototype/savour-by-hand.html` (open it on a phone or desktop and handle it). The ticket changes are applied in `backlog/backlog.yaml` (E16 and the edits listed in §11).*

---

## The big ideas in ten lines

1. **One grammar everywhere.** Roll to browse one thing at a time, pull to open, pinch to see everything, hold to commit. You learn it once on the cabinet, and it means the same thing in every drawer, on the globe and in quick-log.
2. **The turning cabinet** (Collections). One drawer sits big and centred on a revolving column. Swipe and it rolls to the next, clicking once per drawer, then eases ajar so its best three keepsakes rise into view. Pull the drawer toward you to open it.
3. **The chest** (the overview). Pinch, or tap *All drawers*, and the column folds into the whole chest of drawers. Hold a drawer to carry it to a new place, or drop it in the storeroom to hide it. Today's grid becomes this overview, so no reorder or hide logic is lost.
4. **The riffle** (inside a drawer). Keepsakes stand on end like cards in a library catalogue drawer, and you thumb through them one at a time. Index tabs show the order (No. 1, No. 2… or the year). Tap the front one to lift it out and turn it over; pinch to tip the drawer out onto the table.
5. **Draw a keepsake** (quick-log). Hold *Savour something* and a hand of blank keepsakes fans out over your thumb. Slide onto one and let go. Each blank always sits in the same direction, so experts can just flick. A plain tap still opens a sheet.
6. **The print head.** The drawn blank prints its best guess: the café you're standing in, the last film you rewatched, the airline you always fly. Tear it off sideways for the next guess, or type. Rank, relish or date it, then hold the ā. A repeat visit takes about 6 s; the prototype logs a country in about 7.
7. **Spin & stamp** (countries). Spin an ink globe, aim the ring and press the rubber stamp. The country floods with ink and its stamp lands in your passport. Typing flies the globe to a country, and a continent chip deals a strip of unstamped stamps for the 30-countries-in-30-seconds path.
8. **Lucky dip** (rediscovery). Flick the cabinet hard and it spins, clicking slower until it lands. A face-down keepsake rises out of that drawer; tap to turn it over. Anniversaries stick out of their drawer on a saffron tab.
9. **For M1** I recommend the turning cabinet with the chest, the riffle, draw-a-keepsake with the print head, and a stamp pad on the existing flat ink map. The globe follows in M2 (Map collage) and the lucky dip in M4 (Look back).
10. **Cost:** +31 points net, of which +24 lands in M1 (about 1.7 sprints at the planned 14 pts a sprint). Every gesture ships with a visible handle, a tap path, a VoiceOver path and a Reduce Motion crossfade.

---

## 0. Why it still feels like picking from lists

The Keepsakes work fixed how things *look*, but most choosing still happens in lists:
- **The cabinet** (`screenshots/113/cabinet.png`) is a static two-column grid. Nothing moves until you press Edit, and then everything jiggles.
- **Quick-log** (`112/quick-log.png`) is a plain `List` of collections under "What did you savour?" (`Shell/QuickLogSheet.swift`).
- **Countries** (`117/country-picker.png`) are a faint map above a long A–Z list grouped by continent. Onboarding's `StampStep` adds a grid of flag tiles.

The verbs are still *scroll, tap a row, tick*. Nothing invites you to linger, handle, flip, pull or rediscover. This proposal swaps those verbs for physical ones while keeping every fast path.

---

## 1. Research: what we borrowed and why

*Sources were read on 23 Nov 2026. Three pages (rauno.me, blakecrosley.com, culturedcode.com) can't be reached from this sandbox's network, so their points come from search summaries rather than a full read.*

### 1.1 Show one thing big, keep its neighbours in view
- **Cover Flow.** Andrew Coulter Enright proposed it in 2004 and Steel Skies built it. Apple bought it for iTunes 7 in 2006, then retired it with Apple Music in iOS 8.4 (2015) and from the Finder in macOS Mojave ([Wikipedia](https://en.wikipedia.org/wiki/Cover_Flow), [history](https://mjtsai.com/blog/2023/10/13/the-history-of-cover-flow/)). *Lesson:* one big item with its neighbours visible is instantly readable and fun to flick, but it faded as the *only* way into a big library. Every focus view here sits next to an overview and search.
- **Wallet.** It shows saved cards as a stack, like a real wallet, and the front card is the one at hand ([Pratt critique](https://ixd.prattsi.org/2026/09/design-critique-apple-wallet-ios/)).
- **iOS 18 Photos.** Apple announced a swipe-right carousel of collections, then removed it in beta 5 because scrolling already reached the same collections ([MacRumors](https://www.macrumors.com/2024/08/05/ios-18-beta-5-photos-app/), [9to5Mac](https://9to5mac.com/2024/07/22/ios-18-photos-hands-on-get-ready-for-major-changes/)). *Lesson:* a carousel has to earn its place. Ours is the main way in, with a chest one pinch away, so it never duplicates a scroll.

### 1.2 Gestures that are physical verbs
- **Tinder.** It modelled its stack on a deck of cards. The first version had no swipe at all, and Jonathan Badeen added it because "using the buttons to move the cards felt clunky… I wanted more fluidity" ([CNBC](https://www.cnbc.com/2017/01/06/how-a-tinder-founder-came-up-with-swiping-and-changed-dating-forever.html), [VentureBeat](https://venturebeat.com/business/why-swipe-right-wasnt-in-the-first-version-of-tinder), [Wikipedia](https://en.wikipedia.org/wiki/Tinder_(app))). *Lesson:* a throw can replace a button. Throwing a card away also means *no*, though, so Artifacts only lets you tear off **suggestions**, never your keepsakes.
- **Clear.** You pull down to create an item, and a vertical pinch closes a list into the list of lists ([MacStories](https://www.macstories.net/reviews/clear/)). *Lesson:* pinch means "change level". We use it for exactly three things, and they're the same move: cabinet ↔ chest, riffle ↔ spread, globe ↔ flat map.
- **Paper by FiftyThree.** Users complained that a slightly wrong pinch was read as the rewind gesture ([MacRumors forum](https://forums.macrumors.com/threads/fiftythree-gives-behind-the-scenes-look-at-developing-papers-zoom-feature.1585592), [Wikipedia](https://en.wikipedia.org/wiki/FiftyThree)). *Lesson:* never give one gesture two meanings.
- **Things 3's Magic Plus.** Tapping creates a to-do; dragging the + drops the new to-do exactly where you let go ([Cultured Code](https://culturedcode.com/things/support/articles/2803582/), [features](https://culturedcode.com/things/features/)). *Lesson:* the create button can carry intent. Our savour pill becomes a hand you draw from.

### 1.3 Fluid physics
- **[WWDC18 · Designing Fluid Interfaces](https://developer.apple.com/videos/play/wwdc2018/803/).** Respond instantly, and keep everything redirectable mid-gesture. Project where a fling would come to rest from its release velocity and the scroll deceleration rate. Rubber-band at boundaries. Wait for about 10 pt of travel before deciding a direction. Start at 100% damping and "reward that momentum with a little bit of overshoot". Hint which way a gesture goes. ([Nathan Gitter's walkthrough](https://medium.com/@nathangitter/building-fluid-interfaces-ios-swift-9732bb934bf5).)
- **[WWDC23 · Animate with springs](https://developer.apple.com/videos/play/wwdc2023/10158/).** Springs take a duration and a bounce. Bounce 0 is the default; about 0.15 feels brisk, about 0.3 is noticeably bouncy, and above about 0.4 is too much for UI. Springs keep a gesture's velocity and retarget smoothly, and SwiftUI tracks gesture velocity automatically. All our springs follow this model.
- **Rauno Freiberg, [Invisible Details of Interaction Design](https://rauno.me/craft/interaction-design)** ([Every mirror](https://every.to/p/invisible-details-of-interaction-design)). Gestures should be interruptible like a real page flip, keep momentum, and decide sensibly *when* a swipe commits.
- **Benji Taylor, [Family Values](https://benji.org/family-values)** (on the Family wallet app). Every animation explains the path from A to B, and transient actions live in trays that grow out of where you are.

### 1.4 Juice, with restraint
- **Balatro** (2025 Apple Design Award, Delight and Fun, game). Its cards are never still: they hover, tilt toward the pointer and catch light on their foil, and its counters roll rather than appear. That feedback is layered across motion and sound ([analysis](https://blakecrosley.com/guides/design/balatro), [80.lv breakdown](https://80.lv/articles/balatro-s-card-movements-shaders-recreated-in-unity)). The research definition of "juice" is deliberately excessive feedback relative to the input ([survey](https://arxiv.org/pdf/2011.09201)). *Lesson:* stack motion, haptic and sound on the few moments that matter (a click, a clunk, a thunk, a seal) and keep idle screens quiet, as CONCEPT already asks: one hero animation per screen.
- **[2025 Apple Design Award winners](https://developer.apple.com/design/awards/2025/)** ([newsroom](https://www.apple.com/newsroom/2025/06/apple-unveils-winners-and-finalists-of-the-2025-apple-design-awards/)). CapWords won Delight and Fun by turning photos of everyday objects into collectible cards. In [2024](https://developer.apple.com/design/awards/2024) Delight and Fun went to Bears Gratitude and NYT Games ([newsroom](https://www.apple.com/newsroom/2024/06/apple-announces-winners-of-the-2024-apple-design-awards)). *Lesson:* collecting and handling objects is delightful in itself, and Artifacts already has the objects.

### 1.5 Choosing fast
- **Pie menus** select about 15% faster than linear menus, with fewer errors ([Callahan, Hopkins, Weiser & Shneiderman, CHI 1988](https://sites.umiacs.umd.edu/node/16962); [Wikipedia](https://en.wikipedia.org/wiki/Pie_menu)).
- **Marking menus.** Beginners wait and see the menu; experts flick in the remembered direction without it, and people move freely between the two ([Kurtenbach & Buxton, CHI 1994](https://billbuxton.com/MMUserLearn.html); [limits of expert performance](https://research.autodesk.com/app/uploads/2023/03/the-limits-of-expert.pdf_recyw5wL6ekPqcE4Q.pdf)). *Lesson:* the hand of blanks is a half-pie menu around the thumb, with fixed positions so the flick becomes muscle memory.

### 1.6 Gestures need signifiers
- Norman and Nielsen, [Gestural Interfaces: A Step Backward in Usability](https://jnd.org/gestural-interfaces-a-step-backwards-in-usability/), argue that touch UIs hide what you can do. A study found that spatial signifiers such as drag handles and drop shadows teach dragging better than temporal ones ([Springer](https://link.springer.com/10.1007/978-3-030-06134-0_23)). *Lesson:* every gesture here has something visible to grab: the drawer pull, the chevron on the pill, the dashed reticle, the index tabs. Each also has a tap path.

### 1.7 Physical metaphors we leaned on
- **The library card catalogue.** Drawers of 3×5 cards were held on a lock-guard rod, with slide-out trays to rest a drawer while you used it ([Smithsonian Libraries](https://blog.library.si.edu/blog/2021/01/21/the-staple-of-libraries-past), [Library Bureau cabinet](https://www.si.edu/object/nmah_1247621), [rod mechanism](https://kclibrary.org/news/2024-08/missouri-valley-room-holds-unique-piece-library-history)). This gives us the cabinet, the drawer you pull onto a tray, and cards on end with tabs.
- **The Rolodex.** A rotary card file patented in 1956 ([Wikipedia](https://en.wikipedia.org/wiki/Rolodex), [Cooper Hewitt](https://www.cooperhewitt.org/2014/04/15/the-power-of-the-rolodex/)). This gives us flipping card by card with a click at each detent.
- **Record crates.** Digging Into Hip Hop's "3D crate digging engine" ([FACT](https://factmag.com/2016/03/21/digging-into-hip-hop-virtual-crate-digging-experience)), Cratedigger, where you flip a sleeve over to read its tracklist ([Digital Trends](https://www.digitaltrends.com/music/flip-through-youtube-record-collection-cratedigger-fm/)), and [risq/cratedigger](https://github.com/risq/cratedigger). This gives us thumbing, pulling one out, and turning it over.
- **The masala dabba.** A round tin of seven katoris ([Food Network](https://www.foodnetwork.com/how-to/packages/food-network-essentials/how-to-use-masala-dabba)). Considered for quick-log and parked (§11).

### 1.8 What the competitors teach
- **Beli** ranks by asking "which did you prefer", with skip and "too tough" options. Critics dislike comparing unlike places and find the skip options unclear ([Pratt critique](https://ixd.prattsi.org/2022/02/design-critique-beli-ios-app/), [App Store](https://apps.apple.com/us/app/beli/id1478375386)). In our duel you only compare within one drawer, "Too close to call" is a first-class button, and repeat visits skip the duel.
- **Letterboxd.** The poster grid is its identity, alongside the diary and four favourites ([FAQ](https://letterboxd.com/about/faq/), [design notes](https://blakecrosley.com/guides/design/letterboxd)). Our Ticket box spread follows it.
- **Been.** Reviewers ask to tap countries on the globe instead of scrolling a list, and to zoom ([App Store](https://apps.apple.com/us/app/680148327)). Spin & stamp answers both, and the list becomes strips.
- **Mapsake** is a local-first atlas with a satellite globe and On This Day ([App Store](https://apps.apple.com/app/id6775122085)). It is map-only, and nobody combines that with taste and ranking.

### 1.9 The SwiftUI / iOS 26 toolkit

| API | Used for | Source |
|---|---|---|
| `ScrollView` + `scrollTargetLayout` + `.scrollTargetBehavior(.viewAligned)` + `scrollPosition(id:)` | Riffle snapping, card by card | [WWDC23 Beyond scroll views](https://developer.apple.com/videos/play/wwdc2023/10159), [docs](https://developer.apple.com/documentation/swiftui/viewalignedscrolltargetbehavior), forum notes on [centring](https://developer.apple.com/forums/thread/737830) and [`contentMargins`](https://developer.apple.com/forums/thread/750926) |
| `visualEffect { content, proxy in … }` | Per-card 3D transforms from scroll position, without layout cost | [docs](https://developer.apple.com/documentation/swiftui/view/visualeffect(_:)), [WWDC24 10151](https://developer.apple.com/videos/play/wwdc2024/10151/) |
| `scrollTransition` | Simple phase-driven effects (fades, captions) | [WWDC24 10151](https://developer.apple.com/videos/play/wwdc2024/10151/) |
| `onScrollPhaseChange` | Noticing "settled" so the drawer can ease ajar | [docs](https://developer.apple.com/documentation/swiftui/view/onscrollphasechange(_:)); it [doesn't fire on `List`](https://developer.apple.com/forums/thread/758922) |
| `matchedTransitionSource` + `navigationTransition(.zoom)` | Drawer front → riffle, card → item detail. Continuously interactive | [WWDC24 10145](https://developer.apple.com/videos/play/wwdc2024/10145/); reported issues: [source vanishes after swipe-back](https://developer.apple.com/forums/thread/807715), [grid glitches](https://developer.apple.com/forums/thread/810944), [medium-detent sheet](https://developer.apple.com/forums/thread/788257) |
| `DragGesture` (velocity), `MagnifyGesture`, `UIGestureRecognizerRepresentable` (iOS 18) | Axis-locked pull, pinch, the pill's long-press-and-slide | [WWDC24 10118](https://developer.apple.com/videos/play/wwdc2024/10118/), [Swift with Majid](https://swiftwithmajid.com/2024/12/17/introducing-uigesturerecognizerrepresentable-protocol-in-swiftui/), [iOS 18 gestures blocking scroll](https://developer.apple.com/forums/thread/760035) |
| `KeyframeAnimator` / `PhaseAnimator` | Thunk, rubber stamp, wax seal (existing `Motion.thunk`) | CONCEPT §7 |
| `.layerEffect(ShaderLibrary…)` | Ink bloom from the stamp's impact point. Same pattern as Apple's ripple shader, driven by keyframes | [WWDC24 10151](https://developer.apple.com/videos/play/wwdc2024/10151/) |
| `glassEffect`, `GlassEffectContainer`, `glassEffectID` | Pill → sheet chrome morph (chrome only; keepsakes stay paper) | [GlassEffectContainer](https://developer.apple.com/documentation/swiftui/glasseffectcontainer), [glassEffectID](https://developer.apple.com/documentation/swiftui/view/glasseffectid(_:in:)) |
| `sensoryFeedback`, Core Haptics | Detents, clunks, tear ticks, seal ramp | [SensoryFeedback](https://developer.apple.com/documentation/swiftui/sensoryfeedback), [WWDC21 Practice audio haptic design](https://developer.apple.com/videos/play/wwdc2021/10278) (causality, harmony, utility), [WWDC19 810](https://developer.apple.com/videos/play/wwdc2019/810) |
| `accessibilityRepresentation`, `accessibilityAdjustableAction`, custom actions | Non-spatial paths for every gesture | [adjustable action](https://developer.apple.com/documentation/swiftui/view/accessibilityadjustableaction(_:)), forum caveats on [carousels](https://developer.apple.com/forums/thread/781557) and [adjustable plus custom actions](https://developer.apple.com/forums/thread/726964) |
| Versor (quaternion) dragging + inertia | Globe rotation maths | [Observable](https://observablehq.com/notebook-kit/ex/d3/versor-dragging), [Bostock](https://gist.github.com/mbostock/7ea1dde508cec6d2d95306f92642bc42), [d3-inertia](https://gist.github.com/HarryStevens/8c9eba0905777a6ea778ebfc16f4d743) |
| HIG Motion, Reduced Motion criteria | Minimise motion without removing the motion that explains state | [HIG](https://developer.apple.com/design/human-interface-guidelines/motion), [App Store criteria](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/reduced-motion-evaluation-criteria) |

---

## 2. One grammar

| Verb | Gesture | Where | What you see | Haptic | Without the gesture |
|---|---|---|---|---|---|
| **Roll** | Swipe (horizontal on the cabinet, vertical in a drawer, any direction on the globe) | Cabinet, riffle, globe | The next one comes to the front | `detent` (`.selection`) per step | Tap a neighbour, the knob rail, the tab rail, or search |
| **Pull** | Drag the front drawer down | Cabinet | The drawer slides out; keepsakes rise | `detent` at the threshold, `clunk` on open | Tap the drawer |
| **Lift** | Tap the front card, or hold a drawer in the chest | Riffle, chest | The card lifts out; the drawer comes off the shelf | `lift` | VoiceOver actions |
| **Turn** | Tap a lifted card | Lifted card, lucky dip, Journal | Flips to the back (note, people, rank) | `lift` | Same tap; Reduce Motion crossfades |
| **Pinch** (fingers together) | Zoom out a level | Cabinet → chest, riffle → spread, globe → flat map | Everything at once | none (no haptic on a continuous gesture) | Glass buttons: *All drawers*, *Spread*, *Unroll* |
| **Draw** | Hold the pill, slide, release, or flick | Anywhere (the pill is always there) | A blank flies up and becomes your keepsake | `detent` per blank, `pick` on draw | Tap the pill: the same hand as a sheet |
| **Tear** | Swipe the printed blank sideways | Quick-log | The guess tears off; the next one prints | `tear` (six rigid ticks) | "Next guess" button and VoiceOver action |
| **Stamp** | Press the rubber stamp | Globe, flat map, continent strips | Ink floods the country; the stamp thunks into the passport | `stamp` (heavy) | Tap a stamp in a strip; search, then Return |
| **Seal** | Hold the ā for 0.6 s | End of every log | Ink rises; the wax ā thunks | `seal` ramp, then transient | A tap once learned; VoiceOver "Savour" (exists) |
| **Spin** | Flick the cabinet hard | Cabinet | It spins, clicks slower, lands; a keepsake rises face down | decelerating `detent`, `clunk` on landing | *Lucky dip* button |

Four rules hold everywhere. Every gesture is interruptible mid-flight. Every gesture has a visible handle. Every gesture has a non-gesture path. Pinch only ever means "show me everything".

---

## 3. (a) The turning cabinet and the chest

```
  Your cabinet                         The whole chest            [Done]
  8 drawers · 34 keepsakes             Tap one to turn to it · hold one to carry it
        ┌─receipt─┐                     ┌────────┐  ┌────────┐
     ┌──┤ No. 1   ├──┐ ← best three     │ Cafés  │  │Restaur.│  ← keepsake tops
  ╱│ ╲│ └─────────┘ │ ╱│   rise when     │ 7·No.1 │  │ 5·No.1 │    peek out
 ╱ │ ┌┴─────────────┴┐ │   it's ajar     ├────────┤  ├────────┤
│ R│ │ [ ☕ Cafés ]  │ │C│ ← neighbours  │Countrie│  │ Cities │
│ e│ │     ◡ pull    │ │o│   roll away   └────────┘  └────────┘
│ s│ │ 7 No.1 Prufrock│ │u│                    …
 ╲ │ └───────────────┘ │╱               ┌ Storeroom ─ drop here to put away ┐
  ╲│   ● ○ ○ ○ ○ ○    │╱  ← knob rail   │ [Wines · Take out]                │
     [⊞ All drawers] [⚄ Lucky dip]      └───────────────────────────────────┘
     Swipe to turn · pull a drawer down to open it
  ( ā  Savour something            ⌃ )
```

### Choreography
1. **Arrive.** The last drawer you used is in front, ajar. Its top three keepsakes stand up out of it: rank order for ranked collections, most recent for logs, best relish for stars, newest stamps for Countries. The drawer front carries the collection's label card, a cup pull, and the serif stat with its saffron macron (`DrawerSummary`, unchanged: never a bare "0").
2. **Roll.** A horizontal drag turns the column 1:1, at 170 pt per drawer. The drawer in focus is drawn bigger than its neighbours, about 78% of the screen width (×1.18 on an iPhone SE, ×1.26 on a 402 pt iPhone, at most ×1.45), and the extra size passes to the next drawer as it rolls in, so about 40 pt of each neighbour still peeks in (#190, chosen over a vertical cabinet because pull-to-open is vertical). Reduce Motion keeps every drawer the same size. Drawers sit on a closed polygonal drum: 360°/n, at least 45° apart, so with 8 collections plus the blank, neighbours peek about 70 pt in from each edge. The focused drawer closes as soon as you start turning, as you would before spinning a real cabinet. On release, the projected end point (WWDC18: velocity × ~0.2 s, capped at ±3 drawers) snaps to the nearest drawer with `roll`. Each drawer that passes the centre gives one `detent` click, and the knob rail updates.
3. **Settle.** When the roll stops, the front drawer eases ajar after 80 ms. Its keepsakes rise with `settle`, 0, 50 and 90 ms apart. That is the savouring beat.
4. **Pull.** A downward drag on the front drawer only counts as a pull once it is more vertical than horizontal after 9–10 pt of travel. The drawer then slides toward you, growing slightly, with its keepsakes rising further. Travel is rubber-banded: `(1 − 1/(x·0.75/300 + 1))·300`. Past 78 pt, or above 650 pt/s, it clunks open and zooms into the riffle (§4). Short of that, it springs back with `pull`. A tap opens it too. The first time the cabinet settles, the drawer bobs down 26 pt once as a hint (WWDC18 "hinting").
5. **Chest.** Pinching fingers together scrubs a continuous morph from drum to chest. Releasing past halfway commits it with `morph`, otherwise it falls back. *All drawers* does the same. In the chest:
   - **Tap** a drawer to roll back to it.
   - **Hold** a drawer for 0.38 s to lift it. It follows your finger, and the others slide out of its way.
   - **Drop** it on the **storeroom** shelf docked above the pill to hide it. Tap *Take out* to bring it back. This is today's hide and unhide, with a place to put things.
   - The **blank drawer** at the end ("a blank tag for anything") opens the collection editor.
6. **Interrupt anything.** Touching a moving drum catches it. A new swipe retargets the spring, keeping its velocity (WWDC23).

### Motion and haptics
- New motion tokens: `roll` = `.spring(duration: 0.42, bounce: 0.12)`; `pull` = `.spring(duration: 0.36, bounce: 0.2)`; `morph` = `.spring(duration: 0.5, bounce: 0.06)`.
- Reused: `ajar` uses `Motion.settle`, with a 50 ms stagger.
- New haptics: `detent` (`.selection`, throttled to at least 30 ms apart), `clunk` (`.impact(flexibility: .solid, intensity: 0.8)`) and `lift` (`.impact(weight: .light)`).
- Sound (#122, extended): a soft wooden click per detent and a drawer *shff*.

### SwiftUI approach
- **`CabinetDrum`** is a plain value type: position, velocity, `release(velocity:)` (projected target), `step(dt:)` returning detent crossings, and `spin(to:)`. It's unit-tested like `Ranking`. The view draws at most five drawers.
- **`DrawerGeometry(index, position, chestProgress) → transform`** produces the offset, `rotation3DEffect` (y axis, `perspective ≈ 0.5`), scale, `zIndex` and shade. An `Animatable` modifier lets springs interpolate *position* and *progress*, not just end states. That gives a pinch that scrubs and a spring that finishes it, with matched positions and no cross-container `matchedGeometryEffect`.
- **Tracking.** A `DragGesture` drives position while tracking. A `TimelineView(.animation(paused: !drum.isMoving))` integrates free motion and the spin, so it costs nothing when idle.
- **Ajar** is a `@State ajarID`, set when the physics settles. The minis animate their offset with `Motion.settle.delay(Motion.staggerDelay(i))`.
- **Gesture arbitration.** The pull needs axis-locking against the horizontal roll, so use a `UIPanGestureRecognizer` via `UIGestureRecognizerRepresentable`, with `gestureRecognizerShouldBegin` checking `|vy| > |vx|`. Pinch is a `MagnifyGesture` attached simultaneously.
- **Open.** `matchedTransitionSource(id: collection.id)` on the drawer front, and `navigationTransition(.zoom(sourceID:in:))` on the drawer view. The transition is continuously interactive, so dragging down pushes the drawer back in.
- **Reuse.**
  - Today's two-column `Grid` from #113 becomes the chest's layout reference.
  - Reorder keeps `CabinetOrder.destination` and `Repository.reorder`; hide keeps `Repository.setHidden`.
  - The VoiceOver "Move earlier/later" actions stay.
  - `MiniKeepsake` and `GhostSlip` remain the tray contents.
- **Alternative.** A horizontal `ScrollView` with `.viewAligned` and a cylinder transform in `visualEffect` gives native momentum and accessibility for free. It loses wrap-around and the physical spin. The spike (§10) decides; see open question 1.

### Accessibility and fallbacks
- **VoiceOver** never meets the 3D drum. `accessibilityRepresentation` swaps in a plain ordered list of drawer elements, e.g. "Cafés drawer. 7 ranked, number one Prufrock Coffee". Each drawer has actions: Open, Move earlier, Move later, Put away, Share. A "Drawers" rotor is included. Drawers have no inner controls, so the forum caveat about adjustable carousels doesn't apply.
- **Switch Control and Voice Control.** The knob rail is a row of real buttons ("Turn to Films"), and *All drawers* and *Lucky dip* are standard buttons.
- **Reduce Motion.** The drum is drawn flat: no perspective, neighbours at the edges, crossfade between drawers. Ajar is static (keepsakes simply visible). There's no hint bob, and spin becomes a crossfade.
- **Dynamic Type.** The label and stat scale. From AX1 the drawer grows taller and the neighbours hide. From AX3 the chest becomes the default, in a single column of drawer fronts (still furniture, not a CRUD list).
- **One hand.** Roll and pull happen in the middle third of the screen; the chips and pill are in the thumb zone.

### Risks
- **Gesture conflicts.** Roll vs pull vs pinch vs tab-bar swipes. Mitigated by UIKit recognisers with explicit rules, plus the hysteresis threshold.
- **Pull discoverability.** Mitigated by the cup pull (a spatial signifier), the one-time bob, the TipKit tip "Pull a drawer toward you", and a tap working too.
- **Zoom transition glitches** (see the forums). Fall back to a custom overlay with `matchedGeometryEffect`.

---

## 4. (b) Inside a drawer: the riffle and the spreads

```
  ‹ Shut        ● Restaurants        [⊞ Spread]
                The Menu · by duels
      Thumb down to flip · tap the front one to lift it out
              ┌No. 5┐
          ┌No. 4┐──────────────┐          No. 1 ·¯
        ┌─────────┌No. 3┐──────┤          No. 2      ← jump rail
        │  ┌No. 2┐──────────────┤        No. 3
       ┌¯¯¯¯¯┐──────────────────┐         No. 4
       │No. 1│ BOMBAY CAFÉ      │         No. 5
       │     │   Dishoom        │
       │  House black daal …    │
  ┌────┴──── No. 1 ¯¯¯ 02·10·26 ┴──────────┐
  │ [🍴 Restaurants]    ◡        5          │ ← the drawer front you pulled
  └──────────────────────────────── No.1 Dishoom┘
```

### Choreography
1. The drawer front lands at the bottom of the screen (the zoom transition). The keepsakes rise out of it one after another, each standing on end behind the last.
2. **Thumb down** to flip forward. The front card falls toward you around its bottom edge (rotateX to about −86°) and disappears behind the drawer front. Each card crossing the lip clicks (`detent`), with an occasional paper *shff*. Drag 62 pt per card; a fling projects about 0.18 s of velocity and the snap uses `riffle` (`.spring(duration: 0.32, bounce: 0.08)`). Thumb up to flip back. Both ends rubber-band.
3. **Tabs show the order.** Cards behind the front one step up 36 pt each, so their **index tabs** show. Tab positions follow a ⅓-cut pattern, so the stack reads like a real catalogue drawer.
   - **Ranked:** front-to-back is No. 1 → No. n, each tab reads "No. n", and the front tab carries the saffron macron.
   - **Log** (films, flights): newest first, with plum-wash **guide cards** for each year ("2025 · 3 in this year") and ×n on rewatched stubs.
   - **Stars / custom:** grouped by relish ("Unforgettable · Lisbon").
   - **Checklist:** passport pages, newest stamp first.
4. **Jump.** Tap any tab, or scrub the right-hand rail (No. 1 … No. 7 / years / initials), and the stack springs there.
5. **Lift.** Tap the front card. It lifts out (scale 1.08, the scrim dims), and tapping again turns it over: your note in serif italic, the date, who you were with, "Savoured ×4", and the rank with *Re-duel*. In the app this lift is the zoom into **Item detail (#34)**, with the keepsake as its hero.
6. **Spread.** Pinch, or tap *Spread*, to tip the drawer onto the table. Cards fly to the mode's overview, which is exactly #44's four views, reframed:
   - **The Menu** (ranked): a printed list best-first, with No. 1 as the hero. Manual re-ordering (#41's drag) lives here.
   - **Ticket box** (log): stubs and passes by year.
   - **Passport** (checklist): pages of stamps.
   - **Pinboard** (stars/custom): tilted keepsakes in a loose grid.

   Tap any card to go back to the riffle at that card.
7. **Shut.** *Shut*, a tap on the drawer front, or a swipe down on it pushes the drawer back into the cabinet with a `clunk`. You land on the cabinet with that drawer ajar.
8. **An empty drawer** shows a ghost card: "Nothing savoured yet. Hold *Savour something* to draw your first."

### SwiftUI approach
- **The scroll view.** A vertical `ScrollView` with a `LazyVStack(spacing: −overlap)` and `.scrollTargetLayout()`, plus `.scrollTargetBehavior(.viewAligned(limitBehavior: .never))` so flings travel several cards, and `.scrollPosition(id: $frontID, anchor: .bottom)`. That gives native momentum, rubber-banding, laziness for 1,000 films, and VoiceOver reading the cards in order, all for free.
- **The 3D look.** Each card uses `.visualEffect { content, proxy in … }` to read its distance *d* from the lip via `proxy.frame(in: .scrollView)`. It applies `rotation3DEffect(.degrees(d < 0 ? −86·min(1, −d) : 0), axis: (1, 0, 0), anchor: .bottom, perspective: 0.6)`, an offset of `−36·d`, scale `1 − 0.012·d` and opacity. This is pure maths with no state writes per frame, which is what WWDC24 recommends.
- **Haptics:** `.sensoryFeedback(.selection, trigger: frontID)`, behind a small throttle so a fling doesn't buzz.
- **Tabs:** `.overlay(alignment: .topLeading)` offset by `index % 3` thirds. The front tab gets the `MacronBar`.
- **Hit-testing:** only the front card and the tabs are tappable (`allowsHitTesting(isFront)`).
- **Spread:** swap to the overview layout with `matchedGeometryEffect` per card id. The pinch uses a `MagnifyGesture` with a 0.5 threshold.

### Accessibility and fallbacks
- **VoiceOver** reads front to back, e.g. "No. 1, Dishoom, Bombay café, savoured 2 October". Guide cards are headers, available on the headings rotor. Each card has custom actions: Lift out, Re-duel (ranked), Share. The rail is an adjustable element.
- **Reduce Motion:** no rotateX. Cards sit as a short overlapping stack and slide and crossfade by one. The spread crossfades.
- **Dynamic Type:** card heights grow and the overlap shrinks. From AX3 the drawer opens straight into its spread; The Menu is already a readable list.
- **One hand:** the thumb drags in the lower half; the rail sits on the right edge (mirrored for left-handed use via `layoutDirection`).

### Risks
- `viewAligned` snapping with negative spacing, and `scrollPosition` quirks. Mitigate with a fixed card pitch, and fall back to a custom pager if the spike finds problems.
- Overlapped hit areas: handled by the front-only hit-testing above.
- `onScrollPhaseChange` doesn't fire for `List`. We use `ScrollView`.

---

## 5. (c) Draw a keepsake: the hand, the print head, the seal

```
                     Cafés
         release to draw · near you
        ┌──┐ ┌──┐ ┌──┐ ┌──┐ ┌──┐ ┌──┐
     ┌──┐╲  │ │▣ │ │⬡ │ │✉ │ │▥ │ ╱┌──┐   ← one blank per drawer, always in
     │🧾│  ╲ └──┘ └──┘ └──┘ └──┘ ╱  │🏷 │     the same place (cabinet order)
     └──┘   ╲                 ╱    └──┘
              ╲     thumb     ╱
       ( ā  Savour something          ⌃ )
```

### Choreography
1. **Hold** the pill for 170 ms, or start sliding up (more than 8 pt). Up to eight blank keepsakes fan out in an arc over your thumb: radius 200 pt, ±56°, deployed from the centre outwards 18 ms apart with `fan` (`.spring(duration: 0.34, bounce: 0.3)`). Each blank is drawn in its collection's ink: receipt, menu, stamp, postcard, pass, stub, tag.
2. **Slide.** The blank under your thumb's *angle* lifts 20 pt outward and grows to 1.14×, with one `detent` click per change. A label names it and says where the first guess will come from ("Cafés · release to draw · near you"). There is a 46 pt dead zone at the pill. Sliding back below the pill cancels.
3. **Let go** on a blank to draw it (`pick`). It flies up and becomes the keepsake at the top of the quick-log sheet; the rest fold back into the pill.
4. **Flick (expert).** Touch down and flick in a remembered direction. If you let go within 90 ms the hand never draws, but the right blank is drawn: a marking menu. Positions never change (cabinet order); a context guess makes a blank glow, it doesn't move it.
5. **Tap.** The sheet opens with the same hand laid flat across the top, plus **Again?** chips for the most recent things ("Monmouth Coffee again?"), which skip straight to sealing.
6. **The print head.** The drawn blank immediately *prints* its best guess, 20 ms per character with a faint typewriter tick. "1 of 3" shows where the guess came from:
   - **Near you:** MapKit POIs within about 50 m, when location is allowed.
   - **Again?:** the last few items in this drawer.
   - **Now showing:** TMDB, for films.
   - **You're in:** for countries, from the offline lookup (#29).
   - Photo-based guesses arrive with E11 (M4).
7. **Tear** the printed blank sideways (90 pt or 650 pt/s). It tears off along its edge with six rigid ticks (`tear`) and the next guess prints. Swipe the other way to bring a guess back. Or **type**: results print onto the blank as you go. The keyboard only opens automatically when there is nothing to guess.
8. **Savour**, depending on the mode:
   - **Ranked and new:** the duel. "Which did you savour more?", at most ⌈log₂(n+1)⌉ picks, with saffron macron steps and *Too close to call*. The result thunks *No. n* onto the keepsake.
   - **Ranked repeat:** "Still No. 2?" and skip ahead.
   - **Stars:** drag across five ā marks; each step clicks and prints the relish word on the card.
   - **Log:** When? Today / Yesterday / Last week, and "That makes it ×3".
   - **Checklist:** *Stamp*. The rubber stamp thunks onto the passport page.
9. **Seal.** An optional serif "note to your future self", then hold the ā for 0.6 s (the existing `SealButton`). The wax ā thunks, the keepsake flies into its drawer, and a toast says "Savoured in 6.4 s · it's in your Cafés drawer". If you're on Collections, the cabinet rolls to that drawer and the new keepsake rises on top.

**Timing budget.** Each row is a separate example, not cumulative.

| Path | Steps | Time |
|---|---|---|
| Repeat café visit | Hold and slide 0.8 s · print 0.3 s · "That's it" 1.0 s · seal 0.6 s, plus 0.6 s of landing | **≈ 3.5–6 s** |
| New café near you | As above, plus three duel picks ≈ 3 s | **≈ 7–9 s** |
| A film by search | Draw 0.8 s · type 4 letters ≈ 3 s · relish 1.5 s · seal | **≈ 8–11 s** |
| Prototype run (country) | Measured in headless Chrome | **7.3 s** |

All of these sit under the 15 s acceptance criterion in #31.

### SwiftUI approach
- **The gesture.** The pill lives in `tabViewBottomAccessory` (`AppShellView`), but the hand has to draw over the whole screen. The pill feeds a root overlay on `AppShellView` through a `UILongPressGestureRecognizer(minimumPressDuration: 0.15)` with unlimited `allowableMovement`, via `UIGestureRecognizerRepresentable`. That gives continuous locations in window space, even once the finger leaves the accessory. The fallback is `DragGesture(minimumDistance: 0, coordinateSpace: .global)` plus a timer.
- **Layout.** A `HandLayout` (custom `Layout`) places N blanks on an arc. Selection = `atan2(dx, −dy)` → nearest angle.
- **Haptics:** `.selection` on change, `pick` on draw.
- **The sheet.** `matchedGeometryEffect` can't cross a `.sheet` boundary, so present quick-log either as a `fullScreenCover` with `navigationTransition(.zoom)` from the pill (zoom works with sheets and full-screen covers, per WWDC24 10145), or as an in-shell overlay. The pill's glass morphs into the sheet chrome with `glassEffectID`. The keepsake itself stays paper.
- **The print head.**
  - The typewriter reveal: a `TextRenderer` per-glyph reveal (WWDC24 shows the technique), or the simpler `.contentTransition(.interpolate)`.
  - The guesses come from #24 place search, #28 TMDB, #26 the airline list, #29 the offline country lookup, and recents.
  - The tear gesture and its ticks are the same component #121 needs for tearing film stubs.
- **Quick-log scaffolding.** `QuickLogSheet.swift`'s `List` is replaced. The orchestration (savour step per mode, details, save, Journal landing) stays in #31.

### Accessibility and fallbacks
- **VoiceOver.** The pill is a button; double-tap opens the sheet, where the blanks are a two-column grid of buttons ("Savour a café"). The pill also offers custom actions on the actions rotor: "Savour a café", "Stamp a country"… Tear has *Next guess* and *Previous guess* actions, and the seal has *Savour* (exists).
- **Switch Control and Voice Control:** the tap path.
- **Reduce Motion.** The hand appears in place without the arc deployment, and draw, tear and print are crossfades. Timings stay the same, so the flow is no slower.
- **Dynamic Type.** Blank labels use `.caption2` on two lines. At AX sizes the pill's hold still works, but the sheet grid is the primary path.
- **One hand, either hand.** The arc is symmetric over the pill, and every target is in the bottom 60% of the screen.

### Risks
- **System behaviour.** The system may collapse the bottom accessory on scroll (`tabBarMinimizeBehavior`), or intercept long-presses. Spike it. The fallback (tap path only) is still far better than today.
- **Discoverability.** The ⌃ chevron on the pill, and a TipKit tip after the third tap-open: "Hold and slide up to draw".
- **Accidental draws.** The dead zone, the cancel zone below the pill, and Cancel on the sheet.

---

## 6. (d) Spin & stamp: countries

```
  Passport                     8 countries · 4% of the world ¯¯
  [ Find a country…                                      ]
  (Europe) (Asia) (Africa) (N. America) (S. America) (Oceania)
            .  ·  ●   ·    ·                         [⤢ Unroll]
        ·  ·  ● ·(◎)· ·  ·    ← dashed ring = where the stamp lands
          · ·  ·[France]·  ·
            ·  ·    ·  ·  ·                            ( 🗳 Stamp )
  Not yet stamped in Europe                         tap to stamp
  ┊SPAIN┊ ┊IRELAND┊ ┊NORWAY┊ ┊SWEDEN┊ ┊…┊   ← the 30-in-30 path
```

### Choreography (M2 globe; the M1 stamp pad is the same flow on the flat map)
1. **Spin** the ink globe with one finger, using versor (quaternion) dragging so it never gimbal-locks. On release it carries inertia (decay `e^(−2.4t)`) and the latitude is clamped to −65…75°. When it slows, a country centroid within 46 pt of the ring snaps magnetically into it.
2. **Aim.** The dashed **reticle** locks (turns solid) on the country beneath it, and its name shows on a glass label, with "· stamped 03·04·25" if you've been. Small countries resolve through the magnetic snap, plus disambiguation chips ("Luxembourg · Belgium · Netherlands").
3. **Stamp.** Press the rubber-stamp button. The stamp drops onto the ring: 1.4× → 1.0 with a squash, i.e. `Motion.thunk`. Then:
   - a heavy `stamp` haptic plays,
   - **ink blooms** out from the impact point over 0.9 s,
   - the country fills plum,
   - its passport stamp thunks into the strip below,
   - and the counter rolls with `.contentTransition(.numericText())`.

   Double-tapping a country also stamps it.
4. **Fast paths.**
   - **Type** three letters and the globe flies there (ease-in-out, 750 ms); Return stamps it.
   - **A continent chip** flies to that continent and deals a strip of **unstamped stamps** (dashed outlines). Tap, tap, tap. This replaces the flag grid in onboarding (#118 `StampStep`) and the A–Z list (#25 `CountryPicker`), which stays as the VoiceOver representation.
5. **Unroll.** Pinch, or tap *Unroll*: the globe morphs into the existing flat Robinson `InkWorldMap`, where you see everything and can tap to stamp. Pinch back to roll it up.
6. **Wash off.** Long-press a stamp in the passport to wash it off, with Undo.

### SwiftUI approach
- **M1 · stamp pad.** It builds on #117's `InkWorldMap` (Canvas, cached Robinson paths, `Path.contains` hit-test).
  - The rubber stamp is a draggable glass button over the map. While you drag it, a 2× **loupe** (`Canvas` re-drawing the cached paths, clipped to a circle) shows the countries under it; lift to stamp.
  - The ink bloom is a radial mask, or `.layerEffect` with a ~20-line Metal shader (WWDC24's ripple pattern, driven by `keyframeAnimator`).
  - The continent strips are a `LazyHStack` of `PassportStamp` outlines.
- **M2 · globe.**
  - Precompute each country's ring points as unit-sphere vectors once, from `InkWorld`'s catalogue.
  - Per frame: rotate (`simd_quatd`), orthographically project, clip at the horizon (great-circle clipping, as `d3.geoClipCircle` does), and fill the visible countries. Simplify further while moving.
  - Hit-test by inverse-projecting the touch to latitude/longitude, then reuse `InkWorld.code(atUnit:)` via the Robinson projection.
  - A `TimelineView(.animation(paused:))` runs only while spinning.
  - The unroll morph interpolates per-point between the orthographic and Robinson positions. The back hemisphere fades in.
  - *As built (#158, `Countries/Globe/`):*
    - Dragging pins the place under the finger exactly for a north-up camera, and falls back to a versor turn near the rim.
    - The horizon clip pushes hidden points out to the rim. A ring that holds the far side gets the rim added and is filled even-odd.
    - Outlines are thinned to 0.3° at rest (about 20k points) and to 1° while moving (about 9k).
    - The camera is a pure function of time (rest, coast `e^(−2.4t)`, or fly), so a `TimelineView` draws only while it moves.

### Accessibility and fallbacks
- **VoiceOver.** The globe stays one summarised element, as `InkWorldMap` is today ("World map, 8 countries inked: …"). The accessible path is search plus the continent strips (buttons with `.isSelected`), or the representation list from `CountryPicker`. There's a "Stamp" action.
- **Reduce Motion.** No inertia: the globe stops when your finger lifts, fly-to becomes a cut, and the bloom becomes a fade. The thunk scale is removed, but the heavy haptic is kept.
- **Dynamic Type:** the strips wrap to two rows and the labels scale.

### Risks
- Canvas cost at 120 fps with about 250 polygons on an A13. Spike it; fall back to Metal.
- Horizon clipping correctness at the poles and the antimeridian.
- Tiny countries, handled by the magnet plus the chips.
- Onboarding and the Passport drawer must stay consistent: same stamp pad, same strips.

---

## 7. (e) Lucky dip, anniversaries and shuffle

1. **Spin the cabinet.** Fling it faster than 2,300 pt/s, or tap *Lucky dip*. The drum turns two full revolutions plus an offset over 2.1 s, plus 18 ms per drawer passed. It uses an ease-out curve, `1 − (1−u)^3.2`, so the clicks slow down naturally, like a prize wheel. It lands with a `clunk`, the drawer eases ajar, and a **face-down keepsake** (aubergine back, cream ā, saffron macron) rises out of it with `settle`.
2. **Turn it over.** A tap flips it with `Motion.flip`: "Lisbon · savoured 14·09·24 · 'Tram 28 at dusk, pastéis still warm.'" Then *Again*, *Open drawer* (opens the riffle at that card) or *Put back*.
3. **What it picks.** It never picks an empty drawer, and never the same keepsake twice in a row. It favours anniversaries (2×), things not seen for 90 days, and keepsakes with a note or photo.
4. **Anniversary tab.** A drawer holding something from this day a year ago has that card **sticking up** on a saffron-macron tab, "A year ago today". It's visible in both the drum and the chest; tap it to pull the card out. The Journal keeps its face-down card (CONCEPT ⑥, #69).
5. **Shuffle (P2).** Long-press a drawer's lip: the stack riffle-shuffles and a random card comes to the front.

**SwiftUI.** With the custom drum, the spin is just `CabinetDrum.spin(to:)`. With a `ScrollView` drum it would be a programmatic `scrollPosition` over a tripled data source. The announcement uses `AccessibilityNotification.Announcement`.

**Fallbacks.** The *Lucky dip* button is always there. VoiceOver announces "From your Cities drawer: Lisbon, savoured 14 September 2024". Under Reduce Motion there's no spin; it crossfades straight to the face-down card.

---

## 8. Motion and haptics kit II

These extend `Motion.swift` and `Haptics.swift`. The existing tokens are unchanged and reused: `settle`, `thunk`, `flip`, `stagger`, `sealHold`, `crossfade`; `seal`, `stamp`, `pick`, `relishStep`, `done`.

| Token | Value | Used by |
|---|---|---|
| `Motion.roll` | `.spring(duration: 0.42, bounce: 0.12)` | Drum snap, riffle snap (`riffle`: 0.32 / 0.08) |
| `Motion.pull` | `.spring(duration: 0.36, bounce: 0.2)` | Drawer springing back |
| `Motion.morph` | `.spring(duration: 0.5, bounce: 0.06)` | Cabinet ↔ chest, riffle ↔ spread, globe ↔ flat map |
| `Motion.fan` | `.spring(duration: 0.34, bounce: 0.3)`, 18 ms stagger from the centre out | Hand of blanks |
| `Motion.spin(distance:)` | 2.1 s + 18 ms per step, ease `1 − (1−u)^3.2` | Lucky dip |
| `Motion.inkBloom` | 0.9 s ring, 0.5 s fill, ease-out | Stamp |
| `Motion.rubberBand(_:dimension:c:)` | `(1 − 1/(x·c/d + 1))·d`, c = 0.55–0.75 | Pull, riffle ends, chest scroll |
| `Motion.project(velocity:rate:)` | WWDC18 projection with the scroll view deceleration rate | Roll, riffle, globe release |
| `Haptic.detent` | `.selection`, throttled to at least 30 ms | Drum, riffle, hand, reticle lock |
| `Haptic.clunk` | `.impact(flexibility: .solid, intensity: 0.8)` | Drawer opens, shuts or lands; lucky dip landing |
| `Haptic.lift` | `.impact(weight: .light)` | Lift a card or carry a drawer |
| `Haptic.tear` | Core Haptics: six rigid transients 22 ms apart (falls back to `.impact(flexibility: .rigid, intensity: 0.5)`) | Print-head tear-off, film stub (#121) |

All of them follow WWDC21's three principles. *Causality:* every haptic is tied to a visible event. *Harmony:* the click matches the visual detent. *Utility:* no haptic on continuous pinches or scrolls.

---

## 9. Accessibility, Reduce Motion, Dynamic Type, one-handed (cross-cutting)

| Interaction | Visible signifier | Tap / non-gesture path | VoiceOver | Reduce Motion | Dynamic Type |
|---|---|---|---|---|---|
| Roll the cabinet | Neighbours peek; knob rail | Tap a neighbour or a knob | `accessibilityRepresentation` list, rotor | Flat, crossfade | AX1: one drawer; AX3: chest list |
| Pull a drawer | Cup pull; one-time bob | Tap the drawer | Action "Open" | Crossfade into the drawer | Bigger label and stat |
| Chest, carry, hide | *All drawers*; storeroom shelf | Buttons; the cabinet hold menu "Put away" (a hold in the chest carries) | Move earlier/later, Put away | No lift tilt | Single column |
| Riffle | Index tabs; rail | Tap a tab or the rail | Linear cards, headers, actions | Stack slides, no rotation | Overlap shrinks; AX3 opens the spread |
| Spread | *Spread* button | Same | Spread is a plain ordered list | Crossfade | Reflows |
| Draw a keepsake | ⌃ on the pill; hand labels | Tap the pill → grid | Pill actions "Savour a café"… | No arc animation | Sheet grid primary |
| Tear a guess | "Tear it off" line; "1 of 3" | Next / Previous buttons | Actions | Crossfade | Text wraps |
| Stamp | Reticle; Stamp button | Search + Return; strips | Strips, "Stamp" action | No inertia, fade bloom | Strips wrap |
| Seal | ā glyph and caption | Tap once learned | "Savour" action (exists) | Ink fill kept (state, not decoration) | Fixed 88 pt target |
| Lucky dip | Dice button | Button | Announcement | Crossfade | n/a |

The Reduce Motion rule from CONCEPT still stands: no tilt, no fly-to, crossfade, haptics kept. We also keep motion that *explains state* (the seal's ink fill, the stamp's colour change), which follows App Store Connect's advice that removing all animation can hurt understanding. Every interaction also works with **haptics off** (the visuals carry it) and **sound off** (#122's toggle, plus the silent switch via the `.ambient` session).

---

## 10. Feasibility, performance and risks

**Budget.** 120 fps on ProMotion (8.3 ms a frame) for the drum, riffle and hand. At least 60 fps on the oldest iPhone iOS 26 supports (A13 class). Nothing animates when idle.

**Performance moves.**
- **Rasterise.** Mini keepsakes (`ImageRenderer` into a cache keyed by item id and version) are used in the drum, chest and hand. Only the focused card is a live view.
- **Grain.** `KeepsakePaper`'s grain is currently a `Canvas` drawing about `w·h/90` dots per card, roughly 650 for a 290×200 keepsake. Swap it for the 128 px tiled grain image CONCEPT already specifies, so paper costs nothing under 3D transforms.
- **Pure transforms.** `visualEffect` closures and `DrawerGeometry` are pure maths, with no `@State` writes per frame.
- **Haptic throttling** in one `DetentHaptics` helper.

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Gesture arbitration (roll / pull / pinch / tab swipes; the pill inside `tabViewBottomAccessory`) | Medium | High | UIKit recognisers via `UIGestureRecognizerRepresentable` with explicit rules; 10 pt hysteresis; spike first |
| Discoverability of hold-to-draw and pull | Medium | Medium | Spatial signifiers, a one-time hint, TipKit, and a tap that does the same thing |
| Zoom transition glitches | Medium | Low | Custom overlay with `matchedGeometryEffect` |
| `viewAligned` with overlapped cards | Low–medium | Medium | Fixed pitch; custom pager fallback |
| Frame drops with many live keepsakes | Medium | Medium | Raster cache + grain tile (ticket); measure in the spike |
| Globe Canvas at 120 fps | Medium | Low (M2) | LOD while spinning; Metal fallback |
| Scope creep beyond M1 | Medium | Medium | Lean cut in §11 |
| VoiceOver users meeting 3D UI | Low | High | `accessibilityRepresentation` everywhere; a VoiceOver UI test per flow |

**Spike (2 pts, ADR-0004), first.** Build the drum (custom physics vs `ScrollView`), the riffle (`ScrollView` + `visualEffect`) and the pill's hold-and-slide inside the real `tabViewBottomAccessory`. Record:
- frame timings on an A13 and a ProMotion device,
- gesture conflicts,
- VoiceOver traversal,
- a decision on wrap-around.

---

## 11. What ships when

| | Tickets | Points |
|---|---|---|
| **M1 core (P0)** | Spike · Motion & haptics kit II · Turning cabinet · Chest · Draw a keepsake · Print head · Riffle | 22 new, with #31 down from 8 to 5 (−3) → **+19** |
| **M1 stretch (P1)** | Stamp pad (flat map, strips, loupe) · Keepsake raster cache | **+5** |
| **M2** | Spin & stamp: the ink globe | **+5** |
| **M4** | Lucky dip (+ anniversary tab with #69) | **+2** |
| **P2 tweaks** | #121 tear stub −1 (tear built by the print head) · #122 sound pack +1 (drawer, riffle, stamp sounds) | **0** |
| **Net** | | **+31** (M1 +24) |

**Lean option**, if M1 must grow by at most about one sprint: ship the M1 core (+19) and move the stamp pad and raster cache to the start of M2. The flat-map onboarding (#118) works without them.

Existing tickets that change (applied in `backlog/backlog.yaml`). The main ones:
- #113's grid becomes the chest.
- #31 is reduced to orchestration.
- #44 becomes the drawer spreads.
- #38's Passport uses the stamp pad.
- #34's item detail is reached by lifting out of the riffle.
- #69 adds the anniversary tab.
- #74 gains a gesture audit.

---

## 12. Ideas considered and parked

- **The masala dabba quick-log.** A round spice tin whose seven katoris hold the blanks: lift the lid and pick a bowl. It's lovely, and rooted in the brinjal-and-saffron palette, but the spice metaphor strains for films and flights, and CLAUDE.md warns against sounding single-domain. Better kept for the **Tasting Menu** year-in-review: "your year's spices".
- **A Tinder-style swipe deck for your own keepsakes.** Swiping a memory left reads as rejecting it. Tear-off is reserved for *suggestions*.
- **Shake for a lucky dip.** It collides with Shake to Undo, fires by accident, and isn't accessible.
- **A RealityKit or SceneKit 3D globe.** That's a whole 3D engine for one screen. A Canvas globe keeps the ink look and the bundled polygons.
- **A three-column chest.** The labels become too small. Two columns plus a scroll and the docked storeroom work better.

---

## 13. Decisions (owner, 24 Nov 2026)

The owner approved the concept as proposed, so each open question takes the recommended answer:

1. **The cabinet wraps around** (a revolving column, which the spin needs). The spike (ADR-0004) still measures it; if wrapping can't hold frame rate, hard ends are the fallback.
2. **The turning cabinet is the default Collections view**, remembering the last drawer; the chest is one pinch away. At AX3 and above the chest is the default.
3. **The hand of blanks keeps a fixed order** (cabinet order, for muscle memory), with a glow on the likely guess.
4. **On the savour pill, hold draws from the hand and tap opens the sheet.**
5. **The globe comes in M2.** M1 onboarding keeps the flat ink map, with the stamp pad and continent strips.
6. **Lucky dip never surfaces keepsakes rated *Forgettable*** by default.
7. **Sounds stay on by default** (as CONCEPT says), ambient and silenced by the ring switch; the new drawer, detent, riffle and stamp sounds join the sound pack (#122).
8. **Full plan, not the lean option:** M1 grows by +24 points. The stamp pad and raster cache stay in M1 as P1 stretch items and slip to M2 first if M1 runs late.
9. **The Countries drawer** is a passport in the spread view and a riffle of pages in the focus view.
10. **No separate Arrange mode:** hold-to-carry, a Done button and the VoiceOver move actions.

---

## Appendix · the prototype

`prototype/savour-by-hand.html` is self-contained: no libraries, about 140 KB. Open it in Safari on an iPhone or in any desktop browser (a side panel explains the gestures).

**What it covers**
- **Cabinet:** roll, ajar, pull to open, pinch or *All drawers* for the chest, hold to carry, storeroom.
- **Riffle:** thumb through, tabs, rail, lift and turn over, *Spread* / pinch into The Menu.
- **Quick-log:** hold the pill and slide or flick, tap for the sheet, the print head with tear-off and search, then a duel, relish, when-chips or stamp, then hold the ā; the stopwatch shows the time.
- **Lucky dip:** fling or *Lucky dip*, and the anniversary tab on Films.
- **Atlas:** spin the globe, reticle, Stamp, search fly-to, continent strips, Unroll.
- **Journal:** the year-ago flip card and new keepsakes landing.
- **Settings:** dark mode, plus toggles for Reduce Motion, sound, haptics and haptic rings.

**What it approximates**
- Keepsakes are CSS and SVG.
- The globe is one dot per country at approximate centroids; the app uses the bundled Natural Earth outlines.
- Haptics are WebAudio clicks, `navigator.vibrate` on Android, an `<input switch>` tick on iPhone Safari 18+ (best effort), and a ring at the touch point.
- Springs use Apple's duration/bounce → stiffness/damping conversion, so the tuning carries over to SwiftUI.

**Tested** in headless Chrome at 390×844 across all flows, in both light and dark, with Reduce Motion on and via the keyboard path, with no console errors.
