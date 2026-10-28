"""Draws the ZoeziDesk app icons from the logo mark.

The mark (assets/logo/*.svg, the left 48 x 48 of the wordmark) is ten
rounded squares: two white rows and an orange diagonal making a "Z". It is
drawn here directly, with 4x supersampling, so no image library is needed.

    python tool/make_icons.py

Writes Android launcher icons (legacy and adaptive, with a monochrome layer
for themed icons), the launch-screen mark, and a 512 px store icon.
"""

import os
import struct
import zlib

NAVY = (0x0D, 0x1E, 0x2E, 255)   # brand navy, from the light logo
WHITE = (255, 255, 255, 255)
ORANGE = (0xF9, 0x73, 0x16, 255)

# (x, y, colour) in the SVG's 48-unit grid; each square is 9 x 9, radius 2.
SQUARES = [(x, 1.5, WHITE) for x in (1.5, 13.5, 25.5, 37.5)] + \
          [(x, 37.5, WHITE) for x in (1.5, 13.5, 25.5, 37.5)] + \
          [(25.5, 13.5, ORANGE), (13.5, 25.5, ORANGE)]
MARK = (1.5, 46.5)   # extent of the mark in the grid
SS = 4               # supersampling factor

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RES = os.path.join(ROOT, 'android', 'app', 'src', 'main', 'res')
DENSITIES = {'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2, 'xxhdpi': 3, 'xxxhdpi': 4}


def inside_round_rect(px, py, x, y, w, h, r):
    if px < x or py < y or px > x + w or py > y + h:
        return False
    cx = min(max(px, x + r), x + w - r)
    cy = min(max(py, y + r), y + h - r)
    return (px - cx) ** 2 + (py - cy) ** 2 <= r * r


def render(size, mark_px, background=None, bg_radius=0.0, mono=False):
    """A size x size RGBA image with the mark mark_px wide, centred."""
    big = size * SS
    scale = mark_px * SS / (MARK[1] - MARK[0])
    offset = (big - mark_px * SS) / 2 - MARK[0] * scale
    shapes = [(x * scale + offset, y * scale + offset, 9 * scale, 9 * scale, 2 * scale,
               WHITE if mono else c) for x, y, c in SQUARES]
    rows = []
    for y in range(size):
        row = bytearray()
        for x in range(size):
            acc = [0, 0, 0, 0]
            for sy in range(SS):
                for sx in range(SS):
                    px, py = x * SS + sx + 0.5, y * SS + sy + 0.5
                    colour = None
                    for (rx, ry, rw, rh, rr, c) in shapes:
                        if inside_round_rect(px, py, rx, ry, rw, rh, rr):
                            colour = c
                            break
                    if colour is None and background is not None and \
                            inside_round_rect(px, py, 0, 0, big, big, bg_radius * big):
                        colour = background
                    if colour is not None:
                        for i in range(3):
                            acc[i] += colour[i] * colour[3]
                        acc[3] += colour[3]
            n = SS * SS
            a = acc[3] / n
            if acc[3]:
                row += bytes(round(acc[i] / acc[3]) for i in range(3)) + bytes([round(a)])
            else:
                row += b'\x00\x00\x00\x00'
        rows.append(bytes(row))
    return rows


def write_png(path, rows):
    h, w = len(rows), len(rows[0]) // 4
    raw = b''.join(b'\x00' + r for r in rows)

    def chunk(tag, data):
        return struct.pack('>I', len(data)) + tag + data + struct.pack('>I', zlib.crc32(tag + data) & 0xFFFFFFFF)

    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'wb') as f:
        f.write(b'\x89PNG\r\n\x1a\n')
        f.write(chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 6, 0, 0, 0)))
        f.write(chunk(b'IDAT', zlib.compress(raw, 9)))
        f.write(chunk(b'IEND', b''))
    print('wrote', os.path.relpath(path, ROOT))


def main():
    for name, d in DENSITIES.items():
        mip = os.path.join(RES, f'mipmap-{name}')
        # Legacy icon (Android 7 and older): navy rounded square.
        s = round(48 * d)
        write_png(os.path.join(mip, 'ic_launcher.png'), render(s, s * 0.56, NAVY, 0.22))
        # Adaptive layers are 108 dp; keep the mark inside the 66 dp safe
        # circle (a square fits if its side is at most 66 / sqrt 2 = 46 dp).
        s = round(108 * d)
        write_png(os.path.join(mip, 'ic_launcher_foreground.png'), render(s, 44 * d))
        write_png(os.path.join(mip, 'ic_launcher_monochrome.png'), render(s, 44 * d, mono=True))
        # Launch screen before Flutter starts (Android 11 and older).
        s = round(96 * d)
        write_png(os.path.join(RES, f'drawable-{name}', 'launch_mark.png'), render(s, 72 * d))
    # Google Play listing icon (full square; Play applies its own mask).
    write_png(os.path.join(ROOT, 'store', 'icon-512.png'), render(512, 512 * 0.56, NAVY))


if __name__ == '__main__':
    main()
