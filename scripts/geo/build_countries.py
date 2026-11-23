#!/usr/bin/env python3
"""Build Core/Geo's bundled country catalog from Natural Earth (public domain).

Usage:
  curl -sSLo /tmp/ne_50m.geojson \
    https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/ne_50m_admin_0_countries.geojson
  python3 -I scripts/geo/build_countries.py /tmp/ne_50m.geojson

Writes Packages/Core/Geo/Sources/Geo/Resources/countries.json:
  {"source": ..., "countries": [{"code", "code3", "name", "continent", "rings"}], "land": [{"name", "rings"}]}
Each ring is a flat [lon, lat, lon, lat, ...] list, simplified (Douglas-Peucker) and rounded to
0.001 degrees (about 100 m): fine enough that coastal cities and enclaves look up correctly,
still about 1 MB.

Shapes whose ISO code is only in ISO_A2_EH (France, Norway, Kosovo) use it. Territories that
share a code with their country (e.g. Australia's Indian Ocean territories) merge into it.
Shapes with no ISO code at all are kept as unselectable "land", so the map has no holes and the
app doesn't take sides on disputed areas.
"""
import json
import math
import sys
from pathlib import Path

OUT = Path(__file__).resolve().parents[2] / "Packages/Core/Geo/Sources/Geo/Resources/countries.json"
TOLERANCE = 0.01  # degrees
# Everyday names where Natural Earth's are formal.
NAMES = {"US": "United States", "CZ": "Czechia", "BA": "Bosnia and Herzegovina", "VA": "Vatican City"}
PRECISION = 3


def perpendicular(p, a, b):
    if a == b:
        return math.dist(p, a)
    (x, y), (x1, y1), (x2, y2) = p, a, b
    return abs((y2 - y1) * x - (x2 - x1) * y + x2 * y1 - y2 * x1) / math.dist(a, b)


def simplify(points, tolerance):
    """Iterative Douglas-Peucker."""
    if len(points) < 3:
        return points
    keep = [False] * len(points)
    keep[0] = keep[-1] = True
    stack = [(0, len(points) - 1)]
    while stack:
        start, end = stack.pop()
        best, index = 0.0, None
        for i in range(start + 1, end):
            d = perpendicular(points[i], points[start], points[end])
            if d > best:
                best, index = d, i
        if index is not None and best > tolerance:
            keep[index] = True
            stack.append((start, index))
            stack.append((index, end))
    return [p for p, k in zip(points, keep) if k]


def ring_area(ring):
    return abs(sum(x1 * y2 - x2 * y1 for (x1, y1), (x2, y2) in zip(ring, ring[1:] + ring[:1]))) / 2


def compact(ring):
    simplified = simplify(ring, TOLERANCE)
    if len(simplified) < 4:
        simplified = ring  # tiny islands: keep their original outline rather than lose them
    rounded = []
    for x, y in simplified:
        point = (round(x, PRECISION), round(y, PRECISION))
        if not rounded or rounded[-1] != point:
            rounded.append(point)
    if len(rounded) < 4:
        return None
    return [coordinate for point in rounded for coordinate in point]


def outer_rings(geometry):
    """Outer rings only: holes (lakes, enclaves) are other countries or water we needn't cut."""
    if geometry["type"] == "Polygon":
        return [geometry["coordinates"][0]]
    return [polygon[0] for polygon in geometry["coordinates"]]


def continent(props):
    value = props["CONTINENT"]
    if value.startswith("Seven seas"):
        return {"Americas": "North America"}.get(props["REGION_UN"], props["REGION_UN"])
    return value


def main(path):
    features = json.loads(Path(path).read_text())["features"]
    countries, land = {}, []
    for feature in features:
        props = feature["properties"]
        code = props["ISO_A2"] if props["ISO_A2"] != "-99" else props.get("ISO_A2_EH", "-99")
        rings = [compact(ring) for ring in sorted(outer_rings(feature["geometry"]), key=ring_area, reverse=True)]
        rings = [ring for ring in rings if ring]
        if code == "-99":
            land.append({"name": props["NAME_EN"] or props["NAME"], "rings": rings})
            continue
        entry = countries.get(code)
        if entry is None or props["ISO_A2"] != "-99" and entry.get("merged"):
            # Prefer the feature that carries the code natively as the country's identity.
            base = {
                "code": code,
                "code3": props["ISO_A3"] if props["ISO_A3"] != "-99" else props["ADM0_A3"],
                "name": NAMES.get(code, props["NAME_EN"] or props["NAME"]),
                "continent": continent(props),
                "rings": (entry or {}).get("rings", []),
            }
            entry = countries[code] = base
        else:
            entry["merged"] = True
        entry["rings"].extend(rings)
    catalog = {
        "source": "Natural Earth 1:50m Admin 0 - Countries (public domain), simplified by scripts/geo/build_countries.py",
        "countries": sorted(
            ({key: value for key, value in entry.items() if key != "merged"} for entry in countries.values()),
            key=lambda entry: entry["name"],
        ),
        "land": land,
    }
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(catalog, ensure_ascii=False, separators=(",", ":")))
    points = sum(len(r) // 2 for c in catalog["countries"] for r in c["rings"])
    print(f"{len(catalog['countries'])} countries, {len(land)} unassigned shapes, {points} points, "
          f"{OUT.stat().st_size / 1024:.0f} KB -> {OUT}")


if __name__ == "__main__":
    main(sys.argv[1])
