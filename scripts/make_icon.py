#!/usr/bin/env python3
"""アプリアイコン(1024x1024)を生成する。画像素材は使わず、すべて図形で描く。

使い方: python3 scripts/make_icon.py
必要: Pillow
"""
import math
import os
from PIL import Image, ImageDraw, ImageFont

S = 1024
OUT = os.path.join(os.path.dirname(__file__), "..", "App", "Assets.xcassets", "AppIcon.appiconset", "icon-1024.png")

FONT_CANDIDATES = [
    "/usr/share/fonts/opentype/inter/Inter-ExtraBold.otf",
    "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
    "/System/Library/Fonts/Supplemental/Arial Black.ttf",
    "/System/Library/Fonts/Helvetica.ttc",
]


def font(size):
    for path in FONT_CANDIDATES:
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def main():
    # 2 倍で描いて縮小(なめらかにするため)
    k = 2
    n = S * k
    img = Image.new("RGB", (n, n), (230, 30, 30))
    d = ImageDraw.Draw(img)
    cx, cy = n / 2, n * 0.54

    # 後光
    rays = 18
    for i in range(rays):
        a0 = 2 * math.pi * i / rays
        a1 = a0 + math.pi / rays
        r = n * 1.2
        d.polygon(
            [(cx, cy), (cx + math.cos(a0) * r, cy + math.sin(a0) * r), (cx + math.cos(a1) * r, cy + math.sin(a1) * r)],
            fill=(255, 205, 40),
        )
    # 中心の光
    for i in range(40, 0, -1):
        rr = n * 0.42 * i / 40
        c = int(255 - 30 * i / 40)
        d.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], fill=(255, c, 120 + int(100 * (1 - i / 40))))

    # 餃子(半月)
    gw, gh = n * 0.36, n * 0.27
    gy = cy + n * 0.10
    outline = (90, 45, 10)
    d.pieslice([cx - gw - 14, gy - gh - 14, cx + gw + 14, gy + gh + 14], 180, 360, fill=outline)
    d.rounded_rectangle([cx - gw - 14, gy - 4, cx + gw + 14, gy + n * 0.035 + 14], radius=30, fill=outline)
    d.pieslice([cx - gw, gy - gh, cx + gw, gy + gh], 180, 360, fill=(255, 240, 205))
    d.rounded_rectangle([cx - gw, gy - 6, cx + gw, gy + n * 0.035], radius=24, fill=(255, 240, 205))
    # 焼き目
    d.pieslice([cx - gw * 0.8, gy - gh * 0.55, cx + gw * 0.8, gy + gh * 0.55], 180, 360, fill=(235, 170, 80))
    d.pieslice([cx - gw * 0.8, gy - gh * 0.32, cx + gw * 0.8, gy + gh * 0.32], 180, 360, fill=(255, 240, 205))
    # ひだ
    for i in range(9):
        t = math.pi + math.pi * (i + 0.5) / 9
        x0, y0 = cx + math.cos(t) * gw * 0.98, gy + math.sin(t) * gh * 0.98
        x1, y1 = cx + math.cos(t) * gw * 0.80, gy + math.sin(t) * gh * 0.80
        d.line([(x0, y0), (x1, y1)], fill=outline, width=12)
    # 顔(やる気のない目)
    for sx in (-1, 1):
        ex = cx + sx * gw * 0.28
        ey = gy - gh * 0.16
        d.ellipse([ex - 26, ey - 26, ex + 26, ey + 26], fill=(30, 20, 10))
        d.ellipse([ex - 4, ey - 18, ex + 12, ey - 2], fill=(255, 255, 255))
    d.arc([cx - 44, gy - gh * 0.16, cx + 44, gy - gh * 0.16 + 60], 20, 160, fill=(30, 20, 10), width=12)

    # 数字
    text = "×9999"
    f = font(int(n * 0.21))
    box = d.textbbox((0, 0), text, font=f)
    tw, th = box[2] - box[0], box[3] - box[1]
    tx, ty = cx - tw / 2 - box[0], n * 0.07 - box[1]
    for dx in range(-14, 15, 7):
        for dy in range(-14, 15, 7):
            d.text((tx + dx, ty + dy + 10), text, font=f, fill=(90, 0, 0))
    d.text((tx, ty), text, font=f, fill=(255, 255, 255))

    img = img.resize((S, S), Image.LANCZOS)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    img.save(OUT, "PNG", optimize=True)
    print("wrote", os.path.normpath(OUT))


if __name__ == "__main__":
    main()
