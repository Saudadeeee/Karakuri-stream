"""Pack assets/icon/icon_256.png into the multi-size .ico the Windows export needs.

    godot --headless --path . --script tools/gen_icon.gd   # SVG -> PNG
    python tools/gen_icon.py                               # PNG -> ICO

Windows picks a different size per context (16 in the title bar, 32 in the task
bar, 48 in Explorer, 256 in the large-icon view). Shipping only 256 makes
Windows downscale it itself, which on a pixel-edged icon like this one comes out
muddy — so every size goes in the file.
"""

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "assets" / "icon" / "icon_256.png"
DST = ROOT / "assets" / "icon" / "icon.ico"
SIZES = [(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]


def main() -> int:
    if not SRC.exists():
        print(f"missing {SRC} — run tools/gen_icon.gd first")
        return 1
    img = Image.open(SRC).convert("RGBA")
    img.save(DST, format="ICO", sizes=SIZES)
    print(f"ICO {DST.relative_to(ROOT)} ({DST.stat().st_size} bytes, {len(SIZES)} sizes)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
