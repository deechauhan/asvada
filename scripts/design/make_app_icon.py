#!/usr/bin/env python3
"""Generates the placeholder app icon (light, dark and tinted variants) into the asset catalog.

v2 (Keepsakes): a cream serif "a" with a saffron macron bar, i.e. "ā", on the aubergine field.
Re-run after changing colours:
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


def draw_mark(img: Image.Image, glyph, macron) -> Image.Image:
    """A serif "a" with a separate macron bar above it, so the bar can take its own colour."""
    font = ImageFont.truetype(FONT, 640)
    draw = ImageDraw.Draw(img)
    box = draw.textbbox((0, 0), "a", font=font)
    w, h = box[2] - box[0], box[3] - box[1]
    x = (SIZE - w) / 2 - box[0]
    y = (SIZE - h) / 2 - box[1] + 70
    draw.text((x, y), "a", font=font, fill=glyph)
    bar_w, bar_h = 300, 62
    top = y + box[1] - 150
    draw.rounded_rectangle(
        [(SIZE - bar_w) / 2, top, (SIZE + bar_w) / 2, top + bar_h], radius=10, fill=macron,
    )
    return img


def main():
    cream, saffron = hex_rgb("#FAF6F0"), hex_rgb("#F2A93B")
    # Light: cream "a" with a saffron macron on the aubergine field (Palette.aubergineTop → Bottom).
    draw_mark(gradient("#3A1748", "#24102E"), cream, saffron).save(OUT / "AppIcon.png")
    # Dark: a deeper aubergine so it sits quietly on a dark home screen.
    draw_mark(gradient("#2A1035", "#160A1C"), cream, hex_rgb("#F5B54A")).save(OUT / "AppIcon-Dark.png")
    # Tinted: white mark on transparent; the system applies the user's tint.
    tinted = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw_mark(tinted, (255, 255, 255, 255), (255, 255, 255, 255)).save(OUT / "AppIcon-Tinted.png")
    print("wrote", *(p.name for p in sorted(OUT.glob("*.png"))))


if __name__ == "__main__":
    main()
