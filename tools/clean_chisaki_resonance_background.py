from pathlib import Path

import numpy as np
from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "assets" / "ui"
RUNTIME_TEXTURES = [
    "chisaki_resonance_empty_original.png",
    "chisaki_resonance_ready_original.png",
    "chisaki_resonance_release_1_original.png",
    "chisaki_resonance_release_2_original.png",
    "chisaki_resonance_release_3_original.png",
    "chisaki_resonance_release_4_original.png",
    "chisaki_resonance_release_5_original.png",
    "chisaki_resonance_wave_original.png",
]


def clean_texture(path: Path) -> int:
    image = Image.open(path).convert("RGBA")
    pixels = np.asarray(image, dtype=np.uint8).copy()
    rgb = pixels[..., :3]
    alpha = pixels[..., 3]

    channel_range = rgb.max(axis=2) - rgb.min(axis=2)
    dark_neutral = (rgb.max(axis=2) <= 40) & (channel_range <= 3)
    background = dark_neutral & (alpha <= 64)
    cleared = int(np.count_nonzero(background & (alpha > 0)))
    pixels[..., 3][background] = 0

    Image.fromarray(pixels, "RGBA").save(path)
    return cleared


def main() -> None:
    for name in RUNTIME_TEXTURES:
        path = ASSETS / name
        before = Image.open(path)
        original_size = before.size
        cleared = clean_texture(path)
        after = Image.open(path)
        if after.size != original_size or after.mode != "RGBA":
            raise RuntimeError(f"Texture shape changed unexpectedly: {name}")
        print(f"{name}: cleared {cleared} background pixels")


if __name__ == "__main__":
    main()
