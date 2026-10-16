#!/usr/bin/env python3
"""Draw Funkel's app icon: Pip, the mascot, on a warm background with sparkles.

Mirrors the SwiftUI Pip shape (Funkel/DesignSystem/Pip.swift) so the icon and
the app match. Output: a 1024x1024 RGB PNG without transparency, as the App
Store requires.

    python3 scripts/make_app_icon.py
Needs Pillow (`pip install pillow`).
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

SIZE = 1024
SCALE = 4                      # draw at 4x, then downsample for smooth edges
S = SIZE * SCALE
OUT = Path(__file__).absolute().parent.parent / "Funkel/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png"

SUN_TOP = (255, 196, 64)
SUN_BOTTOM = (255, 150, 20)
INK = (43, 37, 64)
CHEEK = (255, 120, 140)
BG_TOP = (255, 248, 236)
BG_BOTTOM = (255, 214, 150)


def lerp(a, b, t):
    return tuple(round(x + (y - x) * t) for x, y in zip(a, b))


def vertical_gradient(size, top, bottom):
    w, h = size
    column = Image.new("RGB", (1, h))
    for y in range(h):
        column.putpixel((0, y), lerp(top, bottom, y / (h - 1)))
    return column.resize((w, h))


def px(v):
    """Icon-space units (0..1) to pixels at the drawing scale."""
    return int(round(v * S))


def sparkle(draw, cx, cy, r, color):
    """A four-pointed star."""
    k = r * 0.28
    points = [(cx, cy - r), (cx + k, cy - k), (cx + r, cy), (cx + k, cy + k),
              (cx, cy + r), (cx - k, cy + k), (cx - r, cy), (cx - k, cy - k)]
    draw.polygon([(px(x), px(y)) for x, y in points], fill=color)


def main():
    icon = vertical_gradient((S, S), BG_TOP, BG_BOTTOM)
    draw = ImageDraw.Draw(icon)

    # Sparkles ("Funkel" = sparkle)
    sparkle(draw, 0.17, 0.20, 0.060, (255, 255, 255))
    sparkle(draw, 0.84, 0.16, 0.045, (255, 225, 140))
    sparkle(draw, 0.86, 0.80, 0.055, (255, 255, 255))
    sparkle(draw, 0.12, 0.74, 0.035, (255, 225, 140))

    # Pip, centred a little low to leave room for the tuft
    cx, cy, r = 0.5, 0.56, 0.33

    # Soft shadow under Pip
    shadow = Image.new("L", (S, S), 0)
    ImageDraw.Draw(shadow).ellipse([px(cx - r), px(cy - r + 0.03), px(cx + r), px(cy + r + 0.03)], fill=110)
    shadow = shadow.filter(ImageFilter.GaussianBlur(px(0.03)))
    icon.paste(Image.new("RGB", (S, S), (230, 140, 40)), mask=shadow)
    draw = ImageDraw.Draw(icon)

    # Tuft: three capsules, the middle one tallest
    for dx, height, angle in ((-0.075, 0.13, 25), (0.0, 0.17, 0), (0.075, 0.13, -25)):
        w = 0.06
        capsule = Image.new("L", (px(w * 2), px(height * 2)), 0)
        ImageDraw.Draw(capsule).rounded_rectangle(
            [px(w / 2), px(height / 2), px(w * 1.5), px(height * 1.5)], radius=px(w / 2), fill=255)
        capsule = capsule.rotate(angle, resample=Image.BICUBIC)
        base_x = cx + dx
        base_y = cy - r + 0.02 - height / 2
        icon.paste(Image.new("RGB", capsule.size, SUN_TOP),
                   (px(base_x - w), px(base_y - height)), mask=capsule)
    draw = ImageDraw.Draw(icon)

    # Body with a vertical gradient
    body_mask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(body_mask).ellipse([px(cx - r), px(cy - r), px(cx + r), px(cy + r)], fill=255)
    body = vertical_gradient((S, S), SUN_TOP, SUN_BOTTOM)
    icon.paste(body, mask=body_mask)
    draw = ImageDraw.Draw(icon)

    # Highlight
    highlight = Image.new("L", (S, S), 0)
    ImageDraw.Draw(highlight).ellipse([px(cx - 0.20), px(cy - 0.27), px(cx + 0.02), px(cy - 0.13)], fill=70)
    highlight = highlight.filter(ImageFilter.GaussianBlur(px(0.02)))
    icon.paste(Image.new("RGB", (S, S), (255, 255, 255)), mask=highlight)
    draw = ImageDraw.Draw(icon)

    # Cheeks
    cheeks = Image.new("L", (S, S), 0)
    cd = ImageDraw.Draw(cheeks)
    for side in (-1, 1):
        x = cx + side * 0.19
        cd.ellipse([px(x - 0.045), px(cy + 0.03), px(x + 0.045), px(cy + 0.10)], fill=120)
    cheeks = cheeks.filter(ImageFilter.GaussianBlur(px(0.006)))
    icon.paste(Image.new("RGB", (S, S), CHEEK), mask=cheeks)
    draw = ImageDraw.Draw(icon)

    # Happy closed eyes: upward arcs
    stroke = px(0.026)
    for side in (-1, 1):
        x = cx + side * 0.11
        draw.arc([px(x - 0.055), px(cy - 0.06), px(x + 0.055), px(cy + 0.04)], start=200, end=340, fill=INK, width=stroke)

    # Smile
    draw.arc([px(cx - 0.11), px(cy - 0.02), px(cx + 0.11), px(cy + 0.17)], start=20, end=160, fill=INK, width=stroke)

    final = icon.resize((SIZE, SIZE), Image.LANCZOS).convert("RGB")
    OUT.parent.mkdir(parents=True, exist_ok=True)
    final.save(OUT, "PNG", optimize=True)
    print(f"wrote {OUT} ({final.size[0]}x{final.size[1]}, mode {final.mode})")


if __name__ == "__main__":
    main()
