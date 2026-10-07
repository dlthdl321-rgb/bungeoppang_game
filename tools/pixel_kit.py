"""Small pixel-art drawing kit shared by the art modules.

Shapes are boolean masks; painting fills a mask with a palette color.
Outlines are colored per object (the darkest step of its ramp), which gives
the soft storybook look instead of black lines.
"""

import math

import numpy as np
from PIL import Image, ImageDraw

from palette import PALETTE


def rgba(name):
    h = PALETTE[name]
    return (int(h[1:3], 16), int(h[3:5], 16), int(h[5:7], 16), 255)


def shifted(m, dx, dy):
    """out[y, x] = m[y + dy, x + dx]; outside the image counts as empty."""
    out = np.zeros_like(m)
    h, w = m.shape
    ys, yd = (slice(dy, h), slice(0, h - dy)) if dy >= 0 else (slice(0, h + dy), slice(-dy, h))
    xs, xd = (slice(dx, w), slice(0, w - dx)) if dx >= 0 else (slice(0, w + dx), slice(-dx, w))
    out[yd, xd] = m[ys, xs]
    return out


def edge(m, dx, dy):
    """Pixels of `m` whose neighbour in direction (dx, dy) is outside `m`."""
    return m & ~shifted(m, dx, dy)


def grow(m, n=1):
    for _ in range(n):
        m = m | shifted(m, 1, 0) | shifted(m, -1, 0) | shifted(m, 0, 1) | shifted(m, 0, -1)
    return m


class Sprite:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.a = np.zeros((h, w, 4), np.uint8)
        self.ys, self.xs = np.mgrid[0:h, 0:w]

    # masks
    def empty(self):
        return np.zeros((self.h, self.w), bool)

    def ellipse(self, cx, cy, rx, ry):
        return ((self.xs + .5 - cx) / rx) ** 2 + ((self.ys + .5 - cy) / ry) ** 2 <= 1

    def circle(self, cx, cy, r):
        return self.ellipse(cx, cy, r, r)

    def rect(self, x, y, w, h):
        return (self.xs >= x) & (self.xs < x + w) & (self.ys >= y) & (self.ys < y + h)

    def rrect(self, x, y, w, h, r):
        """Rounded rectangle with corner radius r."""
        m = self.rect(x + r, y, w - 2 * r, h) | self.rect(x, y + r, w, h - 2 * r)
        for cx, cy in [(x + r, y + r), (x + w - r, y + r), (x + r, y + h - r), (x + w - r, y + h - r)]:
            m |= self.circle(cx, cy, r)
        return m & self.rect(x, y, w, h)

    def poly(self, pts):
        im = Image.new("1", (self.w, self.h), 0)
        ImageDraw.Draw(im).polygon(pts, fill=1, outline=1)
        return np.array(im, bool)

    def line(self, pts, width=1):
        im = Image.new("1", (self.w, self.h), 0)
        ImageDraw.Draw(im).line(pts, fill=1, width=width)
        return np.array(im, bool)

    def checker(self, phase=0):
        return (self.xs + self.ys + phase) % 2 == 0

    def sparse(self, step=4, phase=0):
        """A thin ordered-dither pattern (1 of step*step/2 pixels)."""
        return ((self.xs + phase) % step == 0) & ((self.ys + (self.xs // step) * (step // 2)) % step == 0)

    @property
    def solid(self):
        return self.a[..., 3] > 0

    # painting
    def fill(self, mask, color):
        self.a[mask] = rgba(color)

    def put(self, x, y, color):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.a[y, x] = rgba(color)

    def pixels(self, pts, color):
        for x, y in pts:
            self.put(x, y, color)

    def outline(self, color, mask=None):
        """1px outline around `mask` (default: everything drawn so far)."""
        m = self.solid if mask is None else mask
        ring = grow(m) & ~m
        if mask is None:
            ring &= ~self.solid
        self.fill(ring, color)

    def art(self, x, y, rows, colors):
        """Stamp ASCII art; '.' is transparent."""
        for j, row in enumerate(rows):
            for i, ch in enumerate(row):
                if ch != ".":
                    self.put(x + i, y + j, colors[ch])

    def paste(self, other, x=0, y=0):
        for j in range(other.h):
            for i in range(other.w):
                if other.a[j, i, 3] and 0 <= x + i < self.w and 0 <= y + j < self.h:
                    self.a[y + j, x + i] = other.a[j, i]

    def save(self, path):
        path.parent.mkdir(parents=True, exist_ok=True)
        Image.fromarray(self.a, "RGBA").save(path)


def soft_shade(s, m, ramp, light_from=(-1, -1)):
    """Fill `m` with a 4-step ramp (highlight, light, base, shade).

    Light comes from the top-left: a light band on the lit edges, a small
    highlight inside it, and shade on the far edges.
    """
    hi, light, base, shade = ramp
    lx, ly = light_from
    s.fill(m, base)
    s.fill(m & (edge(m, 0, 3 * ly) | edge(m, 2 * lx, 0)), light)
    s.fill(m & (edge(m, 0, -3 * ly) | edge(m, -2 * lx, 0)), shade)
    s.fill(m & edge(m, 0, ly) & ~edge(m, lx, 0) & (s.xs < np.median(s.xs[m]) if m.any() else m), hi)


def glow(s, cx, cy, r, inner, outer, solid_r=0):
    """Dithered halo: a solid core, a checker ring, then a sparse ring."""
    if solid_r:
        s.fill(s.circle(cx, cy, solid_r), inner)
    s.fill(s.circle(cx, cy, r * .65) & ~s.circle(cx, cy, solid_r or 0.1) & s.checker(), inner)
    s.fill(s.circle(cx, cy, r) & ~s.circle(cx, cy, r * .65) & s.sparse(2), outer)


def sparkle(s, x, y, color="white", big=False):
    s.pixels([(x, y - 1), (x - 1, y), (x, y), (x + 1, y), (x, y + 1)], color)
    if big:
        s.pixels([(x, y - 2), (x - 2, y), (x + 2, y), (x, y + 2)], color)


def heart(s, x, y, color, size=1):
    """A heart with its top-left at (x, y); size 1 is 5x4, size 2 is 7x6."""
    rows = {1: [".x.x.", "xxxxx", ".xxx.", "..x.."],
            2: [".xx.xx.", "xxxxxxx", "xxxxxxx", ".xxxxx.", "..xxx..", "...x..."]}[size]
    s.art(x, y, rows, {"x": color})


def star_points(cx, cy, r, inner_r, points=5, rot=-90):
    pts = []
    for i in range(points * 2):
        a = math.radians(rot + i * 180 / points)
        rr = r if i % 2 == 0 else inner_r
        pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
    return pts


def arc_points(cx, cy, rx, ry, a0, a1, steps=60):
    pts = []
    for i in range(steps + 1):
        a = math.radians(a0 + (a1 - a0) * i / steps)
        p = (round(cx + rx * math.cos(a) - .5), round(cy + ry * math.sin(a) - .5))
        if p not in pts:
            pts.append(p)
    return pts


def sag(x, x0, x1, y0, depth):
    t = (x - x0) / (x1 - x0)
    return round(y0 + depth * 4 * t * (1 - t))
