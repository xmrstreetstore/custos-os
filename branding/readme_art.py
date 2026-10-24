"""
Render the README artwork in the custos-os.com look: black, gold, Montserrat.

    python branding/readme_art.py <fonts-dir> <screens-dir>

<fonts-dir> holds Montserrat.ttf and Inter.ttf (the variable fonts from
google/fonts, ofl/montserrat and ofl/inter). <screens-dir> holds 320x240 device
screenshots rendered from the app (see custos-os-site/screens/render.py):
home, load-seed, card-nfc, pin, smartcard, backup.

Writes branding/readme-banner.png, readme-screens.png and custos-mark.png. Corners
are transparent so the dark panels sit as cards on GitHub's light theme too.
"""
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
LOGO = os.path.join(HERE, "custos-logo.png")

BLACK = (0, 0, 0)
BONE = (236, 232, 223)
GOLD = (232, 179, 58)
MUTED = (163, 157, 144)
BEZEL = (27, 26, 23)
BEZEL_LINE = (47, 44, 37)


def font(path, size, weight):
    f = ImageFont.truetype(path, size)
    axes = f.get_variation_axes()
    f.set_variation_by_axes([weight if a["name"] in (b"Weight", "Weight") else a["default"] for a in axes])
    return f


def unblack(im):
    """Gold-on-black artwork to RGBA: alpha from brightness, colour un-premultiplied."""
    a = np.asarray(im.convert("RGB")).astype(np.float32)
    alpha = np.clip((a.max(axis=2) - 6) * 255 / 249, 0, 255)
    rgb = np.where(alpha[..., None] > 0, np.clip(a * 255 / np.maximum(alpha[..., None], 1), 0, 255), 0)
    out = Image.fromarray(np.dstack([rgb, alpha]).astype(np.uint8), "RGBA")
    return out.crop(out.getbbox())


def tracked(draw, xy, text, f, fill, tracking, anchor_center=True):
    """Draw text with letter-spacing (em fraction). Returns the drawn width."""
    space = f.size * tracking
    widths = [draw.textlength(c, font=f) for c in text]
    total = sum(widths) + space * (len(text) - 1)
    x, y = xy
    if anchor_center:
        x -= total / 2
    for c, w in zip(text, widths):
        draw.text((x, y), c, font=f, fill=fill)
        x += w + space
    return total


def panel(w, h, radius, glows):
    """Black rounded panel with soft gold radial glows: [(cx, cy, rx, ry, strength)]."""
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    light = np.zeros((h, w), np.float32)
    for cx, cy, rx, ry, k in glows:
        d = ((xx - cx * w) / (rx * w)) ** 2 + ((yy - cy * h) / (ry * h)) ** 2
        light += k * np.clip(1 - np.sqrt(d), 0, 1) ** 2
    rgb = np.clip(np.array(GOLD, np.float32)[None, None, :] * light[..., None], 0, 255)
    im = Image.fromarray(rgb.astype(np.uint8), "RGB").convert("RGBA")
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, w - 1, h - 1), radius=radius, fill=255)
    im.putalpha(mask)
    return im


def banner(fonts):
    W, H = 1600, 860
    im = panel(W, H, 36, [(0.5, 0.28, 0.55, 0.62, 0.20), (0.86, 0.95, 0.35, 0.45, 0.07)])
    d = ImageDraw.Draw(im)

    logo = unblack(Image.open(LOGO))
    lh = 330
    logo = logo.resize((int(logo.width * lh / logo.height), lh), Image.LANCZOS)
    im.alpha_composite(logo, ((W - logo.width) // 2, 64))

    y = 64 + lh + 34
    tag = font(fonts["montserrat"], 24, 500)
    tw = tracked(d, (W / 2, y), "STATELESS BY DESIGN", tag, GOLD, 0.32)
    ly = y + 15
    for x0 in (W / 2 - tw / 2 - 92, W / 2 + tw / 2 + 30):
        d.line((x0, ly, x0 + 62, ly), fill=GOLD, width=2)

    head = font(fonts["montserrat"], 66, 500)
    y += 70
    d.text((W / 2, y), "Your seed lives on a card.", font=head, fill=BONE, anchor="mt")
    d.text((W / 2, y + 86), "Your signer forgets it.", font=head, fill=GOLD, anchor="mt")

    sub = font(fonts["inter"], 25, 400)
    d.text((W / 2, y + 200),
           "Air-gapped bitcoin signer  ·  SeedKeeper smartcard  ·  contact or NFC  ·  built on SeedSigner",
           font=sub, fill=MUTED, anchor="mt")
    return im


def screens(fonts, shots):
    names = [("home", "HOME"), ("load-seed", "LOAD A SEED"), ("card-nfc", "TAP A CARD"),
             ("pin", "UNLOCK"), ("smartcard", "SMARTCARD TOOLS"), ("backup", "BACK UP TO A CARD")]
    sw, sh, bz = 440, 330, 12
    gap_x, gap_y, pad_x, pad_y, cap = 52, 44, 72, 64, 52
    cols = 3
    W = pad_x * 2 + cols * (sw + 2 * bz) + (cols - 1) * gap_x
    H = pad_y * 2 + 2 * (sh + 2 * bz + cap) + gap_y
    im = panel(W, H, 36, [(0.5, 0.5, 0.75, 0.9, 0.08)])
    d = ImageDraw.Draw(im)
    capf = font(fonts["montserrat"], 17, 500)

    for i, (name, label) in enumerate(names):
        cx = pad_x + (i % cols) * (sw + 2 * bz + gap_x)
        cy = pad_y + (i // cols) * (sh + 2 * bz + cap + gap_y)
        frame = (cx, cy, cx + sw + 2 * bz, cy + sh + 2 * bz)

        glow = Image.new("RGBA", im.size, (0, 0, 0, 0))
        ImageDraw.Draw(glow).rounded_rectangle(frame, radius=18, fill=GOLD + (60,))
        im.alpha_composite(glow.filter(ImageFilter.GaussianBlur(26)))
        d.rounded_rectangle(frame, radius=18, fill=BEZEL, outline=BEZEL_LINE, width=2)

        # 3x nearest first keeps the device's pixel text sharp, then scale down smoothly.
        src = Image.open(os.path.join(shots, name + ".png")).convert("RGB")
        scr = src.resize((src.width * 3, src.height * 3), Image.NEAREST).resize((sw, sh), Image.LANCZOS)
        m = Image.new("L", (sw, sh), 0)
        ImageDraw.Draw(m).rounded_rectangle((0, 0, sw - 1, sh - 1), radius=8, fill=255)
        im.paste(scr, (cx + bz, cy + bz), m)

        tracked(d, (cx + bz + sw / 2, cy + sh + 2 * bz + 20), label, capf, MUTED, 0.22)
    return im


def mark():
    logo = unblack(Image.open(LOGO).crop((0, 0, 1254, 940)))
    s = max(logo.size)
    sq = Image.new("RGBA", (s, s))
    sq.alpha_composite(logo, ((s - logo.width) // 2, (s - logo.height) // 2))
    return sq.resize((240, 240), Image.LANCZOS)


if __name__ == "__main__":
    fdir, shots = sys.argv[1], sys.argv[2]
    fonts = {"montserrat": os.path.join(fdir, "Montserrat.ttf"), "inter": os.path.join(fdir, "Inter.ttf")}
    banner(fonts).save(os.path.join(HERE, "readme-banner.png"), optimize=True)
    screens(fonts, shots).save(os.path.join(HERE, "readme-screens.png"), optimize=True)
    mark().save(os.path.join(HERE, "custos-mark.png"), optimize=True)
    print("ok")
