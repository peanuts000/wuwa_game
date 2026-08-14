from __future__ import annotations

import json
from pathlib import Path

import numpy as np
from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
COMPONENTS = ROOT / "assets" / "ui" / "coletta_components"
REFERENCE = Path(r"C:\Users\2246\Downloads\T_RoleSkillTreeKelaita.png")
OUTPUT = ROOT / "assets" / "ui"
BACKGROUND = np.array([30.0, 30.0, 30.0], dtype=np.float32)


def correlation(image: np.ndarray, kernel: np.ndarray) -> np.ndarray:
    ih, iw = image.shape
    kh, kw = kernel.shape
    shape = (ih + kh - 1, iw + kw - 1)
    spectrum = np.fft.rfft2(image, shape) * np.fft.rfft2(kernel[::-1, ::-1], shape)
    convolution = np.fft.irfft2(spectrum, shape)
    return convolution[kh - 1 : ih, kw - 1 : iw]


def match_component(target: np.ndarray, source: Image.Image, scales: list[float]) -> dict:
    target_rgb = target[..., :3].astype(np.float32)
    target_sq = np.sum(target_rgb * target_rgb, axis=2)
    best: dict | None = None
    for flip in (False, True):
        base = source.transpose(Image.Transpose.FLIP_LEFT_RIGHT) if flip else source
        for scale in scales:
            size = (max(1, round(base.width * scale)), max(1, round(base.height * scale)))
            component = np.asarray(base.resize(size, Image.Resampling.LANCZOS), dtype=np.float32)
            alpha = component[..., 3] / 255.0
            mask = (alpha > 0.16).astype(np.float32) * np.sqrt(alpha)
            if mask.sum() < 1.0 or size[0] > target.shape[1] or size[1] > target.shape[0]:
                continue
            predicted = component[..., :3] * alpha[..., None] + BACKGROUND * (1.0 - alpha[..., None])
            score = correlation(target_sq, mask)
            for channel in range(3):
                weighted = predicted[..., channel] * mask
                score -= 2.0 * correlation(target_rgb[..., channel], weighted)
                score += np.sum(predicted[..., channel] ** 2 * mask)
            score /= mask.sum()
            y, x = np.unravel_index(np.argmin(score), score.shape)
            candidate = {
                "x": int(x),
                "y": int(y),
                "scale": scale,
                "flip": flip,
                "score": float(score[y, x]),
            }
            if best is None or candidate["score"] < best["score"]:
                best = candidate
    assert best is not None
    return best


def place(canvas: Image.Image, filename: str, placement: dict, additive: bool = False) -> None:
    layer = Image.open(COMPONENTS / filename).convert("RGBA")
    if placement["flip"]:
        layer = layer.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    scale = placement["scale"]
    layer = layer.resize((round(layer.width * scale), round(layer.height * scale)), Image.Resampling.LANCZOS)
    if not additive:
        canvas.alpha_composite(layer, (placement["x"], placement["y"]))
        return
    x, y = placement["x"], placement["y"]
    box = (x, y, x + layer.width, y + layer.height)
    base = np.asarray(canvas.crop(box), dtype=np.float32) / 255.0
    top = np.asarray(layer, dtype=np.float32) / 255.0
    base_alpha = base[..., 3:4]
    top_alpha = top[..., 3:4]
    out_alpha = 1.0 - (1.0 - base_alpha) * (1.0 - top_alpha)
    premultiplied = base[..., :3] * base_alpha + top[..., :3] * top_alpha
    out_rgb = np.clip(premultiplied / np.maximum(out_alpha, 1e-6), 0.0, 1.0)
    output = np.concatenate((out_rgb, out_alpha), axis=2)
    canvas.paste(Image.fromarray(np.uint8(np.round(output * 255.0)), "RGBA"), (x, y))


def main() -> None:
    normal_layout = [
        ("T_NorIceFrameRed.png", {"x": 17, "y": 52, "scale": 1.28, "flip": False}),
        ("T_NorIceFrameRed.png", {"x": 321, "y": 52, "scale": 1.28, "flip": True}),
        ("T_NorLightMidRed.png", {"x": 276, "y": 24, "scale": 1.0, "flip": False}),
        ("T_NorCrystal1.png", {"x": 256, "y": 0, "scale": 1.0, "flip": False}),
        ("T_NorCrystal2.png", {"x": 246, "y": 42, "scale": 1.0, "flip": False}),
        ("T_NorCrystalMid2.png", {"x": 304, "y": 42, "scale": 1.0, "flip": False}),
    ]
    ready_layout = [
        ("T_UltimateLightPurple.png", {"x": 133, "y": 10, "scale": 1.0, "flip": False}),
        ("T_UltimateLightBlueTop.png", {"x": 20, "y": 2, "scale": 1.0, "flip": False}),
        ("T_UltimateLightBlueBottom.png", {"x": 9, "y": 58, "scale": 1.0, "flip": False}),
        ("T_UltimateCharge1Bg.png", {"x": 24, "y": 34, "scale": 1.0, "flip": False}),
        ("T_UltimateCharge2Bg.png", {"x": 95, "y": 31, "scale": 1.25, "flip": False}),
        ("T_UltimateCharge3Bg.png", {"x": 200, "y": 30, "scale": 1.25, "flip": False}),
        ("T_UltimateCharge4Bg.png", {"x": 354, "y": 28, "scale": 1.0, "flip": False}),
        ("T_UltimateCharge1.png", {"x": 24, "y": 12, "scale": 1.0, "flip": False}),
        ("T_UltimateCharge2.png", {"x": 90, "y": 12, "scale": 1.25, "flip": False}),
        ("T_UltimateCharge3.png", {"x": 190, "y": 9, "scale": 1.25, "flip": False}),
        ("T_UltimateCharge4.png", {"x": 350, "y": 6, "scale": 1.0, "flip": False}),
        ("T_UltimateLightBlue.png", {"x": 24, "y": 44, "scale": 1.0, "flip": False}),
        ("T_UltimateLightRed.png", {"x": 292, "y": 0, "scale": 1.0, "flip": False}),
    ]
    empty = Image.new("RGBA", (640, 106), (0, 0, 0, 0))
    for filename, placement in normal_layout:
        place(empty, filename, placement)

    ready = Image.new("RGBA", (640, 106), (0, 0, 0, 0))
    for filename, placement in ready_layout:
        place(ready, filename, placement, additive=True)

    empty.save(OUTPUT / "coletta_resonance_empty_components.png")
    ready.save(OUTPUT / "coletta_resonance_ready_components.png")
    reference = Image.open(REFERENCE).convert("RGBA")
    comparison = Image.new("RGBA", (1280, 232), (30, 30, 30, 255))
    comparison.alpha_composite(reference.crop((72, 0, 712, 106)), (0, 0))
    comparison.alpha_composite(reference.crop((960, 0, 1600, 106)), (640, 0))
    comparison.alpha_composite(empty, (0, 126))
    comparison.alpha_composite(ready, (640, 126))
    comparison.save(OUTPUT / "coletta_resonance_component_comparison.png")
    (OUTPUT / "coletta_resonance_component_layout.json").write_text(
        json.dumps({"normal": normal_layout, "ready": ready_layout}, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    print("Generated component composites")


if __name__ == "__main__":
    main()
