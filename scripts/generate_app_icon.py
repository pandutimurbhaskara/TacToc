#!/usr/bin/env python3
"""Generate the TactileMac app icon and accent color (original artwork)."""
from __future__ import annotations

import json
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / "TactileMac" / "Resources" / "Assets.xcassets"
ICONSET = ASSETS / "AppIcon.appiconset"


def rounded_mask(size: int, radius: int) -> Image.Image:
    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((0, 0, size - 1, size - 1), radius=radius, fill=255)
    return mask


def gradient(size: int, top: tuple[int, int, int], bottom: tuple[int, int, int]) -> Image.Image:
    image = Image.new("RGB", (1, size))
    for y in range(size):
        t = y / max(1, size - 1)
        color = tuple(round(top[i] * (1 - t) + bottom[i] * t) for i in range(3))
        image.putpixel((0, y), color)
    return image.resize((size, size))


def build_master() -> Image.Image:
    size = 2048
    canvas = gradient(size, (108, 78, 214), (61, 43, 138)).convert("RGBA")
    mask = rounded_mask(size, 360)
    canvas.putalpha(mask)

    # Soft lavender glow in the upper-left.
    glow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    gdraw = ImageDraw.Draw(glow)
    gdraw.ellipse((-300, -500, 1200, 900), fill=(196, 174, 255, 95))
    glow = glow.filter(ImageFilter.GaussianBlur(160))
    canvas = Image.alpha_composite(canvas, glow)

    # Subtle inner border.
    border = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    bdraw = ImageDraw.Draw(border)
    bdraw.rounded_rectangle((34, 34, size - 35, size - 35), radius=330, outline=(255, 255, 255, 42), width=10)
    canvas = Image.alpha_composite(canvas, border)

    # Keycap shadow.
    shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    sdraw = ImageDraw.Draw(shadow)
    sdraw.rounded_rectangle((455, 655, 1595, 1675), radius=245, fill=(20, 8, 55, 135))
    shadow = shadow.filter(ImageFilter.GaussianBlur(55))
    canvas = Image.alpha_composite(canvas, shadow)

    # Keycap body.
    key = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    kdraw = ImageDraw.Draw(key)
    kdraw.rounded_rectangle((430, 610, 1570, 1630), radius=235, fill=(250, 248, 255, 255))
    kdraw.rounded_rectangle((430, 610, 1570, 1480), radius=235, fill=(255, 255, 255, 255))
    kdraw.rounded_rectangle((475, 650, 1525, 1450), radius=205, outline=(225, 216, 255, 255), width=10)
    canvas = Image.alpha_composite(canvas, key)

    # Keycap top highlight.
    shine = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    shdraw = ImageDraw.Draw(shine)
    shdraw.ellipse((560, 665, 1450, 980), fill=(255, 255, 255, 115))
    shine = shine.filter(ImageFilter.GaussianBlur(70))
    canvas = Image.alpha_composite(canvas, shine)

    # Glyph: a stylized "T" plus a teal haptic wave.
    draw = ImageDraw.Draw(canvas)
    purple = (88, 62, 190, 255)
    draw.rounded_rectangle((680, 845, 1380, 950), radius=52, fill=purple)
    draw.rounded_rectangle((930, 845, 1125, 1430), radius=95, fill=purple)

    teal = (54, 202, 192, 255)
    for index, (x, height, width) in enumerate(((590, 130, 34), (710, 250, 34), (830, 90, 34))):
        opacity = 120 + index * 50
        draw.rounded_rectangle((x, 1160 - height // 2, x + width, 1160 + height // 2), radius=17, fill=teal[:3] + (opacity,))
    for index, (x, height, width) in enumerate(((1330, 100, 34), (1450, 210, 34), (1570, 70, 34))):
        opacity = 210 - index * 45
        draw.rounded_rectangle((x, 1160 - height // 2, x + width, 1160 + height // 2), radius=17, fill=teal[:3] + (opacity,))

    return canvas


def save_icons(master: Image.Image) -> None:
    ICONSET.mkdir(parents=True, exist_ok=True)
    entries = []
    for base in (16, 32, 128, 256, 512):
        for scale in (1, 2):
            pixels = base * scale
            filename = f"icon_{base}x{base}{'@2x' if scale == 2 else ''}.png"
            image = master.resize((pixels, pixels), Image.LANCZOS)
            image.save(ICONSET / filename)
            entries.append({"size": f"{base}x{base}", "idiom": "mac", "filename": filename, "scale": f"{scale}x"})
    contents = {"images": entries, "info": {"author": "xcode", "version": 1}}
    (ICONSET / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n", encoding="utf-8")

    accent = ASSETS / "AccentColor.colorset"
    accent.mkdir(parents=True, exist_ok=True)
    colors = {
        "colors": [
            {
                "color": {"color-space": "srgb", "components": {"alpha": "1.000", "blue": "0.850", "green": "0.420", "red": "0.560"}},
                "idiom": "universal",
            },
            {
                "appearances": [{"appearance": "luminosity", "value": "dark"}],
                "color": {"color-space": "srgb", "components": {"alpha": "1.000", "blue": "0.940", "green": "0.600", "red": "0.690"}},
                "idiom": "universal",
            },
        ],
        "info": {"author": "xcode", "version": 1},
    }
    (accent / "Contents.json").write_text(json.dumps(colors, indent=2) + "\n", encoding="utf-8")
    (ASSETS / "Contents.json").write_text(json.dumps({"info": {"author": "xcode", "version": 1}}, indent=2) + "\n", encoding="utf-8")


def main() -> None:
    master = build_master()
    save_icons(master)
    print("wrote AppIcon.appiconset and AccentColor.colorset")


if __name__ == "__main__":
    main()
