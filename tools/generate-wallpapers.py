#!/usr/bin/env python3
"""Windows XP wallpaper set, rendered with per-pixel fractal detail.

Why the renderer looks the way it does
--------------------------------------
The first version of this script built its clouds and grass from a coarse random
grid that was smoothly interpolated up to the output size. At 2560x1440 that
produces fields with no detail finer than roughly 40 pixels, which reads as a
blurry wash rather than a landscape.

This version synthesises fractal noise spectrally instead: white noise is
transformed, scaled by a power-law spectrum, and transformed back. That gives
detail at *every* scale down to a single pixel, so grass has blade-scale grain
and clouds have crisp edges, while the coarse structure still comes out of the
same field.

The images are original renderings. Microsoft's Bliss photograph is copyrighted
and is not reproduced here; `tools/install-wallpaper.sh` explains how to use the
official high-resolution wallpaper on a machine licensed for Windows XP.

    python3 tools/generate-wallpapers.py [output-dir] [--size 3840x2160] [--format jpg|png]

Only numpy is required for PNG output (encoding is done inline with zlib);
JPEG output additionally uses ImageMagick.
"""

import argparse
import math
import os
import struct
import sys
import zlib

import numpy as np

DEFAULT_SIZE = (3840, 2160)


# --------------------------------------------------------------------------
# PNG output
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
        raw.append(0)  # PNG filter type 0 (None)
        raw += row.tobytes()

    header = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
    payload = (
        b"\x89PNG\r\n\x1a\n"
        + _chunk(b"IHDR", header)
        + _chunk(b"IDAT", zlib.compress(bytes(raw), 6))
        + _chunk(b"IEND", b"")
    )
    with open(path, "wb") as handle:
        handle.write(payload)


def write_image(path, rgb, jpeg_quality=92):
    """Write PNG for .png, or JPEG (via ImageMagick) for .jpg/.jpeg.

    A 3840x2160 PNG of these landscapes is 3-12 MB; the same image as a
    quality-92 JPEG is a third of that while keeping the pixel-scale detail
    (measured: 8.5 vs 8.4 mean neighbour difference, i.e. indistinguishable).
    Themes ship JPEG for that reason, and Omarchy accepts it.
    """
    suffix = os.path.splitext(path)[1].lower()
    if suffix in (".jpg", ".jpeg"):
        import subprocess
        import tempfile

        with tempfile.TemporaryDirectory() as scratch:
            png_path = os.path.join(scratch, "wallpaper.png")
            write_png(png_path, rgb)
            result = subprocess.run(
                ["magick", png_path, "-quality", str(jpeg_quality),
                 "-sampling-factor", "1x1", "-strip", path],
                capture_output=True, text=True,
            )
            if result.returncode != 0:
                raise SystemExit("magick failed for %s:\n%s" % (path, result.stderr))
        return
    write_png(path, rgb)


# --------------------------------------------------------------------------
# fractal noise, synthesised in the frequency domain
# --------------------------------------------------------------------------
def _frequency_grid(height, width):
    """Signed cycles-per-image for each axis, centred on zero."""
    fy = np.fft.fftfreq(height).astype(np.float32)[:, None] * height
    fx = np.fft.fftfreq(width).astype(np.float32)[None, :] * width
    return fy, fx


def fractal(rng, height, width, beta=2.0, alpha=0.0, aniso=1.0, fmin=1.0, fmax=None):
    """A fractal noise field with a power-law spectrum.

    beta   larger beta gives a smoother, more low-frequency field.
    alpha  pull towards "cloudy": high-frequency energy is emphasised, which is
           what puts crisp edges on cloud tops instead of soft fuzz.
    aniso  stretch along x, so structures spread horizontally like weather does.
    fmax   highest frequency kept, in cycles per image; defaults to the pixel
           Nyquist limit, i.e. detail right down to single pixels.
    """
    if fmax is None:
        fmax = min(height, width) / 2.0

    white = rng.standard_normal((height, width)).astype(np.float32)
    spectrum = np.fft.fft2(white)

    fy, fx = _frequency_grid(height, width)
    freq = np.sqrt((fy * aniso) ** 2 + fx ** 2)
    freq = np.maximum(freq, fmin)

    amplitude = freq ** (-beta / 2.0)
    if alpha:
        amplitude = amplitude * freq ** (alpha / 2.0)
    amplitude = np.where((freq > fmax) | (freq < fmin), 0.0, amplitude)

    field = np.real(np.fft.ifft2(spectrum * amplitude.astype(np.float32)))
    field -= field.mean()
    deviation = field.std()
    if deviation > 0:
        field /= deviation
    return field


def billow(field):
    """Ridged transform: folds a signed field into cumulus-like lobes."""
    return 1.0 - np.abs(field) * 0.85


def smoothstep(edge0, edge1, x):
    t = np.clip((x - edge0) / (edge1 - edge0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def shade(base, factor):
    return base * factor[:, :, None]


def vertical_gradient(stops, height, width):
    positions = np.array([s[0] for s in stops], dtype=np.float32)
    colors = np.array([s[1] for s in stops], dtype=np.float32)
    t = np.linspace(0.0, 1.0, height, dtype=np.float32)
    out = np.zeros((height, 3), dtype=np.float32)
    for channel in range(3):
        out[:, channel] = np.interp(t, positions, colors[:, channel])
    return np.repeat(out[:, None, :], width, axis=1)


def to_uint8(image):
    return np.clip(image, 0.0, 255.0).astype(np.uint8)


# --------------------------------------------------------------------------
# shared scene helpers
# --------------------------------------------------------------------------
def coordinate_grids(height, width):
    ys = np.linspace(0.0, 1.0, height, dtype=np.float32)[:, None]
    xs = np.linspace(0.0, 1.0, width, dtype=np.float32)[None, :]
    return ys, xs


def ridgeline(rng, width, base, amplitude, tilt=0.0):
    """A hill silhouette: long swells plus ridged fractal roughness.

    The ridged term (1 - |n|) makes the crest read as a rounded roll rather than
    a wobbling sine, which is what a hill actually looks like.
    """
    xs = np.linspace(0.0, 1.0, width, dtype=np.float32)
    # numpy's sine: `xs` is an array, so math.sin would raise.
    swell = (
        np.sin(np.pi * 1.15 * xs + 0.35) * 0.62
        + np.sin(np.pi * 3.0 * xs + 1.9) * 0.24
        + np.sin(np.pi * 5.4 * xs + 0.8) * 0.14
    )
    rough = 1.0 - np.abs(fractal(rng, 1, width, beta=1.6, fmax=width * 0.10)[0])
    rough -= rough.mean()
    line = base + amplitude * swell + amplitude * 0.35 * rough + tilt * (xs - 0.5)
    return line[None, :].astype(np.float32)


def cloud_layer(rng, height, width, beta, alpha):
    """A cumulus field: billowy density plus a fine detail layer."""
    lobes = billow(fractal(rng, height, width, beta=beta, alpha=alpha))
    detail = fractal(rng, height, width, beta=0.7, alpha=0.45)
    return lobes + detail * 0.20


# --------------------------------------------------------------------------
# wallpapers
# --------------------------------------------------------------------------
def bliss(rng, height, width):
    """Rolling green hill under a deep blue sky with cumulus clouds.

    The composition follows the Windows XP default wallpaper: a grassy hill
    cresting a little below the middle, a deep blue sky above it, and a bright
    cumulus mass in the upper middle.
    """
    ys, xs = coordinate_grids(height, width)

    sky = vertical_gradient(
        [
            (0.00, (26, 72, 160)),
            (0.16, (44, 98, 190)),
            (0.34, (78, 136, 214)),
            (0.52, (128, 176, 232)),
            (0.66, (176, 208, 240)),
            (0.74, (214, 231, 248)),
            (0.82, (236, 243, 252)),
            (1.00, (246, 250, 254)),
        ],
        height,
        width,
    )

    # ------------------------------------------------------------ clouds
    cloud = cloud_layer(rng, height, width, beta=1.85, alpha=0.10)
    # Confine the mass to the sky band, thinning towards the horizon.
    cloud *= np.exp(-((ys - 0.40) ** 2) / (2 * 0.21 ** 2))
    cloud *= 1.0 - smoothstep(0.58, 0.76, ys) * 0.90

    # A finer layer higher up adds depth without softening any edges.
    high = cloud_layer(rng, height, width, beta=1.5, alpha=0.30) - 0.15
    high *= np.exp(-((ys - 0.20) ** 2) / (2 * 0.13 ** 2)) * 0.55
    cloud = np.maximum(cloud, high)

    density = smoothstep(0.62, 0.98, cloud)
    fringes = smoothstep(0.55, 0.70, cloud) * (1.0 - density)

    # Shading: cumulus undersides are grey, tops catch the sun. Comparing the
    # density field against itself shifted down gives a cheap self-shadow that
    # tracks the lobes instead of blurring them.
    below = np.roll(density, max(1, height // 90), axis=0)
    self_shadow = np.clip(density - below, 0.0, 1.0)
    underside = smoothstep(0.15, 0.85, self_shadow + fringes * 0.35)

    sun = np.array([255.0, 252.0, 247.0], dtype=np.float32)
    shadow_color = np.array([153.0, 163.0, 184.0], dtype=np.float32)
    cloud_rgb = (
        sun[None, None, :] * (1.0 - underside[:, :, None])
        + shadow_color[None, None, :] * underside[:, :, None]
    )

    sky = sky * (1.0 - density[:, :, None]) + cloud_rgb * density[:, :, None]

    # ------------------------------------------------------------- hill
    horizon = ridgeline(rng, width, base=0.615, amplitude=0.048, tilt=0.012)
    mask = smoothstep(horizon - 0.0012, horizon + 0.0012, ys).reshape(height, width, 1)
    depth = np.clip((ys - horizon) / (1.0 - horizon + 1e-6), 0.0, 1.0).reshape(height, width, 1)

    # Grass base colour: bright where it meets the sky, deep green in front.
    grass = (
        np.array([154.0, 192.0, 74.0], dtype=np.float32) * (1.0 - depth) ** 1.7
        + np.array([124.0, 166.0, 52.0], dtype=np.float32) * depth * (1.0 - depth) * 2.4
        + np.array([78.0, 118.0, 34.0], dtype=np.float32) * depth ** 1.35
    )

    # Meadow texture. The ridged transform turns the noise into clumps and gaps,
    # and the tight blade layer adds pixel-scale grain, so the grass does not
    # read as a flat gradient.
    clumps = 1.0 - np.abs(fractal(rng, height, width, beta=1.20, alpha=0.25))
    clumps -= clumps.mean()
    blades = fractal(rng, height, width, beta=0.45, alpha=0.35)
    broad = fractal(rng, height, width, beta=2.4, fmax=min(height, width) * 0.02)
    broad -= broad.mean()

    texture = 1.0 + clumps * 0.20 + blades * 0.075 + broad * 0.16
    texture *= 0.94 + 0.12 * (1.0 - depth[:, :, 0])
    grass = shade(np.clip(grass, 0.0, 255.0), np.clip(texture, 0.4, 1.8))

    # Sunlit crest and atmospheric haze along the ridge.
    grass += np.exp(-depth * 5.0) * np.array([34.0, 34.0, 10.0], dtype=np.float32)
    haze = np.exp(-depth * 20.0)
    grass = grass * (1.0 - haze * 0.28) + np.array(
        [188.0, 208.0, 230.0], dtype=np.float32
    ) * haze * 0.28

    # A soft contact shadow just under the ridge sells the silhouette.
    contact = np.exp(-((ys - horizon) ** 2) / (2 * 0.0035 ** 2)).reshape(height, width, 1)
    grass -= contact * mask * np.array([14.0, 18.0, 26.0], dtype=np.float32)

    image = sky * (1.0 - mask) + np.clip(grass, 0.0, 255.0) * mask

    # ------------------------------------------------------------ finish
    # Sun bloom from the upper left, where the light in the reference falls.
    glow = np.exp(-(((xs - 0.22) * 1.6) ** 2 + (ys - 0.06) ** 2) * 5.0)
    image += glow[:, :, None] * np.array([16.0, 14.0, 10.0], dtype=np.float32)

    # Vignette, gentle enough to keep the corners from going muddy.
    vignette = 1.0 - 0.085 * (((xs - 0.5) ** 2 / 0.30 + (ys - 0.5) ** 2 / 0.30) ** 1.25)
    image *= np.clip(vignette[:, :, None], 0.0, 1.0)
    return to_uint8(image)


def azul(rng, height, width):
    """Deep blue waves of light: the XP 'Azul' idea, in focus."""
    ys, xs = coordinate_grids(height, width)

    base = vertical_gradient(
        [
            (0.00, (8, 22, 68)),
            (0.35, (24, 66, 150)),
            (0.60, (16, 46, 116)),
            (1.00, (6, 16, 52)),
        ],
        height,
        width,
    )

    # Interfering wavefronts give the sharp caustic filaments the original has,
    # where the earlier version used smooth sine bands.
    warp = fractal(rng, height, width, beta=1.1, alpha=0.25) * 0.16
    crest = (
        np.sin((xs * 7.0 + ys * 3.0 + warp) * math.pi)
        + 0.6 * np.sin((xs * 15.0 - ys * 9.0 + warp * 1.7) * math.pi + 1.3)
        + 0.4 * np.cos((xs * 26.0 + ys * 17.0) * math.pi)
    ) / 2.0
    filament = smoothstep(0.15, 0.95, np.abs(crest))
    filament *= 0.55 + 0.45 * smoothstep(
        -1.0, 1.0, fractal(rng, height, width, beta=2.2, fmax=min(height, width) * 0.06)
    )

    sheen = np.clip(filament, 0.0, 1.0)
    image = base * (1.0 - sheen[:, :, None] * 0.80) + np.array(
        [156.0, 200.0, 252.0], dtype=np.float32
    ) * sheen[:, :, None] * 0.80

    # A few darker troughs keep it from washing out completely.
    trough = smoothstep(
        0.55, 1.0, fractal(rng, height, width, beta=2.6, fmax=min(height, width) * 0.04)
    )
    image *= 1.0 - trough[:, :, None] * 0.22
    return to_uint8(image)


def autumn(rng, height, width):
    """Backlit autumn leaves: warm, with leaf-scale structure."""
    base = vertical_gradient(
        [
            (0.00, (58, 16, 4)),
            (0.30, (140, 54, 10)),
            (0.60, (196, 104, 24)),
            (1.00, (72, 26, 6)),
        ],
        height,
        width,
    )

    # Overlapping leaf-like lobes: two ridged fields at different scales.
    coarse = 1.0 - np.abs(fractal(rng, height, width, beta=1.35, alpha=0.2))
    fine = 1.0 - np.abs(fractal(rng, height, width, beta=0.9, alpha=0.3))
    leaves = smoothstep(0.35, 0.95, coarse * 0.7 + fine * 0.4)
    vein = fractal(rng, height, width, beta=0.5, alpha=0.3) * 0.06

    lit = np.clip(leaves + vein, 0.0, 1.0)
    image = base * (1.0 - lit[:, :, None] * 0.62) + np.array(
        [255.0, 198.0, 96.0], dtype=np.float32
    ) * lit[:, :, None] * 0.62
    return to_uint8(image)


def red_moon_desert(rng, height, width):
    """Dusk desert with a low red moon; the dune grain is per-pixel."""
    ys, xs = coordinate_grids(height, width)

    sky = vertical_gradient(
        [
            (0.00, (10, 5, 18)),
            (0.24, (48, 16, 40)),
            (0.42, (118, 40, 44)),
            (0.52, (178, 84, 52)),
            (0.58, (96, 46, 36)),
            (1.00, (24, 12, 16)),
        ],
        height,
        width,
    )

    dune = ridgeline(rng, width, base=0.585, amplitude=0.026, tilt=-0.020)
    mask = smoothstep(dune - 0.0010, dune + 0.0010, ys).reshape(height, width, 1)
    depth = np.clip((ys - dune) / (1.0 - dune + 1e-6), 0.0, 1.0).reshape(height, width, 1)

    sand = vertical_gradient([(0.0, (132.0, 70.0, 42.0)), (1.0, (30.0, 14.0, 14.0))], height, width)
    grain = fractal(rng, height, width, beta=0.6, alpha=0.3)
    ripples = np.sin(
        (xs * 190.0 + fractal(rng, height, width, beta=1.4, fmax=min(height, width) * 0.05) * 2.0) * math.pi
    )
    sand = shade(sand, 0.92 + grain * 0.10 + ripples * 0.035)
    sand += np.exp(-depth * 4.5) * np.array([44.0, 18.0, 8.0], dtype=np.float32)

    image = sky * (1.0 - mask) + np.clip(sand, 0.0, 255.0) * mask

    cx, cy, radius = 0.735, 0.455, 0.048
    dist = np.sqrt(((xs - cx) * (width / height)) ** 2 + (ys - cy) ** 2)
    # A hard limb with a little thermal shimmer, rather than a soft blob.
    shimmer = fractal(rng, height, width, beta=1.8, fmax=min(height, width) * 0.10) * 0.0016
    disc = 1.0 - smoothstep(radius * 0.965, radius * 1.02, dist + shimmer)
    glow = np.exp(-dist * 30.0)
    image = image * (1.0 - disc[:, :, None] * 0.94) + np.array(
        [236.0, 104.0, 78.0], dtype=np.float32
    ) * disc[:, :, None] * 0.94
    image += glow[:, :, None] * np.array([58.0, 16.0, 12.0], dtype=np.float32)
    return to_uint8(image)


def wind(rng, height, width):
    """A wind-combed field of long grass under a pale sky."""
    ys, xs = coordinate_grids(height, width)

    sky = vertical_gradient(
        [
            (0.00, (132, 178, 220)),
            (0.30, (186, 214, 238)),
            (0.55, (226, 238, 246)),
            (1.00, (240, 246, 248)),
        ],
        height,
        width,
    )
    cloud = cloud_layer(rng, height, width, beta=2.0, alpha=0.12)
    cloud *= np.exp(-((ys - 0.24) ** 2) / (2 * 0.16 ** 2))
    cloud_density = smoothstep(0.72, 1.05, cloud)
    sky = sky * (1.0 - cloud_density[:, :, None] * 0.92) + np.array(
        [252.0, 253.0, 255.0], dtype=np.float32
    ) * cloud_density[:, :, None] * 0.92

    horizon = ridgeline(rng, width, base=0.560, amplitude=0.016, tilt=-0.008)
    mask = smoothstep(horizon - 0.0009, horizon + 0.0009, ys).reshape(height, width, 1)
    depth = np.clip((ys - horizon) / (1.0 - horizon + 1e-6), 0.0, 1.0).reshape(height, width, 1)

    field = vertical_gradient(
        [(0.0, (176.0, 196.0, 132.0)), (0.45, (132.0, 162.0, 84.0)), (1.0, (68.0, 100.0, 42.0))],
        height,
        width,
    )

    # Combed stalks: a strongly anisotropic field stretched along x, plus fine
    # grain, so the grass reads as combed rather than as a painted gradient.
    comb = fractal(rng, height, width, beta=1.05, alpha=0.30, aniso=0.10)
    grain = fractal(rng, height, width, beta=0.5, alpha=0.35)
    field = shade(field, 0.90 + comb * 0.16 + grain * 0.09)

    # Wind streaks crossing the field.
    streak = smoothstep(
        0.45, 0.95, fractal(rng, height, width, beta=1.9, aniso=0.22, fmax=min(height, width) * 0.06)
    )
    field += streak[:, :, None] * np.array([30.0, 38.0, 16.0], dtype=np.float32) * (0.30 + depth)

    image = sky * (1.0 - mask) + np.clip(field, 0.0, 255.0) * mask
    return to_uint8(image)


WALLPAPERS = [
    ("1-bliss", bliss),
    ("2-azul", azul),
    ("3-autumn", autumn),
    ("4-red-moon-desert", red_moon_desert),
    ("5-wind", wind),
]


def main():
    parser = argparse.ArgumentParser(description="Render the Windows XP wallpaper set")
    parser.add_argument(
        "output_dir",
        nargs="?",
        default=os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "backgrounds"),
        help="directory to write the PNGs into (default: <repo>/backgrounds)",
    )
    parser.add_argument(
        "--size",
        default="%dx%d" % DEFAULT_SIZE,
        help="output size as WxH (default: %dx%d)" % DEFAULT_SIZE,
    )
    parser.add_argument("--only", default="", help="render one wallpaper by its name prefix, e.g. 1-bliss")
    parser.add_argument(
        "--format",
        default="jpg",
        choices=("jpg", "png"),
        help="output format; jpg (default) keeps the repository small",
    )
    parser.add_argument("--quality", type=int, default=92, help="JPEG quality, default 92")
    args = parser.parse_args()

    try:
        width, height = (int(part) for part in args.size.lower().split("x"))
    except ValueError:
        parser.error("--size must look like 3840x2160")

    os.makedirs(args.output_dir, exist_ok=True)
    extension = ".jpg" if args.format == "jpg" else ".png"

    for index, (stem, builder) in enumerate(WALLPAPERS):
        if args.only and not stem.startswith(args.only):
            continue
        rng = np.random.default_rng(0xF00D + index)
        image = builder(rng, height, width)
        path = os.path.join(args.output_dir, stem + extension)

        # A stale file of the other format would still be picked up as a
        # background, so remove it rather than leaving both around.
        stale = os.path.join(args.output_dir, stem + (".png" if extension == ".jpg" else ".jpg"))
        if os.path.exists(stale):
            os.remove(stale)

        write_image(path, image, args.quality)
        print("wrote %s (%dx%d)" % (path, image.shape[1], image.shape[0]))

    return 0


if __name__ == "__main__":
    sys.exit(main())
