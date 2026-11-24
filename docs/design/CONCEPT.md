# Asvada — Design Concept: "Keepsakes"

*Product + visual design concept · 23 Nov 2026 · **approved by the owner**: Keepsakes direction, Aubergine & Saffron palette, full scope (epic E15).*
*How you browse and pick (cabinet, riffle, hand of blanks, stamp pad) is in `INTERACTION.md` (epic E16), which supersedes the gestures and list layouts sketched here where they differ.*

---

## 1. Diagnosis — why it reads as CRUD

- **Every screen has the same layout.** Timeline, Collections, Map and Settings all open with a black SF Pro large title on cream, then a list or an SF Symbol empty state. Nothing tells you this app is about *taste*. The empty Timeline (`11/launch.png`) is a grey history-clock icon with "Everything you log will appear here", which is about as generic as an empty state gets.
- **Collections are a settings list** (`19/collections.png`): six rows, each with a tinted icon tile, a name and a right-aligned **"0"**. A café and a country get the same row. The number zero is the most prominent piece of data.
- **Quick-log is a form picker** (`11/quick-log.png`). "What did you savour?" is a good line, but it's set as a nav-bar title above a plain table of seven categories. The word *savour* does nothing in the UI.
- **The verbs are database verbs.** "Log something", "Edit", "Hidden", counts. You *manage* data here, you don't *keep memories*.
- **The brand only shows up in the icon and the About page.** The bold serif ā on a solid field is strong, but inside the app there's no serif, no ā and almost no colour apart from saffron link text. About (`12/about.png`) is the only screen with any personality.
- **Nothing makes you want to share it.** No screen produces an object worth screenshotting.

---

## 2. The big idea

> **"Every café, meal, flight and film I've had becomes a little keepsake — a passport stamp, a ticket stub, a boarding pass — and I seal it with my ā. They all end up on a map of my life."**

**Concept name: Keepsakes.** Entries stop being rows and become **objects**, each shaped for its category. Saving one is a physical gesture: you press the ā seal. The rating modes become things those objects *do*: stamps get stamped, menus get ranked, tickets pile up.

### Three directions considered

| | **A. Tasting Notes** | **B. Keepsakes** ★ | **C. Living Atlas** |
|---|---|---|---|
| Metaphor | An editorial journal of tasting notes: handwriting, pull-quotes, paper | A cabinet of category-shaped artefacts: stamps, stubs, passes, menus, receipts | A map-first app where everything is a pin and home is the globe |
| Strength | Literary, calm, true to *āsvāda* | Instant visual variety (kills the CRUD look). Rating modes map naturally to artefact behaviours. Every object can be shared | A strong "wow" for travellers. Map collage front and centre |
| Weakness | Only works if people write, and most won't. Looks like Day One. Ranking doesn't fit | Needs about 7 templates (kept small, see §7) | Films and airlines have no place. CLAUDE.md warns against sounding travel-only. MapKit work lands in M2, so the wow comes late |
| USP strength | Medium | **High**: nobody else combines ranking and travel as physical keepsakes | Medium: Been, Mapsake and Pin Traveler already live here |

**Recommendation: B, Keepsakes.** It takes A's language of savouring (relish words, a "note to your future self" prompt) and makes C the **Atlas** tab, where the keepsakes become the map collage. Every category looks different, the ā gets a job to do, and the wow can ship in M1 rather than waiting for M2.

### The keepsake set

| Collection | Keepsake | What's printed on it | How the rating appears |
|---|---|---|---|
| Cafés | **Receipt**: narrow slip, zig-zag torn foot, a faint coffee ring | Name, district, date and time in mono, "SAVOURED ×4" | `No. 3` rank numeral |
| Restaurants | **Menu card**: deckled edge, centred serif | Name, cuisine, "dishes" taken from the note | `No. 1` with a saffron macron underline |
| Countries | **Passport stamp**: ink shape (round, rectangle, octagon or triangle, chosen by a hash of the ISO code), rotated ±8° | COUNTRY NAME · ENTRY · date | The stamp is the tick |
| Cities | **Postcard**: photo front, round postmark | City, country, date in the postmark | Relish word |
| Airlines | **Boarding pass**: two-part card, decorative barcode generated from the entry id | Big IATA code, optional FROM → TO, seat, date | Flight count ×n |
| Films | **Ticket stub**: perforated, ADMIT ONE | Title, year, poster thumbnail, date, seat | Relish word, or ×n rewatches |
| Custom | **Luggage tag**: eyelet and string, collection's accent ink | Item name, icon, custom fields | Whatever mode the collection uses |

---

## 3. Design language

**Mood:** *a well-kept cabinet at dusk.* Warm paper, plum ink, a flash of saffron. Tactile, a little playful, never twee. The content is paper (matte, with weight and texture); the chrome is glass. That contrast is the look.

### Colour — three options

| Role | **1. Aubergine & Saffron** ★ (light / dark) | 2. Lavender Ink (light / dark) | 3. Saffron-first + Plum (light / dark) |
|---|---|---|---|
| Background | `#FAF6F0` / `#15101A` | `#F8F5FA` / `#120E17` | `#FAF7F2` / `#141210` |
| Surface | `#FFFFFF` / `#1F1826` | `#FFFFFF` / `#1C1622` | `#FFFFFF` / `#1E1B18` |
| Raised | `#F1EAF0` / `#2B2233` | `#EEE8F3` / `#28202F` | `#F1ECE4` / `#2A2622` |
| Text | `#221530` / `#F4EEF6` | `#1E1426` / `#F2EDF6` | `#1F1B16` / `#F3EEE7` |
| Text 2 | `#5D4E68` / `#BBAFC4` | `#5A4E66` / `#B8ADC3` | `#5C554C` / `#B5ADA2` |
| Brand | Plum `#6B2D8C` / Lilac `#C9A3EC` | `#7A3FA0` / `#D3B0F2` | Saffron `#A8401C` / `#F08A5D` |
| Second | Saffron `#F2A93B` (fill) + `#8C4F00` (text) / `#F5B54A` | none | Plum `#6B2D8C` / `#C9A3EC` |
| Feel | Warm, culinary, Indian-rooted (brinjal and kesar), distinctive | Cool, calm, more "app-like"; loses the food warmth | Smallest change; purple feels bolted on, terracotta reads "food delivery" |

**Recommended: 1. Aubergine & Saffron.** Plum is the **ink**: rank numerals, seals, the visited-country fill, primary buttons. Saffron is the **spark**: the macron bar, highlights, the "No. 1" underline. Warm paper keeps the food warmth. A deep **aubergine field** (`#3A1748` → `#24102E`) is the hero surface for the icon, onboarding, share cards and the year-in-review cover.

*Contrast:* every text/background pair in §9 passes AA (4.5:1). Saffron fill `#F2A93B` is only 1.9:1 on paper, so it's **decorative only** (macron bars, glints). Never use it as text or as the only signal of state; use plum for meaningful progress.

### Typography (all Apple-bundled, no licensing)

- **New York** (`.serif`) carries the voice: display titles, hero numerals ("No. 1", "23 countries"), and *italic* for month mastheads, prompts and notes. Italic serif is the "savouring" voice.
- **SF Pro** for UI. **SF Pro Expanded** small caps (`.fontWidth(.expanded)`, tracking +1.5) for ticket labels: ADMIT ONE, GATE, ENTRY.
- **SF Mono** for codes and dates printed on artefacts: `BA 0117`, `LHR → HND`, `23·11·26`.
- **Kohinoor Devanagari** (ships with iOS) for आस्वाद on About and onboarding.

### Materials and Liquid Glass

- **Glass only on chrome:** the tab bar, the savour accessory, the ā seal button, toolbars, map controls and the duel's choice buttons. Tint it plum: `.glassEffect(.regular.tint(plum.opacity(0.25)).interactive())`.
- **Never put glass on keepsakes.** Keepsakes are paper: a `#FFFBF4` keepsake-paper fill, a subtle grain (one 128 px tile multiplied at 4%), a 3 pt radius (sharp next to the rounded glass), and a two-layer ink-tinted shadow.
- Each keepsake gets a deterministic tilt from its id (±2°). Things look *placed*, not laid out in rows.

### Iconography and illustration

- SF Symbols for UI. The artefacts are **drawn in code**, not illustrated: custom `Shape`s for notches, perforations, scallops and deckles, so there's no art budget and they scale with Dynamic Type.
- **Stamp style:** single-colour ink in the collection's accent, slightly uneven edge, 85% opacity, ink grain. Country stamps vary by shape and rotation so a passport page looks collected, not generated.

### How the serif-ā carries through

1. **The ā seal** is the save button. You press it to seal each keepsake, and a small plum wax ā stays in the keepsake's corner.
2. **The macron (¯) is the graphic device.** A short saffron bar marks "this one" everywhere: the No. 1 underline, progress bars (`MacronBar`), the current duel candidate, the active month in the Journal scrubber, the loading indicator (a macron sliding across).
3. **The relish scale uses ā glyphs** instead of stars. Five little ā marks, filled with plum.
4. **The app icon** is an aubergine field with a cream ā and a **saffron macron**. Light, dark and tinted variants come from Icon Composer layers, with the macron on its own floating layer so Liquid Glass gives it depth.

### Motion — "paper physics"

- Things have weight. Keepsakes **land and settle** (a spring with a touch of overshoot), stamps **thunk**, cards **flip**, tickets **tear**. Nothing slides in linearly.
- One hero animation per screen. Everything else is quiet.
- **Reduce Motion:** no tilt and no fly-to. Crossfade only, haptics kept.

### Haptics

- **Seal:** a Core Haptics ramp (continuous, intensity 0.2 → 0.8) ending in a sharp transient.
- **Stamp:** `.impact(weight: .heavy)`.
- **Duel pick:** `.impact(weight: .medium)`.
- **Relish steps:** `.selection`.
- **Completion:** `.success`.
- **Tearing a stub:** rigid light ticks, one per perforation.

### Sound (optional, on by default, `.ambient` session so the silent switch mutes it)

Three short sounds: paper *shff*, stamp *thock*, seal *press*. A toggle in Settings turns them off.

---

## 4. Signature moments

### ① Hold to Savour — the ā seal
- **What happens:** the last step of every log. A round glass button with a serif ā. You press and hold for **0.6 s**. Plum ink rises inside the ā, and the haptic ramps up with it. On release, a wax ā *thunks* onto the corner of the keepsake with a few ink flecks. Then the card lifts and flies into the Journal, landing with a tilt.
- **Animation:** an ink fill (a mask whose height follows hold progress), a `KeyframeAnimator` thunk (scale 1.18 → 0.97 → 1 over 280 ms), then a zoom transition to the Journal.
- **Haptic:** Core Haptics ramp, then a transient.
- **Accessibility:** a VoiceOver action "Savour". A plain tap also works after a tip (TipKit) explains the hold.
- **Why it's memorable:** logging becomes a ritual, not a Save button. It's the moment people describe to friends. Every sealed keepsake can be shared as an image.

### ② This or That? — the ranking duel (ranked collections)
- **What happens:** two receipts or menu cards face each other: the new place on top, the comparison place underneath, both with photos. A prompt in New York italic reads *"Which did you savour more?"* You tap a card or flick it up. The loser tilts away and the next challenger slides in. A row of saffron macron segments shows the ≤ log₂ n steps left. "Too close to call" and "Skip" are glass buttons.
- **Result:** a big **No. 3** stamps in, and the list behind re-flows with matched geometry, so you see your café slot into place.
- **Haptics:** medium impact per pick, heavy on the final stamp.
- **Why it's shareable:** "My top 5 cafés in Lisbon" exports as a printed menu card.

### ③ Stamp your passport (countries, and the onboarding wow)
- **What happens:** a passport spread that pages sideways. Above it, an **ink world map** drawn from the bundled Natural Earth polygons. Tap a country (search, a flag grid, or a continent chip). Its stamp *thunks* onto the page at a random angle while the country floods plum on the map, and the counter rolls up: "23 countries · 12% of the world".
- **Haptic:** heavy impact per stamp.
- **Why it's shareable:** the passport spread and the ink map export as a card on the aubergine field. People will post this.

### ④ Tear the stub (films) and board (flights)
- **Films:** instead of holding the seal, you **drag along the perforation** to tear the ticket. Rigid ticks fire at each notch, and the stub drops into the "ticket box" with a spin.
- **Flights:** codes appear with a **split-flap** roll (`contentTransition(.numericText())` on SF Mono) as you pick the airline.
- **Why:** each category has its own finishing gesture, so logging stays fun on the hundredth film.

### ⑤ The Atlas — map collage
- **Zoomed out:** visited countries are washed in plum ink with grain.
- **Mid zoom:** entries gather into **fanned keepsake stacks**: three photos at −6°, 0° and +6°, with a saffron count tag.
- **Zoomed in:** each entry is a **mini keepsake pin** (a stamp-shaped photo with an accent-ink ring).
- **After your first log in a new country:** the country's ink blooms in on your next visit to Atlas.
- **Why it's shareable:** a poster of a trip or year, framed on aubergine with the ā colophon.

### ⑥ From the cabinet — on this day, and a Tasting Menu of your year
- **On this day:** a **face-down keepsake** appears in the Journal. Tap it and it flips (`rotation3DEffect`) to show "A year ago, you savoured…".
- **Year in review:** a **degustation menu**. *Amuse-bouche:* first coffee of the year. *Entrée:* new countries. *Main:* best restaurant. *Dessert:* film of the year. *Digestif:* most-flown airline. It's set like a real printed menu on cream, with the ā seal at the foot.
- **Why:** it's a novel, culinary twist on "Wrapped" that only Asvada can do.

---

## 5. Screen by screen

**Navigation:** three tabs, **Journal · Collections · Atlas**, plus a `tabViewBottomAccessory` savour pill. Settings moves to an ā avatar button in the Journal toolbar.

### Journal (home) — populated
```
┌────────────────────────────────────┐
│ (ā)                         🔍      │  ā = settings / profile (glass)
│ November                            │  New York italic 34
│ 4 cafés · 1 country · 2 films ¯¯¯   │  summary + saffron macron
│  ┌──────────────────────────┐ ↻1.5° │
│  │ ░ RECEIPT ░░░░░░░░░░░░░░ │       │  Café keepsake (receipt)
│  │ MONMOUTH COFFEE   No. 2  │       │
│  │ Borough · 23·11·26 08:12 │       │
│  └/\/\/\/\/\/\/\/\/\/\/\/\/(ā)      │  torn foot + wax seal
│     ┌────────────────────────┐ ↺1°  │
│     │ ADMIT ONE ┆ Perfect Days│     │  Film stub
│     │ [poster]  ┆ ★ Lovely   │      │
│     └────────────────────────┘      │
│  ┌ ? ─────────────────────────┐     │  face-down "on this day"
│  │   A year ago today… tap   │      │
│  └────────────────────────────┘     │
├────────────────────────────────────┤
│ ( ā  Savour something · Near: Dishoom )│ glass accessory
│   Journal      Collections    Atlas │
└────────────────────────────────────┘
```
- **Components:** `MonthMasthead`, `KeepsakeCard`, `FlipCard`, `SavourAccessory`.
- **Layout:** a single column in a `LazyVStack`. A month scrubber on the right edge shows a macron for the current month.
- **Loading:** keepsake-shaped shimmer blanks (never a spinner).

### Journal — empty (first run after onboarding is skipped)
```
│ Your journal                         │
│  ┌ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┐         │  dashed keepsake outline,
│     your first keepsake               │  breathing at 1.0↔1.02
│  └ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┘         │
│  Start with something you loved:     │
│  [🛂 Stamp your countries · 30s]      │  each chip opens quick-log
│  [☕ Your favourite café]             │  pre-filled for that category
│  [🎟 The last film you saw]           │
```

### Collections — "the cabinet"
```
│ Collections                    Edit │
│ ┌──────────────┐ ┌──────────────┐   │  2-col drawers; each drawer
│ │ Cafés        │ │ Countries    │   │  shows its top 3 keepsakes
│ │ ▤▤▤ fanned   │ │ ◎▭⬡ stamps   │   │  fanned out of it
│ │ 27 · No.1 Ⓐ  │ │ 23 · 12% ¯¯¯ │   │  key stat in serif numerals
│ └──────────────┘ └──────────────┘   │
│ ┌──────────────┐ ┌──────────────┐   │
│ │ Films  🎟🎟   │ │ Airlines ✈▭  │   │
│ └──────────────┘ └──────────────┘   │
│  + New collection (a blank tag)      │
│  Hidden ▸                             │
```
- An empty drawer shows a single ghost keepsake of its type and the line "Nothing savoured yet", **never "0"**.
- Reorder and hide behave as they do today (`Edit` mode jiggles the drawers).

### Collection detail — ranked ("The Menu")
```
│ ‹  Cafés                  [This or that?]│
│      ── The Menu ──                       │  New York, centred
│  No. 1  ¯¯¯                               │  hero card with photo
│  ┌ Prufrock ─────────── [photo] ┐         │
│  No. 2  Monmouth ............ Borough    │  dotted leaders
│  No. 3  Kaffeine ............ Fitzrovia  │
│  No. 4  …                                │
│  Settle a tie (2) ›                       │  "too close" pairs
```
**Empty state:** "Your first café is automatically No. 1."

### Collection detail — checklist ("Passport")
```
│ ‹  Countries            23 · 12% ◔      │
│  [ ink world map, visited = plum ]       │  Canvas, pinch to zoom
│  Europe ¯¯¯¯¯¯¯____ 14/44                 │  MacronBar per continent
│  ┌──────── passport spread ────────┐     │  paged horizontally
│  │ (JAPAN)   [PORTUGAL]  ⬡ INDIA  │      │  rotated stamps
│  │  ⌗ faint outlines = not yet     │     │  toggle "show unvisited"
│  └─────────────────────────────────┘     │
```

### Collection detail — log ("Ticket box")
```
│ ‹  Films                  2026 ▾        │
│  [poster][poster][poster]  3-col grid    │  stub-shaped crops
│   ×3       ×1      ×2   rewatch tally    │
│  — 2025 —  (stacked stubs by year)       │
```

### Quick-log — four beats (target under 15 s)
1. **Pick.** The savour pill morphs (glass morph) into a sheet showing **seven blank keepsakes** in a 2×4 grid (receipt, menu, stamp, postcard, pass, stub, tag), plus a smart row above: *Near you · Recent*. Tapping a blank grows it to the top of the sheet.
2. **Find.** The search field is focused automatically (MapKit / TMDB / catalogue). As you pick a result, its details **print onto the blank** with a typewriter reveal, so you see your keepsake take shape.
3. **Savour.** The rating step depends on the mode:
   - ranked: inline This or That (≤ log₂ n cards)
   - stars: the `RelishScale`, which you drag across five ā marks (*Forgettable · Fine · Good · Lovely · Unforgettable*)
   - log: the date only
   - checklist: the stamp
   Below that, one optional line in serif italic: *"A note to your future self…"*, then 📷, 👥 and a collapsed **More** (date, tags, custom fields).
4. **Seal.** Hold the ā (or tear the stub for films). The keepsake flies to the Journal.
```
│ ◯ Cancel            Café             │
│  ┌──────────────────────────┐        │
│  │ MONMOUTH COFFEE          │ ←live  │
│  │ Borough · today 08:12    │ keepsake
│  └/\/\/\/\/\/\/\/\/\/\/\/\/┘         │
│  Which did you savour more?          │
│  [ Monmouth ]  vs  [ Prufrock ]      │
│  ¯¯ ¯¯ __ __                         │  steps left
│  A note to your future self…         │
│        ( ā )  hold to savour         │  glass seal button
```

### Item / Entry detail
- The hero is the large keepsake. It uses `navigationTransition(.zoom)` from the Journal card. **Tap to flip:** the back shows notes in serif italic, people, tags and custom fields.
- Below the card: "Savoured 4 times" as a horizontal ribbon of mini receipts, a photo strip, the rank badge (with a "Re-duel" link), and a mini map.
- Edit lives in the toolbar. Delete uses swipe with an undo toast.

### Atlas (map)
```
│ (filters)                    (◎)(⤢)  │  glass controls
│   [muted MapKit, paper-tinted]        │
│   ▒▒ plum-ink countries ▒▒            │  zoomed out
│      ⧉3  fanned stacks                │  mid zoom
│         ◉ mini keepsake pins          │  zoomed in
│ ┌ glass sheet (detent: peek) ───────┐ │
│ │ 23 countries · 112 places  Share ▸ │ │  poster export
│ └────────────────────────────────────┘ │
```
- **Empty:** the ink world map with no fills and the prompt "Stamp your first country", which opens the passport.
- **Loading:** the polygons draw in as outlines, then fill.

### Settings and About ("Colophon")
- Settings stays a standard grouped `Form`, which is fine, but it gets the paper background and serif section headers.
- About becomes a **Colophon** on the aubergine field: the big cream ā with its saffron macron, *āsvāda · आस्वाद*, the definition, "Set in New York & SF Pro", and a **privacy seal**: "Nothing leaves this phone except film lookups (TMDB), map tiles and, if you turn it on, your own iCloud."

---

## 6. Onboarding — a wow in under a minute

| Time | Screen |
|---|---|
| 0–5 s | Aubergine `MeshGradient` gently breathing. The saffron macron slides in, then the ā settles beneath it with a thunk. *"Savour what you've lived."* [Begin] |
| 5–35 s | **"Where have you been?"** The ink world map on top. Below it, continent chips, search and a flag grid. Every tap stamps and floods a country. The counter rolls up. No permissions needed. |
| 35–45 s | **"Your passport so far."** The stamps fall onto a spread in a staggered cascade: *23 countries · 12% of the world.* **Share** (the first share moment) or Continue. |
| 45–60 s | **"Now, one thing you loved."** Three chips (café / film / airline) start a pre-filled quick-log that ends in **Hold to Savour**. Your first keepsake lands in the Journal. |

- Every step is skippable. All six collections stay visible and can be hidden later. This replaces the "pick your collections" checkbox screen.
- It depends only on the bundled country catalogue and polygons, not on MapKit, so it can ship in **M1**.

---

## 7. SwiftUI feasibility notes

| Element | Technique | Risk |
|---|---|---|
| Keepsake shapes | Custom `Shape`s: notches via `Path.subtracting` (iOS 17 boolean ops), perforations via `StrokeStyle(dash:)`, scallop, deckle and zig-zag paths. A `KeepsakeTemplate` protocol with 7 conforming views | Low. Keep each template under ~150 lines |
| Paper grain and ink | A bundled grain tile with `.blendMode(.multiply)`. Stamp ink roughness via `.colorEffect(ShaderLibrary.inkGrain)` (a Metal stitchable shader of about 15 lines) | Low–medium (Metal authoring) |
| ā seal hold | `onLongPressGesture(minimumDuration:perform:onPressingChanged:)` plus a progress-driven mask. `CHHapticEngine` continuous event with a parameter curve (`.sensoryFeedback` can't ramp) | Medium: Core Haptics lifecycle. Fall back to `.sensoryFeedback(.success)` |
| Thunk, landing, flip | `KeyframeAnimator` (scale/rotation tracks), `PhaseAnimator` for the stamp, `rotation3DEffect` for the flip | Low |
| Card → detail | `matchedTransitionSource` + `navigationTransition(.zoom)` (iOS 18+) | Low |
| Pill → sheet morph | `GlassEffectContainer` + `glassEffectID(_:in:)`; `tabViewBottomAccessory` | Low–medium: test the accessory with sheets |
| Duel re-flow | `matchedGeometryEffect` in the ranked list; `contentTransition(.numericText())` for No. n | Low |
| Split-flap codes | `.contentTransition(.numericText())` on SF Mono | Low |
| Ink world map | `Canvas` drawing simplified Natural Earth polygons projected (equirectangular or Robinson) once into cached `Path`s; plum fill for visited countries | Medium: projection plus a hit-test via `Path.contains`. Test with 250 countries |
| Atlas | `MKMapView` (`UIViewRepresentable`) with `MKStandardMapConfiguration(emphasisStyle: .muted)`, `MKMultiPolygon` overlays in plum α 0.35, cluster annotation views showing **pre-rendered UIImages** (from `ImageRenderer`, cached), never live SwiftUI hosting | Medium–high (performance): covered by the existing 5k test. The bloom animation via renderer alpha is a nice-to-have |
| Share cards | `ImageRenderer` at scale 3 + `ShareLink` (`Transferable` image). Maps need `MKMapSnapshotter`, since `ImageRenderer` can't render `Map` | Low |
| Teaching | TipKit tips: "Hold the ā to savour", "Tap a card to flip it" | Low |
| Mesh backgrounds | `MeshGradient` 3×3 in aubergine/plum/saffron, gently animated with `TimelineView` (paused under Reduce Motion) | Low |
| Accessibility | Each keepsake is one `accessibilityElement(children: .combine)` with a spoken summary. Rotations disabled under Reduce Motion. Keepsake text uses Dynamic Type, and templates reflow vertically at AX sizes | Medium: test at AX3+ |

---

## 8. Backlog impact

### Existing tickets that change (by title)
- **Design tokens: colour, type, spacing, light & dark** (done) → superseded by *Design tokens v2* (new).
- **App icon, launch screen and About screen** (done) → *App icon v2 + Colophon* (new).
- **App shell: tabs and global add button** (done) → *Shell v2* (new). The tabs become Journal/Collections/Atlas, and Settings moves to the toolbar.
- **Collections screen: list, reorder, hide** (done) → restyled by *Collections cabinet* (new). The reorder and hide logic is kept.
- **Create a custom collection** → add a keepsake template picker (tag/postcard/receipt). +0–1 pt.
- **Quick-log flow (under 15 seconds)** → restructured into Pick / Find / Savour / Seal with a live keepsake preview. Stays 8 pts; the seal is split out.
- **Rating mode: stars** → presented as the **Relish scale** (ā marks and words). 2 → 3.
- **Rating mode: checklist with completion progress** → the Passport spread and continent `MacronBar`s. 3 → 3.
- **Rating mode: ranked via 'which was better?'** → the **This or That?** duel, using keepsake cards and a stamped result. 5 → 5.
- **Timeline home grouped by month** → the **Journal** of keepsakes with month mastheads. 5 → 5, since the keepsake kit carries the visuals.
- **Collection views: list, poster grid, ranked, progress** → The Menu / Passport / Ticket box / Shelf. 5 → 5.
- **Onboarding: pick your collections** → replaced by **Stamp your passport onboarding**, moved earlier. 3 → 5.
- **Map: fill visited countries / clustered photo stacks / individual pins** → ink fill, fanned keepsake stacks, mini keepsake pins. Same points.
- **On this day** → the flip-card treatment. **Year in review** → the **Tasting Menu**. **Poster export** → an aubergine frame with the colophon.
- **Accessibility pass** → add the paper-physics Reduce Motion audit and keepsake VoiceOver summaries.

### New tickets, ordered so the distinctive moments land first

| # | Title | One-line story | Pts |
|---|---|---|---|
| 1 | Design tokens v2: Aubergine & Saffron | As a user I want the app to feel like plum ink on warm paper, consistent in light and dark | 2 |
| 2 | App icon v2 and Colophon About | As a user I see the cream ā with a saffron macron on aubergine, in the icon and on About | 1 |
| 3 | Keepsake kit I: base card, paper material, stamp and luggage-tag templates | As a user my entries look like real keepsakes, not rows | 5 |
| 4 | ā Seal: hold to savour | As a user, saving a memory feels like pressing a seal, with haptics | 3 |
| 5 | Shell v2: Journal / Collections / Atlas and savour accessory | As a user I can savour from anywhere, with nearby suggestions | 2 |
| 6 | Ink world map (Canvas renderer of bundled polygons) | As a user I see my countries flood with ink, offline, without MapKit | 3 |
| 7 | Onboarding: stamp your passport *(replaces the old onboarding)* | As a new user I fill my map in 30 s and share it | 5 |
| 8 | Collections cabinet | As a user my collections are drawers showing their best keepsakes, not a list of zeros | 3 |
| 9 | Keepsake kit II: receipt, menu card, ticket stub, boarding pass, postcard | As a user each category has its own artefact | 5 |
| 10 | Share cards: keepsake, passport spread, top-5 menu | As a user I can share any keepsake as a beautiful image | 3 |
| 11 | Motion and haptics kit with Reduce Motion fallbacks | As a developer I reuse thunk/settle/flip presets and the haptic map | 2 |
| 12 | Duel polish: stamped result and list re-flow | As a user ranking feels like a game, not a form | 2 |
| 13 | Spike: Atlas styling (muted map, ink overlays, snapshot pins) | Decide how to render keepsake pins at 5k entries | 2 |
| 14 | Tear the stub (films) and split-flap codes (flights) | As a user logging a film or a flight has its own finishing gesture | 2 (P2) |
| 15 | Sound pack: paper, stamp, seal | As a user I hear subtle paper sounds (mutable) | 1 (P2) |

**Suggested order:** 1–5 right after the current collection work (before the quick-log story, so it's built on the new kit), then 6–7 straight after the country catalogue, then 8–12 alongside the rating modes in M1, then 13 before the M2 map stories. 14–15 are P2.

**Net scope:** about +37 new points, minus about 8 from deferring *Custom fields for collections* (5) and *Map filters* (3) to M4. That's roughly **+29, or about two sprints**. If that's too much, cut 14, 15 and half of 9 (ship the receipt and ticket stub; leave postcard and boarding pass for M4) for −8.

> **Correction (when the backlog was updated):** the table above sums to **41** new points, not 37. With the old onboarding replaced (−3) and stars at 3 (+1), the plan grows by about **+39**. Deferring custom fields and map filters moves 8 of those points from M1/M2 into M4, so the MVP grows by about **+31** (a little over two sprints). The owner approved the full scope.

---

## 9. Design tokens v2 (ready to implement)

### Colour

All text tokens are checked against every background token in both modes with `contrast.py`. **Minimum ratio is 4.7:1 in light mode and 6.4:1 in dark mode.**

| Token | Light | Dark | Use |
|---|---|---|---|
| `background` (paper) | `#FAF6F0` | `#15101A` | App background |
| `surface` | `#FFFFFF` | `#1F1826` | Grouped rows, sheets |
| `surfaceRaised` | `#F1EAF0` | `#2B2233` | Chips, fields |
| `keepsakePaper` | `#FFFBF4` | `#241C2B` | All keepsake fills |
| `plumWash` | `#EFE3F5` | `#2F2140` | Selected states, visited-country tint behind text |
| `saffronWash` | `#FBEBD0` | `#33261A` | Highlights, "No. 1" badge field |
| `textPrimary` (ink) | `#221530` | `#F4EEF6` | Body, titles |
| `textSecondary` | `#5D4E68` | `#BBAFC4` | Captions, metadata |
| `brand` (plum) | `#6B2D8C` | `#C9A3EC` | Seals, ranks, primary buttons, links |
| `onBrand` | `#FFFFFF` (8.8:1) | `#15101A` (8.9:1) | Text on brand fills |
| `saffron` (fill, decorative) | `#F2A93B` | `#F5B54A` | Macron bars, glints. Never text on paper |
| `saffronInk` (text) | `#8C4F00` | `#F5B54A` | Saffron-coloured text |
| `onSaffron` | `#221530` (8.6:1) | `#15101A` (10.3:1) | Text on saffron fills |
| `aubergine` (hero field) | `#3A1748` → `#24102E` | same | Icon, onboarding, share cards. Cream `#FAF6F0` text is 14.0:1, saffron is 8.3:1, lilac is 7.1:1 |
| `separator` | `#E4DAE3` | `#3A3042` | Hairlines (non-text) |
| `inkShadow` | `#221530` @ 12% / 8% | `#000000` @ 40% | Two-layer keepsake shadow |

### Collection inks

These keep their names; **Countries is darkened slightly** and **Films moves from Plum to Rose** so it doesn't clash with the brand.

| Accent | Light | Dark | Min contrast (light / dark) |
|---|---|---|---|
| Coffee (cafés) | `#8A5A2B` | `#D9A066` | 4.7 / 6.4 |
| Tomato (restaurants) | `#B23A2E` | `#FF8A7A` | 4.8 / 6.4 |
| Jade (countries) | **`#276C4C`** (was `#2B7553`) | `#6FD3A4` | 5.1 / 8.0 |
| Indigo (cities) | `#4B5BB5` | `#9DA8FF` | 4.9 / 6.6 |
| Sky (airlines) | `#1D689E` | `#7CC0F2` | 4.8 / 7.5 |
| **Rose (films)** | **`#A3245E`** (was Plum `#8E3B8A`) | **`#F49AC1`** | 5.7 / 7.1 |
| Slate (custom) | `#56606E` | `#AEB8C6` | 5.2 / 7.3 |

*Min contrast is the worst case across background, surface, surfaceRaised, keepsakePaper, plumWash and saffronWash.*

### Type scale (all relative to Dynamic Type)

| Token | Font | Size / style | Use |
|---|---|---|---|
| `hero` | New York Heavy | 56 relative to `.largeTitle` | No. 1, "23 countries" |
| `display` | New York Bold | `.largeTitle` (34) | Screen titles |
| `masthead` | New York *Italic* | `.largeTitle` (34) | Month headers in the Journal |
| `title` | New York Semibold | `.title2` (22) | Card titles, item names |
| `voice` | New York *Italic* | `.title3` (20) | Prompts, notes, relish words |
| `headline` | SF Pro Semibold | `.headline` (17) | Row titles |
| `body` | SF Pro | `.body` (17) | Body text |
| `callout` | SF Pro | `.callout` (16) | Secondary body |
| `caption` | SF Pro | `.caption` (12) | Metadata |
| `ticketLabel` | SF Pro Expanded Semibold, uppercase, tracking 1.5 | `.caption2` (11) | ADMIT ONE, GATE, ENTRY |
| `code` | SF Mono Medium | `.body` (17) / `.title` (28) on passes | IATA codes, printed dates |
| `devanagari` | Kohinoor Devanagari Semibold | `.title3` | आस्वाद |

### Spacing, radius and motion

- **Spacing:** keep the 4 pt scale.
- **Radius:** add `Radius.keepsake = 3` and `Radius.seal = .infinity` (circle). Keep small 6, medium 12 and large 20 for glass chrome.
- **Tilt:** `Tilt.keepsake = ±2°` and `Tilt.stamp = ±8°`, both deterministic from the entry id hash.
- **Motion:**
  - `settle`: `.spring(response: 0.45, dampingFraction: 0.72)`
  - `thunk`: keyframes 1 → 1.18 (90 ms) → 0.97 (70 ms) → 1 (120 ms)
  - `flip`: 0.6 s `.snappy`
  - `stagger`: 40 ms
  - `sealHold`: 0.6 s
- **Haptics:**
  - `seal`: Core Haptics ramp
  - `stamp`: `.impact(weight: .heavy)`
  - `pick`: `.impact(weight: .medium)`
  - `relishStep`: `.selection`
  - `done`: `.success`

### New components (`Core/DesignSystem` unless noted)

- `KeepsakeCard` + `KeepsakeTemplate` (Receipt, MenuCard, Stamp, Postcard, BoardingPass, TicketStub, LuggageTag)
- `SealButton`
- `RelishScale`
- `MacronBar`
- `MonthMasthead`
- `FlipCard`
- `GhostKeepsake` (empty state)
- `SavourAccessory` (AsvadaApp)
- `InkWorldMap` (Core/Geo + DesignSystem)
- `PassportSpread`
- `DuelView` (Features/Ranking)
- `MenuList`
- `ShareCardRenderer`
- `PaperBackground`
- `Motion` and `Haptics` token enums

*The contrast checkers are in `scripts/design/` (`contrast.py`, `contrast2.py`). Port it into `DesignSystemTests` so CI enforces AA for the v2 tokens, as it does today.*
