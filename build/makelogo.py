"""Build logo_black_240.png from the Custos art, and preview the real splash.

The splash draws the version string at
    canvas_h/2 + logo_height/2 + COMPONENT_PADDING
so the visible artwork must be exactly `logo_height` tall and vertically centred,
or the version text lands on top of it.
"""
import sys
from PIL import Image, ImageDraw, ImageFont

SRC = "/in/custos os.png"
OUT = "/out/logo_black_240.png"
CANVAS = 240
LOGO_HEIGHT = int(sys.argv[1]) if len(sys.argv) > 1 else 160

# Content box from the band analysis: mark + wordmark, tagline excluded.
BOX = (200, 179, 1091, 1027)          # left, top, right+1, bottom+1

src = Image.open(SRC).convert("RGB").crop(BOX)
scale = LOGO_HEIGHT / src.height
size = (max(1, round(src.width * scale)), LOGO_HEIGHT)
art = src.resize(size, Image.LANCZOS)

logo = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 255))
logo.paste(art, ((CANVAS - art.width) // 2, (CANVAS - art.height) // 2))
logo.save(OUT)
print(f"wrote {OUT}: {logo.size}, artwork {art.size}, logo_height={LOGO_HEIGHT}")

# --- preview the actual splash geometry -------------------------------------
PADDING = 8
ACCENT = "#FF9F0A"
for canvas_w, name in ((240, "240x240"), (320, "320x240")):
    frame = Image.new("RGB", (canvas_w, CANVAS), (0, 0, 0))
    frame.paste(logo.convert("RGB"), ((canvas_w - CANVAS) // 2, 0))
    d = ImageDraw.Draw(frame)
    font = ImageFont.truetype("/fonts/OpenSans-SemiBold.ttf", 21)
    version_y = CANVAS // 2 + LOGO_HEIGHT // 2 + PADDING
    d.text((canvas_w // 2, version_y), "0.9.0-custos", font=font, fill=ACCENT, anchor="mt")
    frame.save(f"/out/_preview_{name}.png")
    print(f"preview {name}: version text baseline y={version_y}, "
          f"bottom≈{version_y + 28} of {CANVAS}")
