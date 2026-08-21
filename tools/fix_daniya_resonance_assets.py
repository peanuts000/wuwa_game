"""Build Daniya's 640x106 resonance textures from the extracted 2x2 sheet."""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image


OUTPUT_SIZE = (640, 106)
NAMES = ("empty", "ready", "active", "exhausted")


def clean_alpha(image: Image.Image) -> Image.Image:
    image = image.convert("RGBA")
    pixels = image.load()
    for y in range(image.height):
        for x in range(image.width):
            red, green, blue, alpha = pixels[x, y]
            if alpha < 12:
                pixels[x, y] = (red, green, blue, 0)
    return image


def panel(sheet: Image.Image, column: int, row: int) -> Image.Image:
    half_width = sheet.width // 2
    half_height = sheet.height // 2
    left = 0 if column == 0 else half_width
    right = half_width if column == 0 else sheet.width
    top = 0 if row == 0 else half_height
    bottom = half_height if row == 0 else sheet.height
    cell = sheet.crop((left, top, right, bottom))

    # The extraction sheet keeps equal cell canvases. Crop a shared logical
    # band per row so all four states retain the same center and scale.
    logical_top = round(cell.height * (0.25 if row == 0 else 0.10))
    logical_bottom = round(cell.height * (0.81 if row == 0 else 0.66))
    cell = cell.crop((0, logical_top, cell.width, logical_bottom))
    return clean_alpha(cell.resize(OUTPUT_SIZE, Image.Resampling.LANCZOS))


def build_wave(source_image: Image.Image) -> Image.Image:
    wave = Image.new("RGBA", source_image.size)
    source = source_image.load()
    target = wave.load()
    for y in range(source_image.height):
        for x in range(source_image.width):
            red, green, blue, alpha = source[x, y]
            in_wave_band = y < 62
            outside_center_marker = x < 286 or x > 354
            inside_wave_track = 64 <= x <= 576
            if alpha > 10 and in_wave_band and outside_center_marker and inside_wave_track:
                target[x, y] = (red, green, blue, alpha)
    return wave


def build_ready_base(ready: Image.Image, wave: Image.Image) -> Image.Image:
    base = ready.copy()
    base_pixels = base.load()
    wave_pixels = wave.load()
    for y in range(base.height):
        for x in range(base.width):
            if wave_pixels[x, y][3] > 0:
                base_pixels[x, y] = (0, 0, 0, 0)
    return base


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--sheet",
        type=Path,
        default=Path(__file__).with_name("daniya_resonance_extracted_sheet.png"),
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path(__file__).resolve().parents[1] / "assets" / "ui",
    )
    args = parser.parse_args()

    sheet = Image.open(args.sheet).convert("RGBA")
    states = {
        "empty": panel(sheet, 0, 0),
        "ready": panel(sheet, 1, 0),
        "active": panel(sheet, 0, 1),
        "exhausted": panel(sheet, 1, 1),
    }
    args.output_dir.mkdir(parents=True, exist_ok=True)
    for name in NAMES:
        states[name].save(args.output_dir / f"daniya_resonance_{name}.png")
    wave = build_wave(states["ready"])
    wave.save(args.output_dir / "daniya_resonance_wave.png")
    build_ready_base(states["ready"], wave).save(args.output_dir / "daniya_resonance_ready_base.png")
    active_wave = build_wave(states["active"])
    active_wave.save(args.output_dir / "daniya_resonance_active_wave.png")
    build_ready_base(states["active"], active_wave).save(args.output_dir / "daniya_resonance_active_base.png")


if __name__ == "__main__":
    main()
