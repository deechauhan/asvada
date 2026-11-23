#!/usr/bin/env python3
"""Generates the placeholder app icon (light, dark and tinted variants) into the asset catalog.

A serif "ā" (the first letter of āsvāda) on the brand saffron. Re-run after changing colours:
    python3 scripts/design/make_app_icon.py
Requires Pillow and the DejaVu Serif Bold font (or pass a .ttf path as the first argument).
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "App/Resources/Assets.xcassets/AppIcon.appiconset"
FONT = sys.argv[1] if len(sys.argv) > 1 else "/usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf"
SIZE = 1024


def hex_rgb(value: str) -> tuple[int, int, int]:
    return tuple(int(value[i:i + 2], 16) for i in (1, 3, 5))


def gradient(top: str, bottom: str) -> Image.Image:
    a, b = hex_rgb(top), hex_rgb(bottom)
    img = Image.new("RGB", (SIZE, SIZE))
    px = img.load()
    for y in range(SIZE):
        t = y / (SIZE - 1)
        row = tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))
        for x in range(SIZE):
            px[x, y] = row
    return img


def draw_glyph(img: Image.Image, colour, alpha: bool = False) -> Image.Image:
    font = ImageFont.truetype(FONT, 700)
    draw = ImageDraw.Draw(img)
    box = draw.textbbox((0, 0), "ā", font=font)
    w, h = box[2] - box[0], box[3] - box[1]
    pos = ((SIZE - w) / 2 - box[0], (SIZE - h) / 2 - box[1] + 10)
    draw.text(pos, "ā", font=font, fill=colour)
    return img


def main():
    # Light: cream glyph on saffron (Palette.brand light → a deeper shade).
    draw_glyph(gradient("#C2562A", "#A8401C"), hex_rgb("#FAF7F2")).save(OUT / "AppIcon.png")
    # Dark: saffron glyph on near-black (Palette.background dark).
    draw_glyph(gradient("#1E1B18", "#141210"), hex_rgb("#F08A5D")).save(OUT / "AppIcon-Dark.png")
    # Tinted: white glyph on transparent; the system applies the user's tint.
    tinted = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw_glyph(tinted, (255, 255, 255, 255)).save(OUT / "AppIcon-Tinted.png")
    print("wrote", *(p.name for p in sorted(OUT.glob("*.png"))))


if __name__ == "__main__":
    main()
