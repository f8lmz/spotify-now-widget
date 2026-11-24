#!/usr/bin/env python3
"""Draw the Spotify Now app icon at every size macOS expects."""

import math
import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ICON_DIR = ROOT / "SpotifyNow" / "Assets.xcassets" / "AppIcon.appiconset"
ACCENT_DIR = ROOT / "SpotifyNow" / "Assets.xcassets" / "AccentColor.colorset"
CATALOG = ROOT / "SpotifyNow" / "Assets.xcassets"


def mix(a, b, t):
    t = 0.0 if t < 0 else 1.0 if t > 1 else t
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def smooth(edge, distance):
    # 1 inside, 0 outside, antialiased across one pixel in normalized space.
    return max(0.0, min(1.0, 0.5 - distance / max(edge, 1e-6)))


def shade(nx, ny, pixel):
    """nx, ny are -1..1, y grows downward. pixel is the antialias width."""
    r = math.hypot(nx, ny * 0.98)
    bg = mix((22, 36, 30), (12, 16, 14), (ny + 1) / 2)
    color = bg

    # Soft contact shadow under the disc.
    shadow = r - 0.66
    color = mix(color, (6, 8, 7), smooth(pixel * 8, shadow) * 0.45)

    disc_edge = r - 0.60
    disc_cover = smooth(pixel, disc_edge)
    if disc_cover > 0:
        light = max(0.0, min(1.0, 0.5 - nx * 0.18 - ny * 0.22))
        vinyl = mix((214, 208, 196), (244, 240, 230), light)
        # Grooves.
        for groove in (0.34, 0.43, 0.51):
            band = abs(r - groove) - 0.008
            vinyl = mix(vinyl, (186, 180, 168), smooth(pixel * 1.4, band) * 0.55)
        color = mix(color, vinyl, disc_cover)

    label = smooth(pixel, r - 0.20)
    if label > 0:
        green = mix((18, 140, 64), (40, 205, 98), max(0.0, -ny))
        color = mix(color, green, label)

    hole = smooth(pixel, r - 0.055)
    color = mix(color, (17, 24, 20), hole)
    return color


def render(size):
    samples = 3 if size <= 128 else 2
    rows = []
    edge = 2.0 / size
    for y in range(size):
        row = bytearray()
        for x in range(size):
            acc = [0, 0, 0]
            for sy in range(samples):
                for sx in range(samples):
                    fx = x + (sx + 0.5) / samples
                    fy = y + (sy + 0.5) / samples
                    nx = (fx / size) * 2 - 1
                    ny = (fy / size) * 2 - 1
                    pixel = shade(nx, ny, edge / samples)
                    for i in range(3):
                        acc[i] += pixel[i]
            count = samples * samples
            row.extend(int(channel / count) for channel in acc)
        rows.append(bytes(row))
    return rows


def write_png(path, rows):
    height = len(rows)
    width = len(rows[0]) // 3

    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    raw = b"".join(b"\x00" + row for row in rows)
    ihdr = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    path.write_bytes(png)


def main():
    ICON_DIR.mkdir(parents=True, exist_ok=True)
    ACCENT_DIR.mkdir(parents=True, exist_ok=True)
    pixels = {}
    for size in (16, 32, 64, 128, 256, 512, 1024):
        name = f"icon_{size}.png"
        print(f"rendering {name}")
        rows = render(size)
        write_png(ICON_DIR / name, rows)
        pixels[size] = name

    slots = [
        (16, "1x", 16),
        (16, "2x", 32),
        (32, "1x", 32),
        (32, "2x", 64),
        (128, "1x", 128),
        (128, "2x", 256),
        (256, "1x", 256),
        (256, "2x", 512),
        (512, "1x", 512),
        (512, "2x", 1024),
    ]
    images = []
    for point, scale, px in slots:
        images.append(
            "    {\n"
            f'      "filename" : "{pixels[px]}",\n'
            '      "idiom" : "mac",\n'
            f'      "scale" : "{scale}",\n'
            f'      "size" : "{point}x{point}"\n'
            "    }"
        )
    (ICON_DIR / "Contents.json").write_text(
        "{\n  \"images\" : [\n" + ",\n".join(images) + "\n  ],\n"
        "  \"info\" : {\n    \"author\" : \"xcode\",\n    \"version\" : 1\n  }\n}\n",
        encoding="utf-8",
    )
    (CATALOG / "Contents.json").write_text(
        '{\n  "info" : {\n    "author" : "xcode",\n    "version" : 1\n  }\n}\n',
        encoding="utf-8",
    )
    (ACCENT_DIR / "Contents.json").write_text(
        """{
  "colors" : [
    {
      "color" : {
        "color-space" : "srgb",
        "components" : {
          "alpha" : "1.000",
          "blue" : "0.329",
          "green" : "0.725",
          "red" : "0.114"
        }
      },
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
""",
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
