#!/usr/bin/env python3
"""Remove light paper fringe from asset-catalog PNGs and defringe soft edges.

The pass only removes low-saturation, light pixels that are connected to the
transparent border and sit close to solid artwork.  Interior whites, gold
glows, sparkles and cloud/ice interiors stay untouched because they are not
reachable from the border or are too far from solid art.

Usage:
    python tools/clean_alpha.py             # clean every PNG, write check sheet
    python tools/clean_alpha.py --dry-run   # report only, change nothing
    python tools/clean_alpha.py --only tide # process matching names only
"""

from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as ndi

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "DragonIsland" / "Resources" / "Assets.xcassets"
OUT_DIR = ROOT / "tools" / "out"
CHECK_SHEET = OUT_DIR / "alpha_check.png"

SKIP_PARTS = ("AppIcon", "battle_arena_background")

# Higher level = more permissive removal.  Lower it for a sprite that loses
# detail instead of looping on global tuning.
DEFAULT_LEVEL = 0.55
LEVEL_OVERRIDES = {
    "dragon_tide": 0.62,
    "dragon_frost": 0.62,
    "dragon_breeze": 0.56,
    "dragon_spark": 0.50,
    "dragon_gleam": 0.42,
    "island_starter": 0.45,
    "habitat_ice": 0.34,
    "habitat_water": 0.34,
    "habitat_air": 0.34,
    "egg_ice": 0.34,
    "egg_water": 0.34,
    "egg_air": 0.34,
}

CHECK_NAMES = (
    "dragon_tide_idle_0",
    "dragon_frost_idle_0",
    "dragon_breeze_idle_0",
    "dragon_spark_idle_0",
    "dragon_gleam_idle_0",
    "dragon_blaze_idle_0",
    "island_starter_0",
    "habitat_ice",
    "habitat_water",
    "egg_ice",
)


def level_for(stem: str) -> float:
    for prefix, level in LEVEL_OVERRIDES.items():
        if stem.startswith(prefix):
            return level
    return DEFAULT_LEVEL


def catalog_pngs() -> list[Path]:
    paths = sorted(ASSETS.rglob("*.png"))
    return [p for p in paths if not any(part in str(p) for part in SKIP_PARTS)]


def read_rgba(path: Path) -> np.ndarray:
    image = Image.open(path)
    if image.mode != "RGBA":
        image = image.convert("RGBA")
    return np.asarray(image, dtype=np.uint8).copy()


def edge_reachable(candidate: np.ndarray, transparent: np.ndarray) -> np.ndarray:
    passable = candidate | transparent
    labels, _ = ndi.label(passable)
    border = np.zeros_like(passable, dtype=bool)
    border[0, :] = border[-1, :] = True
    border[:, 0] = border[:, -1] = True
    border_labels = np.unique(labels[border & transparent])
    border_labels = border_labels[border_labels != 0]
    return np.isin(labels, border_labels)


def thresholds(level: float) -> tuple[float, float]:
    """Return (minimum light channel, maximum saturation) for a level.

    Saturation is a 0...1 fraction, not a percentage.  Low levels only match
    near-white paper; high levels also match pale blue/green rims.
    """
    return 255.0 - 70.0 * level, 0.03 + 0.14 * level


def visible_component_sizes(rgba: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    visible = rgba[..., 3] > 8
    labels, count = ndi.label(visible)
    sizes = ndi.sum(visible, labels, range(1, count + 1))
    return labels, sizes


def fringe_mask(rgba: np.ndarray, level: float) -> np.ndarray:
    alpha = rgba[..., 3].astype(np.float32)
    rgb = rgba[..., :3].astype(np.float32)
    high, low = rgb.max(axis=2), rgb.min(axis=2)
    saturation = (high - low) / np.maximum(high, 1.0)

    min_channel, max_saturation = thresholds(level)
    candidate = (alpha > 0) & (low >= min_channel) & (saturation <= max_saturation)
    transparent = alpha <= 8

    reachable = candidate & edge_reachable(candidate, transparent)
    if not reachable.any():
        return reachable

    # Only the outer two pixels can be paper fringe.  This keeps light bodies,
    # ice/cloud interiors and wide highlights intact.
    shell = ndi.binary_dilation(transparent, iterations=2) & ~transparent
    # Detached sparkles and stars are small visible islands.  Fringe always
    # touches a large opaque sprite, so size protects the sparkles.
    labels, sizes = visible_component_sizes(rgba)
    large = np.isin(labels, np.flatnonzero(sizes >= 400) + 1)
    return reachable & shell & large


def defringe(rgba: np.ndarray, level: float, strength: float = 0.85) -> np.ndarray:
    alpha = rgba[..., 3].astype(np.float32)
    rgb = rgba[..., :3].astype(np.float32)
    high, low = rgb.max(axis=2), rgb.min(axis=2)
    saturation = (high - low) / np.maximum(high, 1.0)
    min_channel, max_saturation = thresholds(level)
    halo = (low >= min_channel) & (saturation <= max_saturation)

    transparent = alpha <= 8
    edge_band = ((alpha > 8) & (alpha < 250) & halo
                 & ndi.binary_dilation(transparent, iterations=1))

    opaque = alpha >= 250
    kernel = np.ones((3, 3), dtype=np.float32)
    count = ndi.convolve(opaque.astype(np.float32), kernel, mode="constant")
    total = np.stack([
        ndi.convolve(rgb[..., channel] * opaque, kernel, mode="constant")
        for channel in range(3)
    ], axis=-1)
    has_interior = count >= 1
    interior = total / np.maximum(count[..., None], 1.0)

    lighter = rgb.mean(axis=2) > interior.mean(axis=2) + 4.0
    weight = (1.0 - alpha / 255.0) * strength
    blended = rgb * (1.0 - weight[..., None]) + interior * weight[..., None]
    use = edge_band & has_interior & lighter
    out = rgba.copy()
    out[..., :3] = np.where(use[..., None], np.clip(blended, 0, 255), rgb).astype(np.uint8)
    return out


def clean(rgba: np.ndarray, level: float) -> tuple[np.ndarray, int]:
    removed = fringe_mask(rgba, level)
    out = rgba.copy()
    out[removed] = 0
    out = defringe(out, level)
    return out, int(removed.sum())


def checkerboard(width: int, height: int, cell: int = 16) -> Image.Image:
    dark = np.array([32, 34, 38, 255], dtype=np.uint8)
    mid = np.array([58, 61, 68, 255], dtype=np.uint8)
    tile = np.zeros((height, width, 4), dtype=np.uint8)
    for y in range(0, height, cell):
        for x in range(0, width, cell):
            tile[y:y + cell, x:x + cell] = dark if (x // cell + y // cell) % 2 else mid
    return Image.fromarray(tile, mode="RGBA")


def paste_fit(canvas: Image.Image, sprite: Image.Image, box: tuple[int, int, int, int]) -> None:
    x, y, width, height = box
    scale = min(width / max(sprite.width, 1), height / max(sprite.height, 1), 1.0)
    size = (max(1, int(sprite.width * scale)), max(1, int(sprite.height * scale)))
    resized = sprite.resize(size, Image.LANCZOS)
    canvas.alpha_composite(resized, (x + (width - size[0]) // 2,
                                     y + (height - size[1]) // 2))


def write_check_sheet(before: dict[str, np.ndarray], after: dict[str, np.ndarray]) -> None:
    names = [name for name in CHECK_NAMES if name in before]
    if not names:
        return
    cell_w, cell_h = 210, 180
    margin = 12
    header = 28
    width = margin * 3 + cell_w * 2
    height = header + margin + cell_h * len(names)
    sheet = checkerboard(width, height)
    draw = ImageDraw.Draw(sheet)
    draw.text((margin, 8), "BEFORE (left)   /   AFTER (right)", fill=(255, 235, 180, 255))
    for row, name in enumerate(names):
        top = header + margin + row * cell_h
        draw.text((margin, top + 2), name, fill=(220, 225, 235, 255))
        for column, source in enumerate((before[name], after[name])):
            left = margin + column * cell_w
            tile = checkerboard(cell_w, cell_h)
            paste_fit(tile, Image.fromarray(source, mode="RGBA"), (4, 4, cell_w - 8, cell_h - 8))
            sheet.alpha_composite(tile, (left, top + 12))
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    sheet.convert("RGB").save(CHECK_SHEET, optimize=True)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--only", default=None, help="substring filter for file names")
    args = parser.parse_args()

    paths = catalog_pngs()
    if args.only:
        paths = [p for p in paths if args.only in p.name]

    before: dict[str, np.ndarray] = {}
    after: dict[str, np.ndarray] = {}
    total_removed = 0
    warnings: list[str] = []

    for path in paths:
        rgba = read_rgba(path)
        stem = path.stem
        out, removed = clean(rgba, level_for(stem))
        total_removed += removed
        opaque = int((rgba[..., 3] > 0).sum())
        fraction = removed / max(opaque, 1)
        if fraction > 0.18:
            warnings.append(f"{stem}: removed {fraction:.0%} of visible pixels")
        if stem in CHECK_NAMES:
            before[stem] = rgba.copy()
            after[stem] = out.copy()
        if not args.dry_run and not np.array_equal(out, rgba):
            Image.fromarray(out, mode="RGBA").save(path, optimize=True)

    if not args.dry_run:
        write_check_sheet(before, after)

    print(f"Scanned {len(paths)} PNGs, removed {total_removed} fringe pixels.")
    if warnings:
        print("Large removals (review the check sheet):")
        for line in warnings:
            print(f"  {line}")
    if not args.dry_run:
        print(f"Check sheet: {CHECK_SHEET}")


if __name__ == "__main__":
    main()
