# Sources/Geo/Resources/countries.json

Built from **Natural Earth** 1:50m *Admin 0 – Countries* by `scripts/geo/build_countries.py`
(Douglas–Peucker simplification at 0.01°, coordinates rounded to 0.001°, outer rings only).

Natural Earth is in the **public domain**: "No permission is needed to use Natural Earth. Crediting
the authors is unnecessary." (<https://www.naturalearthdata.com/about/terms-of-use/>). We credit it
anyway, here and in the app's Colophon.

Shapes without an ISO code (Somaliland, Northern Cyprus, Siachen Glacier) are kept as
unselectable land so the map has no holes; the app takes no position on disputed borders.

## Lookup limits

`CountryCatalog.country(at:)` finds the containing outline (the smallest, for enclaves) or the
nearest coast within 20 km. At this resolution: Gibraltar isn't in the 1:50m data (its places fall
to Spain), the Vatican is below the data's resolution (falls to Italy), and within about 1 km of a
land border a point can land in the neighbouring country. An item's own country code, when known
(e.g. from a place search), always wins over the lookup.
