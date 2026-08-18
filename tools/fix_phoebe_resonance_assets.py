from pathlib import Path

from PIL import Image, ImageFilter


UI_DIR = Path(__file__).resolve().parents[1] / "assets" / "ui"


def mirror_about_pixel_gap(image: Image.Image) -> Image.Image:
    """Mirror the left half around x=319.5 for an exactly balanced 640px bar."""
    width, height = image.size
    if width % 2 != 0:
        raise ValueError(f"Expected an even texture width, got {width}")
    left = image.crop((0, 0, width // 2, height))
    result = Image.new("RGBA", image.size)
    result.paste(left, (0, 0))
    result.paste(left.transpose(Image.Transpose.FLIP_LEFT_RIGHT), (width // 2, 0))
    return result


def clean_and_sharpen(image: Image.Image, alpha_floor: int, percent: int) -> Image.Image:
    image = image.convert("RGBA")
    rgb = image.convert("RGB").filter(
        ImageFilter.UnsharpMask(radius=0.65, percent=percent, threshold=2)
    )
    alpha = image.getchannel("A").point(
        lambda value: 0
        if value <= alpha_floor
        else round((value - alpha_floor) * 255 / (255 - alpha_floor))
    )
    result = rgb.convert("RGBA")
    result.putalpha(alpha)
    return result


def isolate_frequency_bars(
    image: Image.Image,
    left_range: tuple[int, int],
    right_range: tuple[int, int],
    baseline_y: int,
) -> Image.Image:
    """Remove static rails, endpoint ornaments, and the center crystal."""
    mask = Image.new("L", image.size)
    source_alpha = image.getchannel("A")
    for start_x, end_x in (left_range, right_range):
        region = source_alpha.crop((start_x, 0, end_x, baseline_y + 1))
        mask.paste(region, (start_x, 0))
    result = image.copy()
    result.putalpha(mask)
    return result


def fit_visible_width(image: Image.Image, target_width: int) -> Image.Image:
    """Center the visible artwork at a fixed width without changing its height."""
    alpha_bbox = image.getchannel("A").getbbox()
    if alpha_bbox is None:
        return image
    left, _top, right, _bottom = alpha_bbox
    visible_width = right - left
    if visible_width <= target_width + 1:
        return image
    visible = image.crop((left, 0, right, image.height))
    visible = visible.resize((target_width, image.height), Image.Resampling.LANCZOS)
    result = Image.new("RGBA", image.size)
    result.alpha_composite(visible, ((image.width - target_width) // 2, 0))
    return result


def process(
    name: str,
    *,
    symmetric: bool,
    alpha_floor: int,
    percent: int,
    wave_ranges: tuple[tuple[int, int], tuple[int, int]] | None = None,
    baseline_y: int = 0,
    target_visible_width: int = 0,
) -> None:
    path = UI_DIR / name
    image = Image.open(path).convert("RGBA")
    if symmetric:
        image = mirror_about_pixel_gap(image)
    if wave_ranges is not None:
        image = isolate_frequency_bars(
            image, wave_ranges[0], wave_ranges[1], baseline_y
        )
    if target_visible_width > 0:
        image = fit_visible_width(image, target_visible_width)
    clean_and_sharpen(image, alpha_floor, percent).save(path, optimize=True)


process(
    "phoebe_resonance_empty_redraw.png",
    symmetric=True,
    alpha_floor=10,
    percent=125,
)
process(
    "phoebe_resonance_wave_gold_redraw.png",
    symmetric=True,
    alpha_floor=24,
    percent=175,
    wave_ranges=((112, 294), (346, 528)),
    baseline_y=62,
)
process(
    "phoebe_resonance_ready_base_redraw.png",
    symmetric=False,
    alpha_floor=10,
    percent=125,
    target_visible_width=480,
)
process(
    "phoebe_resonance_wave_ready_redraw.png",
    symmetric=False,
    alpha_floor=20,
    percent=165,
    wave_ranges=((70, 304), (336, 570)),
    baseline_y=62,
    target_visible_width=416,
)
