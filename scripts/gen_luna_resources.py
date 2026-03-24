#!/usr/bin/env python3
"""
Procedural Luna theme assets for ZirconOSLuna.
Outputs PNGs under src/desktop/luna/resources/. Original artwork (no MS/ReactOS derivatives).
SPDX-License-Identifier: CC0-1.0
"""
from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "src" / "desktop" / "luna" / "resources"

# Palette — zircon teal, luna amber, night blue (distinct from stock Luna orb / Bliss)
Z_TEAL = (45, 212, 191, 255)
Z_TEAL_D = (13, 148, 136, 255)
NIGHT = (30, 58, 95, 255)
NIGHT_D = (15, 30, 52, 255)
MOON = (251, 191, 36, 255)
MOON_D = (245, 158, 11, 255)
ICE = (224, 242, 254, 255)
WHITE = (255, 255, 255, 255)
BLACK = (0, 0, 0, 255)
GRAY = (120, 128, 140, 255)
SILVER_M = (180, 184, 192, 255)


def supersample(draw_fn, size: int = 32, scale: int = 4) -> Image.Image:
    s = size * scale
    im = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    dr = ImageDraw.Draw(im)
    draw_fn(dr, s)
    return im.resize((size, size), Image.Resampling.LANCZOS)


def save_png(path: Path, im: Image.Image) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    im.save(path, "PNG")


# --- 32x32 icons ---


def draw_zircon_hex(dr: ImageDraw.ImageDraw, cx: float, cy: float, r: float, fill, outline=None):
    pts = []
    for i in range(6):
        a = math.pi / 6 + i * math.pi / 3
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    dr.polygon(pts, fill=fill, outline=outline)


def icon_machine(dr, s: int):
    cx, cy = s / 2, s / 2 - s * 0.06
    r = s * 0.28
    draw_zircon_hex(dr, cx, cy, r, (*Z_TEAL[:3], 200), (*Z_TEAL_D[:3], 255))
    # inner facet
    draw_zircon_hex(dr, cx, cy, r * 0.55, (*ICE[:3], 180), None)
    # bus lines
    y0 = cy + r * 0.85
    for i, x in enumerate([s * 0.22, s * 0.42, s * 0.58, s * 0.78]):
        dr.line((x, y0, x, s * 0.88), fill=(*GRAY[:3], 220), width=max(1, s // 32))
    dr.line((s * 0.18, s * 0.9, s * 0.82, s * 0.9), fill=(*Z_TEAL_D[:3], 200), width=max(1, s // 28))


def icon_documents(dr, s: int):
    m = s * 0.12
    dr.rounded_rectangle((m, m + s * 0.08, s - m, s - m * 0.9), radius=s * 0.06, fill=(*NIGHT[:3], 230), outline=(*Z_TEAL[:3], 255), width=max(1, s // 32))
    # fold
    fold = [(s * 0.32, m + s * 0.08), (s * 0.48, m + s * 0.08), (s * 0.38, m + s * 0.2)]
    dr.polygon(fold, fill=(*Z_TEAL_D[:3], 180))
    # crescent badge
    bx, by = s * 0.62, s * 0.22
    dr.ellipse((bx, by, bx + s * 0.22, by + s * 0.22), fill=(*MOON[:3], 255))
    dr.ellipse((bx + s * 0.06, by - s * 0.02, bx + s * 0.28, by + s * 0.2), fill=(*NIGHT[:3], 0))


def icon_recycle_empty(dr, s: int):
    cx, cy = s / 2, s / 2
    r = s * 0.32
    draw_zircon_hex(dr, cx, cy, r, (0, 0, 0, 0), (*ICE[:3], 255))
    draw_zircon_hex(dr, cx, cy, r * 0.78, (0, 0, 0, 0), (*Z_TEAL[:3], 200))


def icon_recycle_full(dr, s: int):
    cx, cy = s / 2, s / 2
    r = s * 0.28
    draw_zircon_hex(dr, cx, cy, r, (*Z_TEAL_D[:3], 210), (*Z_TEAL[:3], 255))
    for i, (dx, dy) in enumerate([(0, 0), (s * 0.12, -s * 0.08), (-s * 0.1, s * 0.1)]):
        draw_zircon_hex(dr, cx + dx, cy + dy, r * 0.22, (*MOON_D[:3], 180), None)


def icon_network(dr, s: int):
    nodes = [(s * 0.25, s * 0.3), (s * 0.75, s * 0.28), (s * 0.72, s * 0.72), (s * 0.28, s * 0.7)]
    for i in range(4):
        for j in range(i + 1, 4):
            dr.line((*nodes[i], *nodes[j]), fill=(*Z_TEAL[:3], 120), width=max(1, s // 40))
    for (x, y) in nodes:
        r = s * 0.07
        dr.ellipse((x - r, y - r, x + r, y + r), fill=(*MOON[:3], 255), outline=(*NIGHT_D[:3], 255), width=1)


def icon_controlpanel(dr, s: int):
    g = s * 0.2
    x0, y0 = s * 0.18, s * 0.2
    for row in range(2):
        for col in range(2):
            x = x0 + col * (g + s * 0.08)
            y = y0 + row * (g + s * 0.08)
            dr.rounded_rectangle((x, y, x + g, y + g * 0.65), radius=s * 0.03, fill=(*Z_TEAL[:3], 200), outline=(*NIGHT[:3], 255), width=1)
            dr.rectangle((x + g * 0.15, y + g * 0.45, x + g * 0.85, y + g * 0.55), fill=(*MOON[:3], 255))


def icon_printer(dr, s: int):
    # paper
    dr.rounded_rectangle((s * 0.28, s * 0.22, s * 0.72, s * 0.62), radius=s * 0.02, fill=(*ICE[:3], 255), outline=(*GRAY[:3], 255), width=1)
    dr.line((s * 0.34, s * 0.32, s * 0.66, s * 0.32), fill=(*NIGHT_D[:3], 180), width=1)
    # body
    dr.rounded_rectangle((s * 0.22, s * 0.55, s * 0.78, s * 0.82), radius=s * 0.04, fill=(*SILVER_M[:3], 255), outline=(*NIGHT[:3], 255), width=1)
    dr.ellipse((s * 0.42, s * 0.66, s * 0.58, s * 0.78), fill=(*Z_TEAL_D[:3], 255))


def icon_help(dr, s: int):
    dr.rounded_rectangle((s * 0.2, s * 0.35, s * 0.8, s * 0.82), radius=s * 0.04, fill=(*NIGHT[:3], 240), outline=(*Z_TEAL[:3], 255), width=1)
    dr.line((s * 0.28, s * 0.42, s * 0.72, s * 0.42), fill=(*ICE[:3], 200), width=1)
    dr.line((s * 0.28, s * 0.5, s * 0.55, s * 0.5), fill=(*ICE[:3], 150), width=1)
    # star
    sx, sy = s * 0.72, s * 0.48
    dr.regular_polygon((sx, sy, s * 0.06), 5, rotation=-18, fill=(*MOON[:3], 255))


def icon_search(dr, s: int):
    cx, cy = s * 0.38, s * 0.4
    r = s * 0.18
    dr.ellipse((cx - r, cy - r, cx + r, cy + r), outline=(*ICE[:3], 255), width=max(2, s // 16))
    # handle — facet bar
    x1, y1 = cx + r * 0.65, cy + r * 0.65
    x2, y2 = s * 0.82, s * 0.82
    dr.line((x1, y1, x2, y2), fill=(*Z_TEAL[:3], 255), width=max(3, s // 10))


def icon_run(dr, s: int):
    m = s * 0.18
    dr.rounded_rectangle((m, m, s - m, s - m), radius=s * 0.08, outline=(*Z_TEAL[:3], 255), width=max(2, s // 16))
    tri = [(s * 0.42, s * 0.32), (s * 0.42, s * 0.68), (s * 0.68, s * 0.5)]
    dr.polygon(tri, fill=(*MOON[:3], 255))


def icon_shutdown(dr, s: int):
    cx, cy = s / 2, s / 2
    r = s * 0.22
    dr.arc((cx - r, cy - r, cx + r, cy + r), 60, 300, fill=(*ICE[:3], 255), width=max(3, s // 12))
    dr.line((cx, cy - r * 0.15, cx, cy + r * 0.35), fill=(*ICE[:3], 255), width=max(3, s // 12))


def icon_logoff(dr, s: int):
    dr.rounded_rectangle((s * 0.22, s * 0.25, s * 0.45, s * 0.75), radius=s * 0.04, outline=(*Z_TEAL[:3], 255), width=max(2, s // 16))
    # arrow
    ax = s * 0.52
    dr.line((ax, s * 0.5, s * 0.78, s * 0.5), fill=(*MOON[:3], 255), width=max(3, s // 14))
    dr.polygon([(s * 0.72, s * 0.38), (s * 0.85, s * 0.5), (s * 0.72, s * 0.62)], fill=(*MOON[:3], 255))


def icon_user(dr, s: int):
    cx, cy = s / 2, s * 0.42
    dr.ellipse((cx - s * 0.16, cy - s * 0.16, cx + s * 0.16, cy + s * 0.16), fill=(*ICE[:3], 255), outline=(*NIGHT[:3], 255), width=1)
    dr.arc((cx - s * 0.22, cy + s * 0.02, cx + s * 0.22, cy + s * 0.45), 0, 180, fill=(*Z_TEAL[:3], 220), width=max(2, s // 16))
    # moon
    mx, my = s * 0.68, s * 0.2
    dr.ellipse((mx, my, mx + s * 0.18, my + s * 0.18), fill=(*MOON[:3], 255))


def icon_browser(dr, s: int):
    dr.rounded_rectangle((s * 0.18, s * 0.22, s * 0.82, s * 0.78), radius=s * 0.05, fill=(*NIGHT_D[:3], 230), outline=(*Z_TEAL[:3], 255), width=1)
    dr.rectangle((s * 0.18, s * 0.22, s * 0.82, s * 0.38), fill=(*Z_TEAL_D[:3], 200))
    # orbit arc
    bbox = (s * 0.28, s * 0.42, s * 0.72, s * 0.72)
    dr.arc(bbox, 200, 520, fill=(*MOON[:3], 255), width=max(2, s // 16))


def icon_email(dr, s: int):
    dr.polygon([(s * 0.15, s * 0.32), (s * 0.5, s * 0.55), (s * 0.85, s * 0.32)], fill=(*ICE[:3], 255), outline=(*NIGHT[:3], 255), width=1)
    dr.polygon([(s * 0.15, s * 0.32), (s * 0.5, s * 0.52), (s * 0.15, s * 0.68)], fill=(*Z_TEAL[:3], 120), outline=(*NIGHT[:3], 255), width=1)
    dr.polygon([(s * 0.85, s * 0.32), (s * 0.5, s * 0.52), (s * 0.85, s * 0.68)], fill=(*Z_TEAL_D[:3], 120), outline=(*NIGHT[:3], 255), width=1)
    dr.ellipse((s * 0.62, s * 0.52, s * 0.78, s * 0.68), fill=(*MOON[:3], 255))


def tray_volume(dr, s: int):
    # speaker wedge
    dr.polygon([(s * 0.2, s * 0.35), (s * 0.2, s * 0.65), (s * 0.38, s * 0.65), (s * 0.5, s * 0.75), (s * 0.5, s * 0.25), (s * 0.38, s * 0.35)], fill=(*ICE[:3], 255), outline=(*NIGHT[:3], 255), width=1)
    for i, (x0, x1) in enumerate([(0.55, 0.62), (0.64, 0.74), (0.72, 0.86)]):
        dr.arc((s * 0.45, s * 0.2, s * 0.95, s * 0.8), 300 - i * 25, 340 - i * 25, fill=(*Z_TEAL[:3], 255), width=max(1, s // 16))


def tray_network(dr, s: int):
    cx, cy = s * 0.5, s * 0.55
    for i, (w, h) in enumerate([(0.5, 0.35), (0.72, 0.55), (0.95, 0.78)]):
        ww, hh = s * w * 0.5, s * h * 0.35
        dr.arc((cx - ww, cy - hh, cx + ww, cy + hh), 200, 340, fill=(*MOON[:3], 220 - i * 50), width=max(2, s // 14))
    dr.ellipse((cx - s * 0.08, cy + s * 0.08, cx + s * 0.08, cy + s * 0.22), fill=(*Z_TEAL[:3], 255))


# --- 16x16 tray (no supersample, direct) ---


def tray_icon(draw_fn) -> Image.Image:
    s = 64
    im = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    dr = ImageDraw.Draw(im)
    draw_fn(dr, s)
    return im.resize((16, 16), Image.Resampling.LANCZOS)


# --- Start button 108x30 ---


def gen_start_button() -> Image.Image:
    w, h = 108, 30
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    dr = ImageDraw.Draw(im)
    m = 2
    dr.rounded_rectangle((m, m, w - m, h - m), radius=6, fill=(*Z_TEAL_D[:3], 255), outline=(*NIGHT_D[:3], 255), width=1)
    # inner highlight
    dr.rounded_rectangle((m + 2, m + 2, w // 2, h - m - 2), radius=4, fill=(*Z_TEAL[:3], 80))
    # small gem
    cx, cy = 22, h // 2
    draw_zircon_hex(dr, cx, cy, 9, (*ICE[:3], 230), (*MOON_D[:3], 255))
    # subtle sheen
    dr.line((8, 6, 40, 6), fill=(255, 255, 255, 60), width=1)
    return im


# --- Titlebar 63x21: min, max, close ---


def gen_titlebar_buttons() -> Image.Image:
    w, h = 63, 21
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    dr = ImageDraw.Draw(im)
    for i in range(3):
        x0 = i * 21
        dr.rounded_rectangle((x0 + 2, 2, x0 + 19, h - 2), radius=3, fill=(*SILVER_M[:3], 220), outline=(*GRAY[:3], 180), width=1)
        cx = x0 + 10.5
        cy = h / 2
        if i == 0:
            dr.line((x0 + 6, cy, x0 + 15, cy), fill=(*NIGHT_D[:3], 255), width=2)
        elif i == 1:
            dr.rectangle((x0 + 7, cy - 4, x0 + 14, cy + 4), outline=(*NIGHT_D[:3], 255), width=2)
        else:
            dr.line((x0 + 7, cy - 4, x0 + 14, cy + 4), fill=(*NIGHT_D[:3], 255), width=2)
            dr.line((x0 + 7, cy + 4, x0 + 14, cy - 4), fill=(*NIGHT_D[:3], 255), width=2)
    return im


# --- Cursors 32x32 ---


def gen_cursor_arrow() -> Image.Image:
    s = 32
    im = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    dr = ImageDraw.Draw(im)
    pts = [(1, 1), (1, 22), (8, 16), (12, 26), (16, 24), (11, 14), (20, 14)]
    dr.polygon(pts, fill=(*BLACK[:3], 255), outline=(*WHITE[:3], 255), width=1)
    return im


def gen_cursor_wait() -> Image.Image:
    s = 32
    im = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    dr = ImageDraw.Draw(im)
    cx, cy = s / 2, s / 2
    for i in range(8):
        a0 = i * 45 - 90
        a1 = a0 + 32
        r0, r1 = 4, 12
        # wedge
        dr.pieslice((cx - 14, cy - 14, cx + 14, cy + 14), a0, a1, fill=(*Z_TEAL[:3], 200 - i * 18))
    draw_zircon_hex(dr, cx, cy, 5, (*MOON[:3], 255), (*NIGHT[:3], 255))
    return im


# --- Wallpapers 1280x720 ---


def wp_blue() -> Image.Image:
    w, h = 1280, 720
    im = Image.new("RGB", (w, h))
    px = im.load()
    for y in range(h):
        for x in range(w):
            t = y / h
            u = x / w
            r = int(8 + t * 40 + u * 25)
            g = int(20 + t * 55 + (1 - u) * 30)
            b = int(60 + (1 - t) * 80 + u * 40)
            px[x, y] = (r, g, b)
    # soft diagonal aurora bands (abstract, not landscape)
    overlay = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    dr = ImageDraw.Draw(overlay)
    for i in range(5):
        x0 = -200 + i * 280
        dr.polygon(
            [(x0, h), (x0 + 400, 0), (x0 + 520, 0), (x0 + 120, h)],
            fill=(45, 212, 191, 25 + i * 8),
        )
    im = Image.alpha_composite(im.convert("RGBA"), overlay).convert("RGB")
    return im


def wp_olive() -> Image.Image:
    w, h = 1280, 720
    im = Image.new("RGB", (w, h))
    px = im.load()
    for y in range(h):
        for x in range(w):
            t = y / h
            r = int(50 + t * 40)
            g = int(70 + (1 - t) * 50 + (x / w) * 20)
            b = int(35 + t * 25)
            px[x, y] = (r, g, b)
    ov = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    dr = ImageDraw.Draw(ov)
    dr.ellipse((w * 0.55, -h * 0.1, w * 1.1, h * 0.45), fill=(245, 158, 11, 35))
    return Image.alpha_composite(im.convert("RGBA"), ov).convert("RGB")


def wp_silver() -> Image.Image:
    w, h = 1280, 720
    im = Image.new("RGB", (w, h))
    px = im.load()
    for y in range(h):
        for x in range(w):
            v = int(110 + (x + y) / (w + h) * 50)
            px[x, y] = (v, v - 5, v + 8)
    ov = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    dr = ImageDraw.Draw(ov)
    for i in range(3):
        y0 = h * (0.2 + i * 0.22)
        dr.line([(0, y0), (w, y0 + 80)], fill=(58, 91, 140, 20), width=40)
    return Image.alpha_composite(im.convert("RGBA"), ov).convert("RGB")


def main() -> None:
    icons = [
        ("icons/system/icon_mycomputer.png", icon_machine),
        ("icons/system/icon_mydocuments.png", icon_documents),
        ("icons/system/icon_recyclebin_empty.png", icon_recycle_empty),
        ("icons/system/icon_recyclebin_full.png", icon_recycle_full),
        ("icons/system/icon_network.png", icon_network),
        ("icons/system/icon_controlpanel.png", icon_controlpanel),
        ("icons/system/icon_printer.png", icon_printer),
        ("icons/system/icon_help.png", icon_help),
        ("icons/system/icon_search.png", icon_search),
        ("icons/system/icon_run.png", icon_run),
        ("icons/system/icon_shutdown.png", icon_shutdown),
        ("icons/system/icon_logoff.png", icon_logoff),
        ("icons/system/icon_user_default.png", icon_user),
    ]
    for rel, fn in icons:
        save_png(OUT / rel, supersample(fn, 32, 4))

    for sub in ("icons/quicklaunch", "icons/startmenu"):
        save_png(OUT / sub / "icon_internet.png", supersample(icon_browser, 32, 4))
        save_png(OUT / sub / "icon_email.png", supersample(icon_email, 32, 4))

    save_png(OUT / "icons/tray/icon_tray_volume.png", tray_icon(tray_volume))
    save_png(OUT / "icons/tray/icon_tray_network.png", tray_icon(tray_network))

    save_png(OUT / "taskbar/ui_start_button.png", gen_start_button())
    save_png(OUT / "titlebar/ui_titlebar_buttons.png", gen_titlebar_buttons())

    save_png(OUT / "cursors/cursor_arrow.png", gen_cursor_arrow())
    save_png(OUT / "cursors/cursor_wait.png", gen_cursor_wait())

    save_png(OUT / "wallpapers/bliss_default.png", wp_blue())
    save_png(OUT / "wallpapers/wallpaper_olive_green.png", wp_olive())
    save_png(OUT / "wallpapers/wallpaper_silver.png", wp_silver())

    export_kernel_rgba_icons()
    export_kernel_cursor_and_wallpaper()

    print("Wrote Luna resources to", OUT)


def export_kernel_rgba_icons() -> None:
    """32x32 RGBA raw blobs for kernel @embedFile (no PNG decoder in kernel)."""
    kd = ROOT / "src" / "kernel" / "gui" / "data"
    kd.mkdir(parents=True, exist_ok=True)
    mapping = [
        ("icon_mycomputer.rgba", OUT / "icons/system/icon_mycomputer.png"),
        ("icon_mydocuments.rgba", OUT / "icons/system/icon_mydocuments.png"),
        ("icon_recyclebin_empty.rgba", OUT / "icons/system/icon_recyclebin_empty.png"),
        ("icon_network.rgba", OUT / "icons/system/icon_network.png"),
        ("icon_internet.rgba", OUT / "icons/quicklaunch/icon_internet.png"),
    ]
    for fname, png_path in mapping:
        im = Image.open(png_path).convert("RGBA")
        if im.size != (32, 32):
            raise SystemExit(f"kernel embed expects 32x32: {png_path}")
        kd.joinpath(fname).write_bytes(im.tobytes())


def export_kernel_cursor_and_wallpaper() -> None:
    """Kernel Luna: arrow cursor + bliss wallpaper thumbnail (stretch at runtime)."""
    kd = ROOT / "src" / "kernel" / "gui" / "data"
    kd.mkdir(parents=True, exist_ok=True)
    car = Image.open(OUT / "cursors/cursor_arrow.png").convert("RGBA")
    if car.size != (32, 32):
        raise SystemExit("kernel cursor expects 32x32 cursor_arrow.png")
    kd.joinpath("cursor_arrow.rgba").write_bytes(car.tobytes())
    wpb = Image.open(OUT / "wallpapers/bliss_default.png").convert("RGBA")
    wpb = wpb.resize((320, 180), Image.Resampling.LANCZOS)
    kd.joinpath("wallpaper_bliss_320x180.rgba").write_bytes(wpb.tobytes())


if __name__ == "__main__":
    main()
