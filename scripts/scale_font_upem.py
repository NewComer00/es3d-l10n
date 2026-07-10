#!/usr/bin/env python3
"""Scale a TrueType font's unitsPerEm (and metrics) by a factor. Used for UI menu font merge."""

from __future__ import annotations

import argparse
import sys

from fontTools.ttLib import TTFont
from fontTools.ttLib.tables._g_l_y_f import GlyphCoordinates


def scale_font(src: str, dst: str, scale: float, units_per_em: int) -> None:
    font = TTFont(src)
    font["head"].unitsPerEm = units_per_em
    for name in font.getGlyphOrder():
        glyph = font["glyf"][name]
        if hasattr(glyph, "coordinates") and glyph.coordinates is not None:
            glyph.coordinates = GlyphCoordinates(
                [(int(x * scale), int(y * scale)) for x, y in glyph.coordinates]
            )
        if glyph.numberOfContours not in (-1, None) and glyph.numberOfContours > 0:
            glyph.recalcBounds(font["glyf"])
    for name in font["hmtx"].metrics:
        aw, lsb = font["hmtx"].metrics[name]
        font["hmtx"].metrics[name] = (int(aw * scale), int(lsb * scale))
    font["hhea"].ascent = int(font["hhea"].ascent * scale)
    font["hhea"].descent = int(font["hhea"].descent * scale)
    for attr in (
        "sTypoAscender",
        "sTypoDescender",
        "sTypoLineGap",
        "usWinAscent",
        "usWinDescent",
        "sxHeight",
        "sCapHeight",
    ):
        if hasattr(font["OS/2"], attr):
            setattr(font["OS/2"], attr, int(getattr(font["OS/2"], attr) * scale))
    font.save(dst)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("src")
    parser.add_argument("dst")
    parser.add_argument("--scale", type=float, default=1.4)
    parser.add_argument("--upem", type=int, default=1400)
    args = parser.parse_args()
    scale_font(args.src, args.dst, args.scale, args.upem)
    print(f"wrote {args.dst} (upem={args.upem}, scale={args.scale})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
