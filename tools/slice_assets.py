#!/usr/bin/env python3
"""Slice dragon_game_assets_v3.zip into transparent sprites and an Assets.xcassets catalog.

Layout comes from the archive's manifest.json.  Frame rectangles are derived by
projecting a soft alpha matte, so no sprite coordinate is hand-written.
Background haze is removed with fractional alpha and un-blended colour, which
keeps anti-aliased outlines clean instead of leaving a light halo.

Usage:
    python tools/slice_assets.py            # rebuild the catalog
    python tools/slice_assets.py --report   # print detected sheet geometry only
    python tools/slice_assets.py --keep     # keep existing imageset folders
"""

from __future__ import annotations

import argparse
import json
import re
import shutil
import sys
import zipfile
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage as ndi

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_ZIP = ROOT / "assets_input" / "dragon_game_assets_v3.zip"
WORK_DIR = ROOT / "build" / "asset_work"
ASSETS_DIR = ROOT / "DragonIsland" / "Resources" / "Assets.xcassets"
DATA_DIR = ROOT / "DragonIsland" / "Resources" / "GameData"
SEED_PATH = ROOT / "tools" / "data" / "catalog_seed.json"

DRAGON_ROWS = ("idle", "walk", "fly", "action")
DRAGON_COLS = 6
DRAGON_MIN_AREA = 600
DRAGON_NEAR_PAD = 26
ITEM_MIN_AREA = 70


# --------------------------------------------------------------------------- #
# Archive + matte
# --------------------------------------------------------------------------- #

def extract_archive(zip_path: Path) -> Path:
    """Unpack the source archive into build/asset_work and return its root folder."""
    if not zip_path.exists():
        sys.exit(f"Missing source archive: {zip_path}")
    WORK_DIR.mkdir(parents=True, exist_ok=True)
    root = WORK_DIR / "dragon_game_assets_v3"
    if not (root / "manifest.json").exists():
        with zipfile.ZipFile(zip_path) as archive:
            archive.extractall(WORK_DIR)
    return root


def read_rgb(path: Path) -> np.ndarray:
    return np.asarray(Image.open(path).convert("RGB"), dtype=np.float32)


def estimate_background(rgb: np.ndarray) -> np.ndarray:
    """Modal light colour.  Using the mode ignores painted edge shadows and
    borders that would bias a corner sample."""
    pixels = rgb.reshape(-1, 3)[::3]
    high, low = pixels.max(axis=1), pixels.min(axis=1)
    light = pixels[(high > 170) & ((high - low) < 90)]
    if len(light) < 200:
        return np.median(pixels, axis=0)
    bins = (light // 6).astype(np.int32)
    _, inverse, counts = np.unique(bins, axis=0, return_inverse=True, return_counts=True)
    return np.median(light[inverse == int(np.argmax(counts))], axis=0)


def build_matte(rgb: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    """Return (un-blended RGB, alpha in 0...1)."""
    bg = estimate_background(rgb)
    distance = np.abs(rgb - bg).max(axis=2)
    ramp = np.clip((distance - 9.0) / 46.0, 0.0, 1.0)
    alpha = ramp * ramp * (3.0 - 2.0 * ramp)

    # Fill only small enclosed gaps (eyes, pale bellies).  A global hole fill
    # would flood empty space enclosed by several sprites on one sheet.
    solid = ndi.binary_closing(alpha > 0.5, iterations=2)
    gaps = ndi.binary_fill_holes(solid) & ~solid
    labels, count = ndi.label(gaps)
    if count:
        sizes = ndi.sum(gaps, labels, range(1, count + 1))
        solid |= np.isin(labels, [i + 1 for i, size in enumerate(sizes) if size < 2500])
    alpha = np.where(ndi.binary_erosion(solid, iterations=2), 1.0, alpha)

    # Keep soft pixels only near solid art.  This drops wide painted shadows
    # and background banding while preserving anti-aliased outlines.
    near_art = ndi.binary_dilation(alpha > 0.85, iterations=3)
    alpha = np.where((alpha < 0.62) & ~near_art, 0.0, alpha)
    alpha[alpha < 0.035] = 0.0

    safe = np.maximum(alpha[..., None], 1e-4)
    unblended = np.clip((rgb - (1.0 - alpha[..., None]) * bg) / safe, 0, 255)
    unblended[alpha < 0.02] = 0.0
    return unblended.astype(np.uint8), alpha


def strip_edge_bands(rgb: np.ndarray, alpha: np.ndarray, zone: int = 64) -> np.ndarray:
    """Clear painted border shadows that contain no strong artwork."""
    strong = np.abs(rgb - estimate_background(rgb)).max(axis=2) > 90
    height, width = strong.shape
    out = alpha.copy()
    columns = list(range(min(zone, width))) + list(range(max(0, width - zone), width))
    rows = list(range(min(zone, height))) + list(range(max(0, height - zone), height))
    for x in columns:
        if strong[:, x].mean() < 0.004:
            out[:, x] = 0.0
    for y in rows:
        if strong[y].mean() < 0.004:
            out[y, :] = 0.0
    return out


def axis_runs(flags: np.ndarray, max_len: int, expand: int = 1) -> list[tuple[int, int]]:
    """Short True runs, widened by ``expand`` so a 1-2 px rule covers both edges."""
    runs, start = [], None
    for index, flag in enumerate(np.append(flags, False)):
        if flag and start is None:
            start = index
        elif not flag and start is not None:
            if index - start <= max_len:
                runs.append((max(0, start - expand), min(len(flags), index + expand)))
            start = None
    return runs


def strip_grid_lines(rgb: np.ndarray, alpha: np.ndarray) -> np.ndarray:
    """Erase thin rules and soft painted bands without cutting through sprites."""
    out = alpha.copy()
    height, width = out.shape
    solid = out > 0.45

    columns = np.zeros(width, dtype=bool)
    rows = np.zeros(height, dtype=bool)
    for start, stop in axis_runs(solid.sum(axis=0) > 0.55 * height, 3):
        columns[start:stop] = True
    for start, stop in axis_runs(solid.sum(axis=1) > 0.55 * width, 3):
        rows[start:stop] = True

    # Soft beige rules never reach full occupancy.  Flag thin columns of warm,
    # low-saturation background tone that stand out from their neighbours.
    high, low = rgb.max(axis=2), rgb.min(axis=2)
    saturation = (high - low) / np.maximum(high, 1.0)
    warm = (saturation < 0.22) & (high - low > 5) & (rgb[..., 0] >= rgb[..., 1] + 3) \
        & (rgb[..., 1] >= rgb[..., 2] + 3) & (high > 100)
    tone = warm & (out > 0.15)

    def add_soft_rules(profile: np.ndarray, target: np.ndarray) -> None:
        for start, stop in axis_runs(profile >= 0.25, 3, expand=0):
            inside = float(profile[start:stop].mean())
            outside = np.concatenate((profile[max(0, start - 6):start],
                                      profile[stop:min(len(profile), stop + 6)]))
            baseline = float(outside.mean()) if outside.size else 0.0
            if inside >= 2.0 * max(baseline, 0.01):
                target[max(0, start - 1):min(len(target), stop + 1)] = True

    add_soft_rules(tone.mean(axis=0), columns)
    add_soft_rules(tone.mean(axis=1), rows)

    # Clear only rule pixels that have no artwork on either side.  A rule that
    # crosses a sprite is covered by neighbouring solid columns and survives.
    protected = solid.copy()
    protected[:, columns] = False
    protected = ndi.binary_dilation(protected, iterations=2)
    out[columns[None, :] & ~protected] = 0.0

    protected = solid.copy()
    protected[rows, :] = False
    protected = ndi.binary_dilation(protected, iterations=2)

    # A wide band can defeat the dilation above, so test each candidate row
    # directly: artwork just above and below the same column means the band
    # crosses a sprite and every pixel in that band must survive.
    crossing = np.zeros_like(solid)
    for start, stop in axis_runs(rows, len(rows), expand=0):
        above = solid[max(0, start - 5):start].any(axis=0)
        below = solid[stop:min(len(rows), stop + 5)].any(axis=0)
        crossing[start:stop] = (above & below)[None, :]
    out[rows[:, None] & ~protected & ~crossing] = 0.0
    return out


def strip_dragon_labels(rgba: np.ndarray, alpha: np.ndarray) -> None:
    """Remove titles and row labels that sit in the gaps between sprite rows."""
    rows = detect_rows(alpha)
    if not rows:
        return
    mask = alpha > 0.35
    labels, count = ndi.label(mask)
    if count == 0:
        return
    sizes = ndi.sum(mask, labels, range(1, count + 1))

    def label_band(ys) -> int | None:
        """Gap whose text row this component belongs to, if any."""
        for index, (row_top, _) in enumerate(rows):
            gap_start = 0 if index == 0 else rows[index - 1][1] + 1
            if ys.start >= gap_start - 2 and ys.stop <= row_top + 9:
                return index
        return None

    # Label whole components so glyphs that dip into a row are removed in one
    # piece, while large artwork stays merged and is skipped by the area test.
    for index, sl in enumerate(ndi.find_objects(labels)):
        ys, xs = sl
        area = int(sizes[index])
        height = ys.stop - ys.start
        if area < 30 or height < 7 or area >= 2500 or height >= 80:
            continue
        band = label_band(ys)
        if band is None:
            continue
        if band == 0:
            # Labels that dip into the first row stay left of the artwork.
            margin = 115 if ys.stop > rows[0][0] else 140
            if xs.start >= margin and ys.stop > rows[0][0] - 4:
                continue
        elif xs.start >= 140:
            continue
        core = labels[ys, xs] == index + 1
        pixels = rgba[ys, xs][core].astype(np.float32)
        high = pixels.max(axis=1)
        saturation = ((high - pixels.min(axis=1)) / np.maximum(high, 1.0)).mean()
        if saturation >= 0.55 or high.mean() >= 180:
            continue
        height, width = mask.shape
        py0, py1 = max(0, ys.start - 3), min(height, ys.stop + 3)
        px0, px1 = max(0, xs.start - 3), min(width, xs.stop + 3)
        patch_core = labels[py0:py1, px0:px1] == index + 1
        patch_alpha = alpha[py0:py1, px0:px1]
        patch_color = rgba[py0:py1, px0:px1]
        region = patch_core | (ndi.binary_dilation(patch_core, iterations=4) & (patch_alpha < 0.5))
        patch_alpha[region] = 0.0
        patch_color[region] = 0


def strip_caption_labels(rgba: np.ndarray, alpha: np.ndarray, min_height: int = 80,
                         art_area: int = 15000, max_area: int = 2500) -> None:
    """Clear sheet titles printed in the space above each row of island art."""
    rows = detect_rows(alpha, min_height)
    if not rows:
        return
    mask = alpha > 0.35
    labels, count = ndi.label(mask)
    if count == 0:
        return
    sizes = ndi.sum(mask, labels, range(1, count + 1))
    slices = ndi.find_objects(labels)
    tops = []
    for y0, y1 in rows:
        art = [sl[0].start for i, sl in enumerate(slices)
               if sizes[i] >= art_area and sl[0].stop > y0 and sl[0].start < y1]
        tops.append(min(art) if art else y0)
    regions = [(0, tops[0])]
    regions += [(rows[i][1] + 1, tops[i + 1]) for i in range(len(rows) - 1)]
    for y0, y1 in regions:
        if y1 <= y0:
            continue
        labels, _ = ndi.label(alpha[y0:y1] > 0.35)
        for index, sl in enumerate(ndi.find_objects(labels)):
            ys, xs = sl
            area = int((labels[ys, xs] == index + 1).sum())
            height = ys.stop - ys.start
            if area < 25 or area > max_area or height > 60:
                continue
            core = labels[ys, xs] == index + 1
            pixels = rgba[y0 + ys.start:y0 + ys.stop, xs.start:xs.stop][core].astype(np.float32)
            high = pixels.max(axis=1)
            saturation = ((high - pixels.min(axis=1)) / np.maximum(high, 1.0)).mean()
            if saturation >= 0.55 or high.mean() >= 180:
                continue
            height, width = labels.shape
            py0, py1 = max(0, ys.start - 4), min(height, ys.stop + 4)
            px0, px1 = max(0, xs.start - 4), min(width, xs.stop + 4)
            patch_core = labels[py0:py1, px0:px1] == index + 1
            patch_alpha = alpha[y0 + py0:y0 + py1, px0:px1]
            patch_color = rgba[y0 + py0:y0 + py1, px0:px1]
            region = patch_core | (ndi.binary_dilation(patch_core, iterations=6) & (patch_alpha < 0.5))
            patch_alpha[region] = 0.0
            patch_color[region] = 0


def sheet_matte(asset_root: Path, relative_path: str) -> tuple[np.ndarray, np.ndarray]:
    rgb = read_rgb(asset_root / relative_path)
    rgba, alpha = build_matte(rgb)
    return rgba, strip_grid_lines(rgb, strip_edge_bands(rgb, alpha))


# --------------------------------------------------------------------------- #
# Geometry
# --------------------------------------------------------------------------- #

def profile_bands(profile: np.ndarray, threshold: float, min_gap: int, min_size: int) -> list[tuple[int, int]]:
    bands: list[list[int]] = []
    start = last = None
    for index, value in enumerate(profile):
        if value > threshold:
            if start is None:
                start = index
            last = index
        elif start is not None and index - last >= min_gap:
            bands.append([start, last])
            start = None
    if start is not None:
        bands.append([start, last])
    return [(a, b) for a, b in bands if b - a + 1 >= min_size]


def detect_rows(alpha: np.ndarray, min_height: int = 60) -> list[tuple[int, int]]:
    """Rows with real sprite mass; title and label text fall below the threshold."""
    occupancy = (alpha > 0.30).sum(axis=1)
    threshold = max(12, int(alpha.shape[1] * 0.045))
    return profile_bands(occupancy, threshold=threshold, min_gap=12, min_size=min_height)


def detect_cols(alpha: np.ndarray, row: tuple[int, int], min_width: int = 28) -> list[tuple[int, int]]:
    occupancy = (alpha[row[0]:row[1] + 1] > 0.30).sum(axis=0)
    return profile_bands(occupancy, threshold=4, min_gap=16, min_size=min_width)


def nominal_splits(start: int, end: int, count: int) -> list[tuple[int, int]]:
    step = (end - start) / count
    return [(round(start + i * step), round(start + (i + 1) * step)) for i in range(count)]


def content_extent(alpha: np.ndarray, axis: int) -> tuple[int, int]:
    hits = np.flatnonzero((alpha > 0.22).sum(axis=axis) > 1)
    if len(hits) == 0:
        return 0, alpha.shape[axis] - 1
    return int(hits[0]), int(hits[-1])


def column_centers(alpha: np.ndarray, rows: list[tuple[int, int]], expected: int) -> list[float]:
    """Median of clean per-row centres; action effects cannot skew the grid."""
    samples, every_band = [], []
    for row in rows:
        cols = detect_cols(alpha, row)
        every_band.extend(cols)
        if len(cols) == expected:
            samples.append([(a + b) / 2 for a, b in cols])
    if samples:
        return list(np.median(np.array(samples), axis=0))
    if every_band:
        left, right = min(a for a, _ in every_band), max(b for _, b in every_band)
    else:
        left, right = content_extent(alpha, axis=1)
    step = (right - left) / expected
    return [left + step * (i + 0.5) for i in range(expected)]


# --------------------------------------------------------------------------- #
# Crops
# --------------------------------------------------------------------------- #

def paste_box(image: np.ndarray, box: tuple[int, int, int, int]) -> np.ndarray:
    """Copy an arbitrary (possibly off-sheet) rectangle into a fresh array."""
    x, y, width, height = box
    shape = (height, width, image.shape[2]) if image.ndim == 3 else (height, width)
    out = np.zeros(shape, dtype=image.dtype)
    x0, y0 = max(0, x), max(0, y)
    x1, y1 = min(image.shape[1], x + width), min(image.shape[0], y + height)
    if x1 > x0 and y1 > y0:
        out[y0 - y:y1 - y, x0 - x:x1 - x] = image[y0:y1, x0:x1]
    return out


def content_bbox(alpha: np.ndarray, min_area: int, near_pad: int | None = None) -> tuple[int, int, int, int] | None:
    """Union of sizeable components.  ``near_pad`` keeps only parts close to the
    largest blob, which drops stray label glyphs from animation frames."""
    mask = alpha > 0.35
    labels, count = ndi.label(mask)
    if count == 0:
        return None
    sizes = ndi.sum(mask, labels, range(1, count + 1))
    slices = ndi.find_objects(labels)
    boxes = [
        (int(sl[1].start), int(sl[0].start), int(sl[1].stop), int(sl[0].stop))
        for i, sl in enumerate(slices) if sizes[i] >= min_area
    ]
    if not boxes:
        return None
    if near_pad is not None:
        big = max(boxes, key=lambda b: (b[2] - b[0]) * (b[3] - b[1]))
        near = (big[0] - near_pad, big[1] - near_pad, big[2] + near_pad, big[3] + near_pad)
        boxes = [b for b in boxes if b[0] < near[2] and b[2] > near[0] and b[1] < near[3] and b[3] > near[1]]
    return (min(b[0] for b in boxes), min(b[1] for b in boxes),
            max(b[2] for b in boxes), max(b[3] for b in boxes))


def union_rect(rects: list[tuple[int, int, int, int]]) -> tuple[int, int, int, int]:
    return (min(r[0] for r in rects), min(r[1] for r in rects),
            max(r[2] for r in rects), max(r[3] for r in rects))


def rgba_image(rgb: np.ndarray, alpha: np.ndarray) -> Image.Image:
    stack = np.dstack([rgb, np.clip(alpha * 255.0, 0, 255).astype(np.uint8)])
    return Image.fromarray(stack, mode="RGBA")


# --------------------------------------------------------------------------- #
# Slicing
# --------------------------------------------------------------------------- #

def slice_animated(rgba: np.ndarray, alpha: np.ndarray, row_count: int, col_count: int,
                   name_for, min_row_height: int = 60) -> tuple[list, tuple[int, int]]:
    """Cut an animated sheet.  Every frame shares one canvas, so swapping
    textures in SpriteKit never makes the character jitter."""
    rows = detect_rows(alpha, min_row_height)
    if len(rows) != row_count:
        top, bottom = content_extent(alpha, axis=0)
        rows = nominal_splits(top, bottom + 1, row_count)

    centers = column_centers(alpha, rows, col_count)
    spacing = int(round(float(np.median(np.diff(centers))))) if col_count > 1 else alpha.shape[1]
    left = int(round(centers[0] - spacing / 2))
    canvas_h = max(b - a + 1 for a, b in rows) + 2

    cells, rects = [], []
    for row_index, (_, row_bottom) in enumerate(rows):
        top = row_bottom + 1 - canvas_h
        for col_index in range(col_count):
            box = (left + col_index * spacing, top, spacing, canvas_h)
            bbox = content_bbox(paste_box(alpha[..., None], box)[..., 0], DRAGON_MIN_AREA, DRAGON_NEAR_PAD)
            bbox = bbox or (0, 0, spacing, canvas_h)
            rects.append((max(0, bbox[0] - 5), max(0, bbox[1] - 5),
                          min(spacing, bbox[2] + 5), min(canvas_h, bbox[3] + 5)))
            cells.append((row_index, col_index, box))

    shared = union_rect(rects)
    # Inset by three pixels: generated sheets draw a 1-2 px rule on cell
    # boundaries, and it must not become a stripe on a frame edge.
    shared = (shared[0] + 3, shared[1] + 3, shared[2] - 3, shared[3] - 3)
    if shared[2] - shared[0] < 8 or shared[3] - shared[1] < 8:
        shared = union_rect(rects)
    crop = (slice(shared[1], shared[3]), slice(shared[0], shared[2]))

    frames = []
    for row_index, col_index, box in cells:
        rgb_box = paste_box(rgba, box)
        alpha_box = paste_box(alpha[..., None], box)[..., 0]
        frames.append((name_for(row_index, col_index), rgba_image(rgb_box[crop], alpha_box[crop])))
    return frames, (shared[2] - shared[0], shared[3] - shared[1])


def slice_items(rgba: np.ndarray, alpha: np.ndarray, row_bands: list[tuple[int, int]],
                cols_per_row: list[int], names_per_row: list[list[str]],
                near_pad: int | None = None) -> list:
    """Tightly crop independent world/UI sprites, one per cell."""
    frames = []
    for row, ncols, names in zip(row_bands, cols_per_row, names_per_row):
        cols = detect_cols(alpha, row)
        if len(cols) != ncols:
            band = alpha[row[0]:row[1] + 1]
            hits = np.flatnonzero((band > 0.22).sum(axis=0) > 1)
            cols = nominal_splits(int(hits[0]), int(hits[-1]) + 1, ncols)
        for (x0, x1), name in zip(cols, names):
            box = (x0, row[0], x1 - x0 + 1, row[1] - row[0] + 1)
            rgb_box = paste_box(rgba, box)
            alpha_box = paste_box(alpha[..., None], box)[..., 0]
            bbox = content_bbox(alpha_box, ITEM_MIN_AREA, near_pad) or (0, 0, box[2], box[3])
            crop = (slice(max(0, bbox[1] - 4), min(box[3], bbox[3] + 4)),
                    slice(max(0, bbox[0] - 4), min(box[2], bbox[2] + 4)))
            frames.append((name, rgba_image(rgb_box[crop], alpha_box[crop])))
    return frames


# --------------------------------------------------------------------------- #
# Catalog writing
# --------------------------------------------------------------------------- #

def write_json(path: Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def write_color_set(name: str, hex_color: str) -> None:
    value = hex_color.lstrip("#")
    red, green, blue = (int(value[i:i + 2], 16) / 255.0 for i in (0, 2, 4))
    folder = ASSETS_DIR / f"{name}.colorset"
    folder.mkdir(parents=True, exist_ok=True)
    write_json(folder / "Contents.json", {
        "colors": [{
            "color": {"color-space": "srgb", "components": {
                "red": f"{red:.3f}", "green": f"{green:.3f}", "blue": f"{blue:.3f}", "alpha": "1.000"}},
            "idiom": "universal",
        }],
        "info": {"author": "dragon-island-slicer", "version": 1},
    })


def reset_catalog(force: bool) -> None:
    if force and ASSETS_DIR.exists():
        shutil.rmtree(ASSETS_DIR)
    ASSETS_DIR.mkdir(parents=True, exist_ok=True)
    write_json(ASSETS_DIR / "Contents.json", {"info": {"author": "dragon-island-slicer", "version": 1}})
    for group in ("Dragons", "World", "UI"):
        write_json(ASSETS_DIR / group / "Contents.json", {"info": {"author": "dragon-island-slicer", "version": 1}})
    write_color_set("LaunchBackground", "#7FCBE8")
    write_color_set("AccentColor", "#F26B3A")


def save_imageset(name: str, image: Image.Image, group: str) -> None:
    folder = ASSETS_DIR / group / f"{name}.imageset"
    folder.mkdir(parents=True, exist_ok=True)
    image.save(folder / f"{name}.png", optimize=True)
    write_json(folder / "Contents.json", {
        "images": [{"filename": f"{name}.png", "idiom": "universal", "scale": "1x"}],
        "info": {"author": "dragon-island-slicer", "version": 1},
    })


def save_frames(frames, group: str) -> list[str]:
    for name, image in frames:
        save_imageset(name, image, group)
    return [name for name, _ in frames]


# --------------------------------------------------------------------------- #
# Export steps
# --------------------------------------------------------------------------- #

def export_dragons(asset_root: Path, manifest: dict) -> dict:
    states = DRAGON_ROWS
    fps = {"idle": 6, "walk": 8, "fly": 10, "action": 8}
    entries = {}
    for sheet in manifest["dragons"]["sheets"]:
        dragon_id = sheet["id"]
        rgba, alpha = sheet_matte(asset_root, sheet["file"])
        strip_dragon_labels(rgba, alpha)
        frames, (width, height) = slice_animated(
            rgba, alpha, len(states), DRAGON_COLS,
            lambda row, col, did=dragon_id: f"dragon_{did}_{states[row]}_{col}",
        )
        animations = {state: [] for state in states}
        for index, (name, image) in enumerate(frames):
            save_imageset(name, image, "Dragons")
            animations[states[index // DRAGON_COLS]].append(name)
        entries[dragon_id] = {
            "element": sheet["element"].lower(),
            "frameSize": {"width": width, "height": height},
            "animations": {state: {"frames": animations[state], "fps": fps[state], "loop": state != "action"}
                           for state in states},
        }
        print(f"  dragon {dragon_id:<8} {width}x{height}  {len(frames)} frames")
    return entries


def parse_layout(text: str) -> tuple[int, int]:
    numbers = [int(value) for value in re.findall(r"\d+", text)]
    return numbers[1], numbers[0]  # (columns, rows)


def rows_or_nominal(alpha: np.ndarray, expected: int, min_height: int = 60) -> list[tuple[int, int]]:
    rows = detect_rows(alpha, min_height)
    if len(rows) != expected:
        top, bottom = content_extent(alpha, axis=0)
        rows = nominal_splits(top, bottom + 1, expected)
    return rows


def export_world(asset_root: Path, manifest: dict) -> dict:
    world_cfg = manifest["world"]
    textures = {"habitats": {}, "eggs": {}, "buildings": {}, "farmStages": [], "indicators": []}

    island = world_cfg["starter_island"]
    rgba, alpha = sheet_matte(asset_root, island["file"])
    strip_caption_labels(rgba, alpha)
    island_frames, _ = slice_animated(
        rgba, alpha, 2, 3, lambda r, c: f"island_starter_{r * 3 + c}", min_row_height=80)
    island_names = save_frames(island_frames, "World")

    arena = world_cfg["battle_arena"]
    save_imageset("battle_arena_background", Image.open(asset_root / arena["file"]).convert("RGB"), "World")

    for habitat_sheet in world_cfg["habitats"]:
        cols, rows = parse_layout(habitat_sheet["layout"])
        elements = habitat_sheet["elements"]
        rgba, alpha = sheet_matte(asset_root, habitat_sheet["file"])
        bands = rows_or_nominal(alpha, rows)
        names = [f"habitat_{element}" for element in elements]
        save_frames(slice_items(rgba, alpha, bands, [cols] * rows,
                                [names[i:i + cols] for i in range(0, len(names), cols)]), "World")
        textures["habitats"].update(zip(elements, names))

    eggs_cfg = world_cfg["buildings_and_eggs"]
    eggs, buildings = eggs_cfg["eggs_section"], eggs_cfg["buildings_section"]
    eggs_cols, eggs_rows = parse_layout(eggs["layout"])
    build_cols, build_rows = parse_layout(buildings["layout"])
    rgba, alpha = sheet_matte(asset_root, eggs_cfg["file"])
    bands = rows_or_nominal(alpha, eggs_rows + build_rows, min_height=80)
    egg_names = [f"egg_{element}" for element in eggs["elements"]]
    save_frames(slice_items(rgba, alpha, bands[:eggs_rows], [eggs_cols] * eggs_rows,
                            [egg_names[i:i + eggs_cols] for i in range(0, len(egg_names), eggs_cols)],
                            near_pad=5), "World")
    textures["eggs"].update(zip(eggs["elements"], egg_names))
    building_names = [f"building_{name}" for name in buildings["buildings"]]
    save_frames(slice_items(rgba, alpha, bands[eggs_rows:], [build_cols] * build_rows, [building_names]), "World")
    textures["buildings"].update({name: f"building_{name}" for name in buildings["buildings"]})

    markers_cfg = world_cfg["buildings_and_markers"]
    rgba, alpha = sheet_matte(asset_root, markers_cfg["file"])
    bands = rows_or_nominal(alpha, len(markers_cfg["rows"]))
    prefixes = ["farm_", "building_", "indicator_"]
    marker_names = [[prefix + item for item in row["items"]]
                    for prefix, row in zip(prefixes, markers_cfg["rows"])]
    save_frames(slice_items(rgba, alpha, bands, [len(names) for names in marker_names], marker_names), "World")
    textures["farmStages"] = marker_names[0]
    textures["buildings"].update({name.replace("building_", ""): name for name in marker_names[1]})
    textures["indicators"] = marker_names[2]

    return {
        "world": {"starter_island": {"frames": island_names, "fps": 4, "loop": True}},
        "textures": textures,
        "island_frames": island_frames,
    }


def export_ui(asset_root: Path, manifest: dict) -> dict:
    icons_cfg = manifest["ui"]["ui_icons"]
    _, icon_rows = parse_layout(icons_cfg["layout"])
    rgba, alpha = sheet_matte(asset_root, icons_cfg["file"])
    icon_names = [[f"icon_{name}" for name in row] for row in icons_cfg["rows"]]
    save_frames(slice_items(rgba, alpha, rows_or_nominal(alpha, icon_rows),
                            [len(row) for row in icon_names], icon_names), "UI")

    badges_cfg = manifest["ui"]["element_badges"]
    badge_cols, badge_rows = parse_layout(badges_cfg["layout"])
    rgba, alpha = sheet_matte(asset_root, badges_cfg["file"])
    badge_names = [f"badge_{element}" for element in badges_cfg["elements"]]
    save_frames(slice_items(rgba, alpha, rows_or_nominal(alpha, badge_rows), [badge_cols] * badge_rows,
                            [badge_names[i:i + badge_cols] for i in range(0, len(badge_names), badge_cols)]), "UI")
    return {"icons": [name for row in icon_names for name in row], "badges": badge_names}


def build_app_icon(frames, catalog_path: Path) -> None:
    island = next(image for name, image in frames if name.endswith("_0")).copy()
    scale = 820 / max(island.width, 1)
    island = island.resize((max(1, round(island.width * scale)), max(1, round(island.height * scale))),
                           Image.LANCZOS)
    gradient = np.zeros((1024, 1024, 4), dtype=np.uint8)
    top, bottom = np.array([126, 206, 238]), np.array([247, 231, 186])
    for y in range(1024):
        t = y / 1023
        gradient[y, :, :3] = (top * (1 - t) + bottom * t).astype(np.uint8)
    gradient[..., 3] = 255
    icon = Image.fromarray(gradient, mode="RGBA")
    icon.alpha_composite(island, ((1024 - island.width) // 2, 1024 - island.height - 70))
    folder = catalog_path / "AppIcon.appiconset"
    folder.mkdir(parents=True, exist_ok=True)
    icon.convert("RGB").save(folder / "AppIcon-1024.png", optimize=True)
    write_json(folder / "Contents.json", {
        "images": [{"filename": "AppIcon-1024.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"}],
        "info": {"author": "dragon-island-slicer", "version": 1},
    })


def build_catalog(manifest: dict) -> dict:
    seed = json.loads(SEED_PATH.read_text(encoding="utf-8"))
    order = [sheet["element"].lower() for sheet in manifest["dragons"]["sheets"]]
    dragon_seed = {dragon["id"]: dragon for dragon in seed["dragons"]}

    elements = [{
        "id": element,
        "displayName": seed["elements"][element]["displayName"],
        "colorHex": seed["elements"][element]["colorHex"],
        "badgeTexture": f"badge_{element}",
        "habitatTexture": f"habitat_{element}",
        "habitatName": seed["elements"][element]["habitatName"],
        "habitatCapacity": seed["elements"][element]["habitatCapacity"],
        "habitatCost": seed["elements"][element]["habitatCost"],
    } for element in order]

    dragons = [{
        "id": sheet["id"],
        "displayName": dragon_seed[sheet["id"]]["displayName"],
        "element": sheet["element"].lower(),
        "rarity": "starter",
        "actionName": sheet["action_name"],
        "spritePrefix": f"dragon_{sheet['id']}",
        "baseHealth": dragon_seed[sheet["id"]]["baseHealth"],
        "baseAttack": dragon_seed[sheet["id"]]["baseAttack"],
        "baseDefense": dragon_seed[sheet["id"]]["baseDefense"],
        "baseSpeed": dragon_seed[sheet["id"]]["baseSpeed"],
    } for sheet in manifest["dragons"]["sheets"]]

    habitats = [{
        "id": f"habitat_{element}",
        "element": element,
        "displayName": seed["elements"][element]["habitatName"],
        "texture": f"habitat_{element}",
        "capacity": seed["elements"][element]["habitatCapacity"],
        "buildCost": seed["elements"][element]["habitatCost"],
        "unlockLevel": seed["elements"][element]["unlockLevel"],
        "goldPerHour": seed["elements"][element]["goldPerHour"],
        "goldCap": seed["elements"][element]["goldCap"],
    } for element in order]

    return {
        "schemaVersion": 1,
        "economy": seed["economy"],
        "elementOrder": order,
        "elements": elements,
        "dragons": dragons,
        "habitats": habitats,
        "buildings": seed["buildings"],
        "starterLayout": seed["starterLayout"],
        "starterDragons": seed["starterDragons"],
    }


def report(asset_root: Path, manifest: dict) -> None:
    for sheet in manifest["dragons"]["sheets"]:
        _, alpha = sheet_matte(asset_root, sheet["file"])
        rows = detect_rows(alpha)
        print(f"\n{sheet['id']}: rows={len(rows)}")
        for row in rows:
            cols = detect_cols(alpha, row)
            print(f"  y={row}  cols={len(cols)}  centres={[round((a + b) / 2) for a, b in cols]}")
    for key in ("starter_island", "habitats", "buildings_and_eggs", "buildings_and_markers"):
        entries = manifest["world"][key]
        for item in entries if isinstance(entries, list) else [entries]:
            _, alpha = sheet_matte(asset_root, item["file"])
            rows = detect_rows(alpha)
            print(f"{item['file']}: rows={len(rows)} cols={[len(detect_cols(alpha, r)) for r in rows]}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--zip", type=Path, default=DEFAULT_ZIP)
    parser.add_argument("--report", action="store_true", help="print detected geometry and exit")
    parser.add_argument("--keep", action="store_true", help="keep existing imageset folders")
    args = parser.parse_args()

    asset_root = extract_archive(args.zip)
    manifest = json.loads((asset_root / "manifest.json").read_text(encoding="utf-8"))
    if args.report:
        report(asset_root, manifest)
        return

    reset_catalog(force=not args.keep)
    print("Slicing dragons...")
    dragons = export_dragons(asset_root, manifest)
    print("Slicing world...")
    world = export_world(asset_root, manifest)
    print("Slicing UI...")
    ui = export_ui(asset_root, manifest)

    write_json(DATA_DIR / "sprite_manifest.json", {
        "schemaVersion": 1,
        "dragons": dragons,
        "world": world["world"],
        "textures": world["textures"],
        "ui": ui,
    })
    write_json(DATA_DIR / "starter_catalog.json", build_catalog(manifest))
    print("Building app icon...")
    build_app_icon(world["island_frames"], ASSETS_DIR)
    print(f"Done. Asset catalog: {ASSETS_DIR}")


if __name__ == "__main__":
    main()
