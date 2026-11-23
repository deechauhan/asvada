#!/usr/bin/env python3
"""Build Core/Sources' bundled airline catalog from OpenFlights (ODbL 1.0).

Usage:
  curl -sSLo /tmp/airlines.dat  https://raw.githubusercontent.com/jpatokal/openflights/master/data/airlines.dat
  curl -sSLo /tmp/countries.dat https://raw.githubusercontent.com/jpatokal/openflights/master/data/countries.dat
  python3 -I scripts/data/build_airlines.py /tmp/airlines.dat /tmp/countries.dat

Writes Packages/Core/Sources/Sources/Sources/Resources/airlines.json:
  {"source": ..., "licence": ..., "airlines": [{"name", "iata", "icao", "country"}]}

Keeps airlines marked active that have a two-character IATA code (what boarding passes print);
the ICAO code is kept when present. Countries are mapped from OpenFlights' names to ISO 3166-1
alpha-2 codes, so flags and passport stamps line up with Core/Geo.
"""
import csv
import json
import sys
from pathlib import Path

OUT = Path(__file__).resolve().parents[2] / "Packages/Core/Sources/Sources/Sources/Resources/airlines.json"
NULLS = {"", "\\N", "-", "N/A"}
# OpenFlights country names that its own countries table doesn't resolve.
COUNTRY_FIXES = {
    "Republic of Korea": "KR",
    "Democratic People's Republic of Korea": "KP",
    "Hong Kong SAR of China": "HK",
    "Macao SAR of China": "MO",
    "Lao Peoples Democratic Republic": "LA",
    "Russia": "RU",
    "Syrian Arab Republic": "SY",
    "Ivory Coast": "CI",
    "Macedonia": "MK",
    "Moldova": "MD",
    "Iran": "IR",
    "Brunei": "BN",
    "Burma": "MM",
    "Cape Verde": "CV",
    "Congo (Kinshasa)": "CD",
    "Republic of the Congo": "CG",
    "Faroe Islands": "FO",
    "Kyrgyzstan": "KG",
    "Russian Federation": "RU",
    "Canadian Territories": "CA",
}


def clean(value):
    return None if value in NULLS else value.strip()


def main(airlines_path, countries_path):
    iso = {}
    for row in csv.reader(open(countries_path, encoding="utf-8")):
        name, code = row[0], row[1]
        if clean(code) and len(code) == 2:
            iso[name] = code
    iso.update(COUNTRY_FIXES)

    airlines, unmapped = [], set()
    for row in csv.reader(open(airlines_path, encoding="utf-8")):
        _, name, _, iata, icao, _, country, active = row[:8]
        iata, icao, country, name = clean(iata), clean(icao), clean(country), clean(name)
        if active != "Y" or not name or not iata or len(iata) != 2:
            continue
        code = iso.get(country) if country else None
        if country and not code:
            unmapped.add(country)
        airlines.append({
            "name": name,
            "iata": iata.upper(),
            "icao": icao.upper() if icao and len(icao) == 3 else None,
            "country": code,
        })
    airlines.sort(key=lambda a: (a["name"].casefold(), a["iata"]))
    catalog = {
        "source": "OpenFlights airlines.dat (https://openflights.org/data), filtered by scripts/data/build_airlines.py",
        "licence": "Open Database License (ODbL) 1.0: https://opendatacommons.org/licenses/odbl/1-0/",
        "airlines": airlines,
    }
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(catalog, ensure_ascii=False, separators=(",", ":")))
    print(f"{len(airlines)} airlines, {OUT.stat().st_size / 1024:.0f} KB -> {OUT}")
    if unmapped:
        print("countries without an ISO code:", sorted(unmapped))


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
