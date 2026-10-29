#!/usr/bin/env python3
"""Regenerates the bundled map geometry in expedition/ReferenceData/.

Not part of the app build. Run by hand (Python 3.9+, standard library only)
when the country list or source data needs to change:

    python3 tools/build-reference-data.py

What it does:
  1. Downloads Natural Earth 1:50m admin-0 countries and admin-1 states
     (pinned version, public domain).
  2. Keeps the 197 sovereign countries in SOVEREIGN plus the non-sovereign
     EXTRAS, keyed by ISO 3166-1 alpha-2 code, and the 50 US states keyed by
     USPS postal code.
  3. Simplifies outlines (Douglas-Peucker), rounds coordinates, and strips
     properties down to what the app needs.

The output files are the source of truth the app loads. parks.json lives
alongside them but is hand-maintained, not generated here.
"""

import json
import math
import urllib.request
from pathlib import Path

NE_VERSION = "5.1.2"
NE_BASE = f"https://cdn.jsdelivr.net/gh/nvkelso/natural-earth-vector@{NE_VERSION}/geojson"
COUNTRIES_URL = f"{NE_BASE}/ne_50m_admin_0_countries.geojson"
STATES_URL = f"{NE_BASE}/ne_50m_admin_1_states_provinces.geojson"

OUT_DIR = Path(__file__).resolve().parent.parent / "expedition" / "ReferenceData"

# Simplification tolerance in degrees (~5 km for countries, ~2 km for states),
# and output precision in decimal places.
COUNTRY_TOLERANCE = 0.05
STATE_TOLERANCE = 0.02
PRECISION = 3

# The 197 sovereign states counted toward the countries total (193 UN members
# plus Kosovo, Palestine, Taiwan, and Vatican City).
SOVEREIGN = set("""
AD AE AF AG AL AM AO AR AT AU AZ BA BB BD BE BF BG BH BI BJ BN BO BR BS BT BW
BY BZ CA CD CF CG CH CI CL CM CN CO CR CU CV CY CZ DE DJ DK DM DO DZ EC EE EG
ER ES ET FI FJ FM FR GA GB GD GE GH GM GN GQ GR GT GW GY HN HR HT HU ID IE IL
IN IQ IR IS IT JM JO JP KE KG KH KI KM KN KP KR KW KZ LA LB LC LI LK LR LS LT
LU LV LY MA MC MD ME MG MH MK ML MM MN MR MT MU MV MW MX MY MZ NA NE NG NI NL
NO NP NR NZ OM PA PE PG PH PK PL PS PT PW PY QA RO RS RU RW SA SB SC SD SE SG
SI SK SL SM SN SO SR SS ST SV SY SZ TD TG TH TJ TL TM TN TO TR TT TV TW TZ UA
UG US UY UZ VA VC VE VN VU WS XK YE ZA ZM ZW
""".split())

# Non-sovereign areas shown and trackable on the map, but excluded from the total.
EXTRAS = {"GL", "PR", "AQ"}

EXCLUDED_STATES = {"DC"}


def download(url):
    print(f"Downloading {url}")
    with urllib.request.urlopen(url) as response:
        return json.load(response)


def perpendicular_distance(point, start, end):
    (x, y), (x1, y1), (x2, y2) = point, start, end
    dx, dy = x2 - x1, y2 - y1
    if dx == 0 and dy == 0:
        return math.hypot(x - x1, y - y1)
    t = max(0, min(1, ((x - x1) * dx + (y - y1) * dy) / (dx * dx + dy * dy)))
    return math.hypot(x - (x1 + t * dx), y - (y1 + t * dy))


def douglas_peucker(points, tolerance):
    keep = [False] * len(points)
    keep[0] = keep[-1] = True
    stack = [(0, len(points) - 1)]
    while stack:
        first, last = stack.pop()
        index, max_distance = None, tolerance
        for i in range(first + 1, last):
            distance = perpendicular_distance(points[i], points[first], points[last])
            if distance > max_distance:
                index, max_distance = i, distance
        if index is not None:
            keep[index] = True
            stack += [(first, index), (index, last)]
    return [p for p, k in zip(points, keep) if k]


def round_point(point):
    return [round(point[0], PRECISION), round(point[1], PRECISION)]


def simplify_ring(ring, tolerance):
    """Returns the simplified closed ring, or None if it collapsed."""
    simplified = douglas_peucker(ring, tolerance)
    rounded = []
    for point in map(round_point, simplified):
        if not rounded or point != rounded[-1]:
            rounded.append(point)
    if rounded[0] != rounded[-1]:
        rounded.append(rounded[0])
    return rounded if len(rounded) >= 4 else None


def simplify_geometry(geometry, tolerance):
    polygons = geometry["coordinates"] if geometry["type"] == "MultiPolygon" else [geometry["coordinates"]]
    result = []
    for polygon in polygons:
        outer = simplify_ring(polygon[0], tolerance)
        if outer is None:
            continue
        holes = [h for h in (simplify_ring(r, tolerance) for r in polygon[1:]) if h is not None]
        result.append([outer] + holes)
    if not result:
        # Every part was smaller than the tolerance (tiny island nations):
        # keep the largest part at full detail so the place stays visible.
        largest = max(polygons, key=lambda p: len(p[0]))
        result = [[[round_point(p) for p in largest[0]]]]
    return {"type": "MultiPolygon", "coordinates": result}


def feature(properties, geometry, tolerance):
    return {"type": "Feature", "properties": properties, "geometry": simplify_geometry(geometry, tolerance)}


def build_countries(source):
    wanted = SOVEREIGN | EXTRAS
    chosen = {}
    for f in source["features"]:
        p = f["properties"]
        code = p["ISO_A2_EH"]
        if code not in wanted:
            continue
        # Some codes have extra territory features (e.g. Ashmore and Cartier
        # Islands under AU); prefer the country's main feature.
        is_main = p["ADM0_A3"] == p["ISO_A3_EH"]
        if code not in chosen or is_main:
            chosen[code] = f
    missing = wanted - chosen.keys()
    assert not missing, f"Missing countries: {sorted(missing)}"
    features = []
    for code in sorted(chosen):
        p = chosen[code]["properties"]
        properties = {
            "id": code,
            "sovereign": code in SOVEREIGN,
            "labelLatitude": round(p["LABEL_Y"], PRECISION),
            "labelLongitude": round(p["LABEL_X"], PRECISION),
        }
        features.append(feature(properties, chosen[code]["geometry"], COUNTRY_TOLERANCE))
    return features


def build_states(source):
    features = []
    for f in source["features"]:
        p = f["properties"]
        if p["iso_a2"] != "US" or p["postal"] in EXCLUDED_STATES:
            continue
        properties = {
            "id": p["postal"],
            "name": p["name"],
            "labelLatitude": round(p["latitude"], PRECISION),
            "labelLongitude": round(p["longitude"], PRECISION),
        }
        features.append(feature(properties, f["geometry"], STATE_TOLERANCE))
    assert len(features) == 50, f"Expected 50 states, got {len(features)}"
    return sorted(features, key=lambda f: f["properties"]["id"])


def write(name, features):
    path = OUT_DIR / name
    lines = [json.dumps(f, ensure_ascii=False, separators=(",", ":")) for f in features]
    path.write_text('{"type":"FeatureCollection","features":[\n' + ",\n".join(lines) + "\n]}\n")
    points = sum(len(r) for f in features for poly in f["geometry"]["coordinates"] for r in poly)
    print(f"Wrote {path.name}: {len(features)} features, {points} points, {path.stat().st_size // 1024} KB")


def main():
    write("countries.geojson", build_countries(download(COUNTRIES_URL)))
    write("states.geojson", build_states(download(STATES_URL)))


if __name__ == "__main__":
    main()
