# Measuring the Atlas (#53)

The Atlas is a SwiftUI `Map` with one polygon per ring of every inked country and, zoomed in, up to
300 pins nearest the middle (`AtlasLogic.pinLimit`). This is how to measure it with a lot of
places, on a device, and where to write the numbers down.

## What the code already does for the load

- **Pins are bounded.** Only places inside the visible region are considered, and at most 300 are
  drawn, nearest the middle first. Zoomed out past 30° of latitude none are drawn.
- **Rings are built once.** `AtlasRingCache` keeps each country's polygon coordinates (Canada alone
  is about 8,000 points), so panning, zooming and changing a filter don't rebuild them.
- **Thumbnails:** pins carry an icon, not a photo, so there is no thumbnail cache to bound yet.
  The photo stacks (#50) bring one and must bound it.

## Set-up

1. Build and run Asvada on the device from Xcode with the **Release** configuration (Profile),
   so Debug overhead doesn't hide or fake a problem.
2. Add these launch arguments to the scheme (they only work with the in-memory store, so nothing
   touches your real data):

   ```
   -inMemoryStore -skipOnboarding -disableTips -stressPlaces 5000
   ```

   `-stressPlaces N` scatters N cafés, restaurants and cities round 28 cities, with one entry
   each, deterministically. About 25 countries ink as the places stamp them. Add `-stressItems
   5000` as well to load the cabinet and riffle (ADR-0004) at the same time.

## Run

Open Instruments from Xcode (Product → Profile) with the **Animation Hitches** template, then
**Time Profiler** and **Allocations** (or the SwiftUI template, if you have it). For each:

| Pass | What to do | Look for |
|---|---|---|
| World | Open Atlas. Pan and pinch for 20 s at world scale. | Frame rate; hitches while the ink moves |
| Country | Zoom to Western Europe (a few countries, dense pins). Pan for 20 s. | Frame rate with pins on; time in `AtlasLogic.pins` |
| City | Zoom into London (300 pins, the cap). Pan for 20 s. | Frame rate with the most annotations |
| Filter | Open the filter sheet, tick Cafés, change a year, reset. Repeat 10 times. | Time to redraw; ring-cache reuse |
| Memory | Pan around for two minutes. | Allocations growth; no leak after leaving the tab |

## Targets (from #53)

- At least **55 fps** while panning, on the target device.
- Memory settles and doesn't grow while panning.

## Results

Fill this in from the run and attach the Instruments traces to #53.

| Date | Device | Build | World fps | Country fps | City fps | Peak memory | Notes |
|---|---|---|---|---|---|---|---|
| | | | | | | | |

If a pass misses the target, the likely culprits, in order: the 300-pin cap (lower it), polygon
detail (thin the rings the way `InkGlobeWorld` does, at 0.3° near and 1° far), and hosting views
as annotations (swap the pin for a pre-rendered image once #120's spike decides).
