from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
SOURCE = Path(r"C:\Users\2246\Downloads\T_RoleSkillTreeKelaita.png")
OUTPUT = ROOT / "assets" / "ui"


def make_background_transparent(rgb: np.ndarray, background: np.ndarray) -> Image.Image:
    pixels = rgb.astype(np.float32)
    matte = background.astype(np.float32)
    distance = np.max(np.abs(pixels - matte), axis=2)
    alpha = np.clip((distance - 1.0) / 27.0, 0.0, 1.0)
    alpha = alpha * alpha * (3.0 - 2.0 * alpha)

    safe_alpha = np.maximum(alpha[..., None], 1.0 / 255.0)
    foreground = matte + (pixels - matte) / safe_alpha
    foreground = np.clip(foreground, 0.0, 255.0)
    foreground[alpha <= 0.0] = 0.0
    rgba = np.dstack((foreground, alpha[..., None] * 255.0))
    return Image.fromarray(np.uint8(np.round(rgba)), "RGBA")


def main() -> None:
    source = Image.open(SOURCE).convert("RGB")
    original_empty = np.asarray(source.crop((72, 0, 712, 106))).copy()
    empty = original_empty.copy()
    ready = source.crop((960, 0, 1600, 106))

    background = np.median(empty[0:24, 0:640], axis=(0, 1)).astype(np.uint8)

    # Remove only the two waveform fields. The center range is excluded so the
    # pink crystal and its glow stay byte-for-byte identical to the reference.
    empty[0:78, 58:586] = background

    # Restore the red/pink crystal pixels inside the waveform gap.
    center = original_empty[0:92, 245:395]
    red_dominant = (
        (center[..., 0].astype(np.int16) > center[..., 1].astype(np.int16) * 1.22)
        & (center[..., 0] > 48)
    )
    restored = empty[0:92, 245:395]
    restored[red_dominant] = center[red_dominant]
    empty[0:92, 245:395] = restored
    empty[20:106, 304:336] = original_empty[20:106, 304:336]
    empty[58:78, 245:304] = background
    empty[58:78, 336:395] = background

    # Feather the hard cleanup edge into the untouched reference background.
    for y, opacity in ((78, 0.8), (79, 0.6), (80, 0.4), (81, 0.2)):
        for start, end in ((58, 280), (360, 586)):
            row = empty[y, start:end].astype(np.float32)
            empty[y, start:end] = np.uint8(
                np.clip(row * (1.0 - opacity) + background * opacity, 0.0, 255.0)
            )

    empty_image = make_background_transparent(empty, background)
    ready_image = make_background_transparent(np.asarray(ready), background)
    empty_image.save(OUTPUT / "coletta_resonance_empty_cutout.png")
    ready_image.save(OUTPUT / "coletta_resonance_ready_original.png")

    comparison = Image.new("RGB", (1280, 232), tuple(int(value) for value in background))
    comparison.paste(source.crop((72, 0, 712, 106)), (0, 0))
    comparison.paste(source.crop((960, 0, 1600, 106)), (640, 0))
    comparison.paste(empty_image, (0, 126), empty_image)
    comparison.paste(ready_image, (640, 126), ready_image)
    comparison.save(OUTPUT / "coletta_resonance_cutout_comparison.png")


if __name__ == "__main__":
    main()
