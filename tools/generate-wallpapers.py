#!/usr/bin/env python3
"""Generate the Windows XP wallpaper set procedurally.

No third-party Python modules are required: the script builds every image with
numpy and encodes PNG itself (zlib + struct). Output is written to
`backgrounds/` next to the repository root, or to the directory given as the
first argument.

    python3 tools/generate-wallpapers.py [output-dir]

Every wallpaper is regenerated deterministically from a fixed seed, so a rerun
produces byte-identical files.
"""

import math
import os
import struct
import sys
import zlib

import numpy as np

WIDTH = 2560
HEIGHT = 1440


# --------------------------------------------------------------------------
# PNG writer
# --------------------------------------------------------------------------
def _chunk(tag, data):
    return (
        struct.pack(">I", len(data))
        + tag
        + data
        + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
    )


def write_png(path, rgb):
    height, width, _ = rgb.shape
    raw = bytearray()
    for row in np.ascontiguousarray(rgb).reshape(height, width * 3):
        raw.append(0)  # filter type 0 (None)
        raw += row.tobytes()

    header = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
    payload = (
        b"\x89PNG\r\n\x1a\n"
        + _chunk(b"IHDR", header)
        + _chunk(b"IDAT", zlib.compress(bytes(raw), 9))
        + _chunk(b"IEND", b"")
    )
    with open(path, "wb") as handle:
        handle.write(payload)


# --------------------------------------------------------------------------
# noise helpers
# --------------------------------------------------------------------------
def value_noise(rng, height, width, cells_y, cells_x):
    """Smooth noise built from a coarse random grid and bicubic upsampling."""
    grid = rng.random((cells_y + 2, cells_x + 2)).astype(np.float32)
    ys = np.linspace(0, cells_y, height, dtype=np.float32)
    xs = np.linspace(0, cells_x, width, dtype=np.float32)

    # The upper edge is clamped to the last full cell, so the +1 lookups below
    # always land inside the grid.
    y0 = np.minimum(np.floor(ys).astype(np.int32), cells_y)
    x0 = np.minimum(np.floor(xs).astype(np.int32), cells_x)
    ty = (ys - y0)[:, None]
    tx = (xs - x0)[None, :]

    # Smoothstep interpolation keeps the result free of grid-aligned creases.
    sy = ty * ty * (3.0 - 2.0 * ty)
    sx = tx * tx * (3.0 - 2.0 * tx)

    a = grid[np.ix_(y0, x0)]
    b = grid[np.ix_(y0, x0 + 1)]
    c = grid[np.ix_(y0 + 1, x0)]
    d = grid[np.ix_(y0 + 1, x0 + 1)]

    top = a * (1.0 - sx) + b * sx
    bottom = c * (1.0 - sx) + d * sx
    return top * (1.0 - sy) + bottom * sy


def fbm(rng, height, width, octaves, base_cells, gain=0.5, lacunarity=2.0):
    """Fractal brownian motion: octaves of value noise, normalised to 0..1."""
    total = np.zeros((height, width), dtype=np.float32)
    amplitude = 1.0
    norm = 0.0
    cells = float(base_cells)

    for _ in range(octaves):
        cells_y = max(1, int(round(cells * height / width)))
        total += amplitude * value_noise(rng, height, width, max(1, cells_y), max(1, int(cells)))
        norm += amplitude
        amplitude *= gain
        cells *= lacunarity

    return total / norm


def vertical_gradient(stops, height, width):
    """Build a vertical gradient image from [(position, (r, g, b)), ...]."""
    positions = np.array([s[0] for s in stops], dtype=np.float32)
    colors = np.array([s[1] for s in stops], dtype=np.float32)
    t = np.linspace(0.0, 1.0, height, dtype=np.float32)

    out = np.zeros((height, 3), dtype=np.float32)
    for channel in range(3):
        out[:, channel] = np.interp(t, positions, colors[:, channel])
    return np.repeat(out[:, None, :], width, axis=1)


def smoothstep(edge0, edge1, x):
    t = np.clip((x - edge0) / (edge1 - edge0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def to_uint8(image):
    return np.clip(image, 0.0, 255.0).astype(np.uint8)


def shade(base, factor):
    """Multiply an (H, W, 3) image by a per-pixel (H, W) or scalar factor."""
    if np.isscalar(factor):
        return base * factor
    return base * factor[:, :, None]


# --------------------------------------------------------------------------
# wallpapers
# --------------------------------------------------------------------------
def bliss(rng):
    """Rolling green hill under a deep blue sky with cumulus clouds."""
    height, width = HEIGHT, WIDTH

    sky = vertical_gradient(
        [
            (0.00, (36, 84, 168)),
            (0.22, (64, 116, 202)),
            (0.45, (110, 160, 226)),
            (0.62, (163, 199, 240)),
            (0.74, (214, 231, 248)),
            (0.84, (236, 243, 252)),
            (1.00, (246, 249, 253)),
        ],
        height,
        width,
    )

    ys = np.linspace(0.0, 1.0, height, dtype=np.float32)[:, None]
    xs = np.linspace(0.0, 1.0, width, dtype=np.float32)[None, :]

    # One broad cloud mass in the middle band, thinning towards the horizon.
    cloud_field = fbm(rng, height, width, octaves=6, base_cells=5)
    cloud_field = cloud_field * 1.35 - 0.18
    cloud_field *= np.exp(-((ys - 0.46) ** 2) / (2 * 0.20 ** 2))
    cloud_field *= 1.0 - smoothstep(0.60, 0.80, ys) * 0.92

    # Fine detail clouds layered on top of the mass for a photographic look.
    detail = fbm(rng, height, width, octaves=5, base_cells=24)
    detail *= np.exp(-((ys - 0.40) ** 2) / (2 * 0.22 ** 2))
    cloud_field = np.clip(cloud_field + detail * 0.22, 0.0, 1.0)

    cloud = smoothstep(0.36, 0.72, cloud_field)

    # Lit tops and shadowed undersides give the cumulus its volume.
    underside = smoothstep(0.30, 0.62, cloud_field) * (1.0 - cloud)
    sky = sky * (1.0 - cloud[:, :, None] * 0.04)
    sky += cloud[:, :, None] * np.array([250.0, 251.0, 253.0], dtype=np.float32) * 0.95
    sky -= underside[:, :, None] * np.array([54.0, 58.0, 70.0], dtype=np.float32)

    # Hill silhouette: a rolling ridgeline with fractal detail, sloping down to
    # the right, exactly like the hillside in the reference photograph.
    horizon = (
        0.615
        + 0.052 * np.sin(xs * math.pi * 1.15 + 0.35)
        + 0.020 * np.sin(xs * math.pi * 3.1 + 1.9)
        + 0.014 * (xs - 0.5)
    )
    ridge_noise = fbm(rng, 1, width, octaves=5, base_cells=9)[0] * 0.028
    horizon = (horizon + ridge_noise)[None, :]

    hill_mask = smoothstep(horizon - 0.0025, horizon + 0.0025, ys).reshape(height, width, 1)

    # Grass colour: sunlit green near the crest, deepening towards the camera.
    depth = np.clip((ys - horizon) / (1.0 - horizon + 1e-6), 0.0, 1.0)
    depth = depth.reshape(height, width)[:, :, None]
    grass_near = np.array([92.0, 132.0, 40.0], dtype=np.float32)
    grass_mid = np.array([133.0, 173.0, 58.0], dtype=np.float32)
    grass_far = np.array([152.0, 189.0, 74.0], dtype=np.float32)
    grass = (
        grass_far * (1.0 - depth) ** 1.6
        + grass_mid * depth * (1.0 - depth) * 2.6
        + grass_near * depth ** 1.5
    )
    grass = np.clip(grass, 0.0, 255.0)

    # Blade-scale texture plus a few broad tonal patches.
    blades = fbm(rng, height, width, octaves=7, base_cells=90)
    patches = fbm(rng, height, width, octaves=3, base_cells=4)
    blade_factor = 0.86 + blades * 0.30
    patch_factor = 0.90 + patches * 0.22
    grass = shade(grass, blade_factor * patch_factor)

    # Sunlit crest: bright right above the ridgeline, darkening as it falls away.
    crest = np.exp(-depth[:, :, 0] * 6.0)
    grass += crest[:, :, None] * np.array([30.0, 34.0, 12.0], dtype=np.float32)

    # Atmospheric perspective haze along the ridgeline.
    haze = np.exp(-depth[:, :, 0] * 22.0)
    grass = grass * (1.0 - haze[:, :, None] * 0.25) + np.array([196.0, 214.0, 232.0], dtype=np.float32) * haze[:, :, None] * 0.25

    # Soft contact shadow where the hill meets the sky.
    contact = np.exp(-((ys - horizon) ** 2) / (2 * 0.006 ** 2)).reshape(height, width, 1)
    outline = contact * hill_mask

    image = sky * (1.0 - hill_mask) + np.clip(grass, 0.0, 255.0) * hill_mask
    image -= outline * np.array([10.0, 16.0, 26.0], dtype=np.float32)

    # Gentle vignette so the corners do not compete with the centre.
    vignette = 1.0 - 0.10 * (
        ((xs - 0.5) ** 2 / 0.25 + (ys - 0.5) ** 2 / 0.25) ** 1.3
    )
    image *= np.clip(vignette[:, :, None], 0.0, 1.0)
    return to_uint8(image)


def azul(rng):
    """Deep blue abstract swirl, in the spirit of the XP 'Azul' wallpaper."""
    height, width = HEIGHT, WIDTH
    ys = np.linspace(0.0, 1.0, height, dtype=np.float32)[:, None]
    xs = np.linspace(0.0, 1.0, width, dtype=np.float32)[None, :]

    base = vertical_gradient(
        [
            (0.00, (10, 24, 74)),
            (0.40, (22, 62, 148)),
            (0.70, (14, 40, 104)),
            (1.00, (8, 18, 56)),
        ],
        height,
        width,
    )

    wave = (
        np.sin(xs * 9.0 + ys * 6.0)
        + 0.7 * np.sin(xs * 17.0 - ys * 11.0 + 1.3)
        + 0.5 * np.cos((xs + ys) * 24.0)
    ) / 2.2
    sheen = smoothstep(-0.15, 0.9, wave)
    noise = fbm(rng, height, width, octaves=5, base_cells=6)
    sheen = np.clip(sheen * 0.75 + noise * 0.35, 0.0, 1.0)

    image = base * (1.0 - sheen[:, :, None] * 0.86) + np.array(
        [150.0, 196.0, 252.0], dtype=np.float32
    ) * sheen[:, :, None] * 0.86
    return to_uint8(image)


def autumn(rng):
    """Amber autumn leaves abstract, in the spirit of the XP 'Autumn' wallpaper."""
    height, width = HEIGHT, WIDTH
    base = vertical_gradient(
        [
            (0.00, (74, 22, 6)),
            (0.35, (150, 62, 12)),
            (0.65, (196, 108, 26)),
            (1.00, (96, 36, 8)),
        ],
        height,
        width,
    )
    leaves = fbm(rng, height, width, octaves=6, base_cells=7)
    leaves = smoothstep(0.34, 0.78, leaves)
    image = base * (1.0 - leaves[:, :, None] * 0.55) + np.array(
        [255.0, 196.0, 92.0], dtype=np.float32
    ) * leaves[:, :, None] * 0.55
    return to_uint8(image)


def red_moon_desert(rng):
    """Dusk desert: dark sky, low horizon, red moon."""
    height, width = HEIGHT, WIDTH
    ys = np.linspace(0.0, 1.0, height, dtype=np.float32)[:, None]
    xs = np.linspace(0.0, 1.0, width, dtype=np.float32)[None, :]

    sky = vertical_gradient(
        [
            (0.00, (16, 8, 26)),
            (0.28, (58, 20, 44)),
            (0.44, (126, 44, 46)),
            (0.52, (176, 82, 52)),
            (0.60, (92, 44, 36)),
            (1.00, (30, 16, 20)),
        ],
        height,
        width,
    )

    dune = (
        0.585
        + 0.030 * np.sin(xs * math.pi * 1.7 + 0.6)
        + 0.014 * np.sin(xs * math.pi * 4.3 + 2.1)
    )
    dune = dune + fbm(rng, 1, width, octaves=5, base_cells=7)[0] * 0.020
    mask = smoothstep(dune - 0.0015, dune + 0.0015, ys).reshape(height, width, 1)
    depth = np.clip((ys - dune) / (1.0 - dune + 1e-6), 0.0, 1.0).reshape(height, width, 1)

    sand = vertical_gradient(
        [(0.0, (128.0, 66.0, 40.0)), (1.0, (34.0, 16.0, 16.0))], height, width
    )
    texture = fbm(rng, height, width, octaves=6, base_cells=60)
    sand = shade(sand, 0.86 + texture * 0.30)
    sand += np.exp(-depth * 5.0) * np.array([46.0, 20.0, 8.0], dtype=np.float32)

    image = sky * (1.0 - mask) + np.clip(sand, 0.0, 255.0) * mask

    # A low, dim red moon sitting on the horizon.
    cx, cy, radius = 0.74, 0.44, 0.055
    dist = np.sqrt(((xs - cx) * (width / height)) ** 2 + (ys - cy) ** 2)
    disc = 1.0 - smoothstep(radius * 0.94, radius * 1.04, dist)
    glow = np.exp(-dist * 34.0)
    image = image * (1.0 - disc[:, :, None] * 0.92) + np.array(
        [232.0, 96.0, 74.0], dtype=np.float32
    ) * disc[:, :, None] * 0.92
    image += glow[:, :, None] * np.array([60.0, 16.0, 12.0], dtype=np.float32)
    return to_uint8(image)


def wind(rng):
    """Soft sage-green field with drifting grass, a calm XP-era alternative."""
    height, width = HEIGHT, WIDTH
    ys = np.linspace(0.0, 1.0, height, dtype=np.float32)[:, None]
    xs = np.linspace(0.0, 1.0, width, dtype=np.float32)[None, :]

    sky = vertical_gradient(
        [
            (0.00, (150, 190, 224)),
            (0.35, (196, 220, 238)),
            (0.58, (232, 240, 244)),
            (1.00, (244, 248, 248)),
        ],
        height,
        width,
    )
    cloud = smoothstep(0.42, 0.78, fbm(rng, height, width, octaves=6, base_cells=5))
    cloud *= 1.0 - smoothstep(0.50, 0.68, ys) * 0.85
    sky = sky * (1.0 - cloud[:, :, None] * 0.9) + np.array(
        [252.0, 253.0, 255.0], dtype=np.float32
    ) * cloud[:, :, None] * 0.9

    horizon = 0.575 + 0.012 * np.sin(xs * math.pi * 1.3 + 0.8)
    mask = smoothstep(horizon - 0.002, horizon + 0.002, ys).reshape(height, width, 1)
    depth = np.clip((ys - horizon) / (1.0 - horizon + 1e-6), 0.0, 1.0).reshape(height, width, 1)

    field = vertical_gradient(
        [(0.0, (168.0, 190.0, 132.0)), (0.5, (128.0, 158.0, 84.0)), (1.0, (74.0, 104.0, 46.0))],
        height,
        width,
    )
    texture = fbm(rng, height, width, octaves=7, base_cells=70)
    field = shade(field, 0.88 + texture * 0.26)

    # Wind streaks: horizontal bands drifting through the grass.
    streaks = smoothstep(0.44, 0.80, fbm(rng, height, width, octaves=3, base_cells=3))
    field += streaks[:, :, None] * np.array([26.0, 34.0, 14.0], dtype=np.float32) * (0.35 + depth)

    image = sky * (1.0 - mask) + np.clip(field, 0.0, 255.0) * mask
    return to_uint8(image)


WALLPAPERS = [
    ("1-bliss.png", bliss),
    ("2-azul.png", azul),
    ("3-autumn.png", autumn),
    ("4-red-moon-desert.png", red_moon_desert),
    ("5-wind.png", wind),
]


def main():
    out_dir = sys.argv[1] if len(sys.argv) > 1 else os.path.join(
        os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "backgrounds"
    )
    os.makedirs(out_dir, exist_ok=True)

    for index, (name, builder) in enumerate(WALLPAPERS):
        rng = np.random.default_rng(0xF00D + index)
        path = os.path.join(out_dir, name)
        image = builder(rng)
        write_png(path, image)
        print("wrote %s (%dx%d)" % (path, image.shape[1], image.shape[0]))


if __name__ == "__main__":
    main()
