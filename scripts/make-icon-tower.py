#!/usr/bin/env python3
"""アイコン（1024×1024、透過なし）：夕暮れの空に浮かぶ小さな等角の塔と、窓の猫の目。
使い方: python3 scripts/make-icon-tower.py
"""
import math
from pathlib import Path
from PIL import Image, ImageDraw

S = 1024
img = Image.new('RGB', (S, S))
d = ImageDraw.Draw(img)
# 夕空：ラベンダー → ローズ → アプリコット
stops = [(0, (0x6E, 0x5A, 0x8E)), (0.55, (0xC9, 0x8A, 0x8E)), (1, (0xF2, 0xC4, 0x9B))]
for y in range(S):
    t = y / (S - 1)
    for (a, ca), (b, cb) in zip(stops, stops[1:]):
        if a <= t <= b:
            k = (t - a) / (b - a)
            c = tuple(int(ca[i] + (cb[i] - ca[i]) * k) for i in range(3))
            break
    d.line([(0, y), (S, y)], fill=c)
for (x, y, r) in [(780, 150, 9), (250, 210, 6), (600, 110, 5)]:
    d.ellipse([x - r, y - r, x + r, y + r], fill=(0xFF, 0xF6, 0xDD))

U = 118  # 1 升の大きさ
ox, oy = S / 2 - 40, 720
def P(u, w, h):
    return (ox + (u - w) * 0.866 * U, oy + (u + w) * 0.5 * U - h * U)

walls = {
    'terra': ((0xEB, 0xA5, 0x84), (0xCD, 0x6E, 0x52), (0xA9, 0x54, 0x3F)),
    'mint': ((0xB7, 0xE0, 0xCE), (0x84, 0xBF, 0xA8), (0x5F, 0x9C, 0x86)),
    'sand': ((0xF5, 0xE6, 0xCB), (0xDC, 0xC6, 0xA2), (0xBD, 0xA4, 0x7F)),
    'plum': ((0xB4, 0x9B, 0xC4), (0x8E, 0x74, 0xA2), (0x6F, 0x57, 0x83)),
}
# (u, w, z, 材料)：真ん中の塔と、宙に浮く橋
cubes = [(0, 0, 0, 'terra'), (0, 0, 1, 'terra'), (0, 0, 2, 'terra'), (-1, 0, 0, 'sand'), (0, -1, 0, 'mint'),
         (1, -1, 1, 'plum'), (1, -2, 1, 'plum')]
cubes.sort(key=lambda c: c[0] + c[1] + c[2])
line = (0x56, 0x41, 0x6A)
for (u, w, z, m) in cubes:
    top, left, right = walls[m]
    t = [P(u - .5, w - .5, z + 1), P(u + .5, w - .5, z + 1), P(u + .5, w + .5, z + 1), P(u - .5, w + .5, z + 1)]
    fr = [P(u + .5, w - .5, z), P(u + .5, w + .5, z), P(u + .5, w + .5, z + 1), P(u + .5, w - .5, z + 1)]  # +u 面
    fl = [P(u - .5, w + .5, z), P(u + .5, w + .5, z), P(u + .5, w + .5, z + 1), P(u - .5, w + .5, z + 1)]  # +w 面
    d.polygon(fr, fill=right, outline=line)
    d.polygon(fl, fill=left, outline=line)
    d.polygon(t, fill=top, outline=line)
# 屋根
u, w, z = 0, 0, 3
apex = P(u, w, z + 0.75)
d.polygon([P(u + .55, w - .55, z), P(u + .55, w + .55, z), apex], fill=(0x8E, 0x4A, 0x3B))
d.polygon([P(u - .55, w + .55, z), P(u + .55, w + .55, z), apex], fill=(0xB9, 0x65, 0x4E))
# 窓の猫：+w 面（左の面）の 2 段目に、面に沿ったアーチ窓と光る 2 つの目
def F(su, h):  # +w 面の上の点：su は横（-0.5〜0.5）、h は高さ
    return P(su, 0.5, h)
arch = [F(-0.32, 1.1), F(0.32, 1.1), F(0.32, 1.52)] + [F(0.32 * math.cos(a), 1.52 + 0.3 * math.sin(a)) for a in [i / 10 * math.pi for i in range(1, 11)]]
d.polygon(arch, fill=(0x3B, 0x2C, 0x47))
sil = (0x1E, 0x16, 0x26)
cx, cy = F(0, 1.42)
d.polygon([F(0.24 * math.cos(a), 1.38 + 0.2 * math.sin(a)) for a in [i / 16 * 2 * math.pi for i in range(16)]], fill=sil)
d.polygon([F(-0.22, 1.45), F(-0.19, 1.7), F(-0.06, 1.55)], fill=sil)
d.polygon([F(0.22, 1.45), F(0.19, 1.7), F(0.06, 1.55)], fill=sil)
for su in (-0.1, 0.1):
    ex, ey = F(su, 1.42)
    d.ellipse([ex - 8, ey - 8, ex + 8, ey + 8], fill=(0xF6, 0xCE, 0x76))
out = Path(__file__).resolve().parent.parent / 'App/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png'
img.save(out)
print('saved', out)
