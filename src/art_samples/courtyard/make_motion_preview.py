"""Assemble native Godot capture frames into a compact, undithered preview GIF."""
import argparse
from pathlib import Path

from PIL import Image


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("frames", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    paths = sorted(args.frames.glob("[0-9][0-9][0-9].png"))
    if len(paths) != 60:
        raise SystemExit(f"Expected 60 captured frames, found {len(paths)}")
    frames = []
    for path in paths:
        with Image.open(path) as source:
            frames.append(source.convert("RGB").resize((960, 540), Image.Resampling.LANCZOS))
    # One shared palette avoids per-frame colour flicker. No dithering over flat paint.
    contact = Image.new("RGB", (960, 540 * 6))
    for i, frame in enumerate(frames[::10]):
        contact.paste(frame, (0, i * 540))
    palette = contact.quantize(colors=256, method=Image.Quantize.MEDIANCUT)
    quantized = [frame.quantize(palette=palette, dither=Image.Dither.NONE) for frame in frames]
    args.output.parent.mkdir(parents=True, exist_ok=True)
    quantized[0].save(args.output, save_all=True, append_images=quantized[1:], duration=100, loop=0, disposal=1, optimize=False)
    print(f"{args.output}: 60 frames, 960x540, 10 fps, {args.output.stat().st_size} bytes")


if __name__ == "__main__":
    main()
