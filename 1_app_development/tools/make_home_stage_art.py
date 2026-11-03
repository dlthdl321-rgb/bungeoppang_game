"""Home stage art for the 메인UI mockup (3.5_completed_game_mockups).

Writes, from art already in the repository:
  assets/images/bg_clean/clear.png  the clear background with no mold on the
      counter: the street of 미분류생성이미지05 (frame 1) above the counter
      edge, the empty counter of 손님모션01 below it.
  assets/images/mold/<state>.png  a single big iron mold for the cooking
      steps, drawn on an 8 px grid around fish/redbean.png so the fish fits
      its cavity exactly (MOLD_FISH below = WorkshopMoldArt.fishRect).

Other backgrounds have no mold-free source yet; they keep their baked art.

  python tools/make_home_stage_art.py   (run from 1_app_development)
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

APP = Path(__file__).resolve().parents[1]
REF = APP.parent / '3_original_images_and_visual_references' / '3.2_visual_design_references_20261006'
IMAGES = APP / 'assets' / 'images'

# Counter edge row of the 335x762 concept cuts.
COUNTER_EDGE = 375


def clean_clear():
    street = Image.open(REF / '01_원본전체' / '미분류생성이미지05_원본_261006_1905_01.png').convert('RGB')
    street = street.crop((3, 3, 338, 765))
    counter = Image.open(REF / '05_손님프레임' / '손님모션01_컷_261006_1905_01.png').convert('RGB')
    out = counter.crop((0, 0, 335, 762))
    out.paste(street.crop((0, 0, 335, COUNTER_EDGE)), (0, 0))
    (IMAGES / 'bg_clean').mkdir(exist_ok=True)
    out.save(IMAGES / 'bg_clean' / 'clear.png')


# --- mold -------------------------------------------------------------------
GRID = 8
W, H = 1200, 880
FISH_AT = (100, 66)          # top-left of fish/redbean.png in the mold canvas
IRON = [(18, 15, 16), (37, 32, 33), (52, 46, 47), (68, 61, 62), (92, 84, 84), (124, 114, 112)]


def grid_mask(mask, dilate=0):
    """Full-size bool mask -> grid mask (any pixel set), optionally grown."""
    g = Image.fromarray((mask * 255).astype('uint8')).resize((W // GRID, H // GRID), Image.BOX)
    g = np.array(g) > 40
    if dilate:
        im = Image.fromarray((g * 255).astype('uint8')).filter(ImageFilter.MaxFilter(dilate * 2 + 1))
        g = np.array(im) > 0
    return g


def ellipse(gw, gh, cx, cy, rx, ry):
    y, x = np.mgrid[0:gh, 0:gw]
    return ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1


def up(grid_rgba):
    return Image.fromarray(grid_rgba).resize((W, H), Image.NEAREST)


def build_mold():
    fish = Image.open(IMAGES / 'fish' / 'redbean.png').convert('RGBA')
    canvas_fish = Image.new('RGBA', (W, H))
    canvas_fish.paste(fish, FISH_AT)
    fa = np.array(canvas_fish)
    fish_mask = fa[:, :, 3] > 128
    gw, gh = W // GRID, H // GRID
    cavity = grid_mask(fish_mask)
    body = grid_mask(fish_mask, dilate=7)
    ys, xs = np.where(cavity)
    cy = (ys.min() + ys.max()) / 2
    lug_l = ellipse(gw, gh, xs.min() - 10, cy, 11, 9)
    lug_r = ellipse(gw, gh, xs.max() + 9, cy, 11, 9)
    hole_l = ellipse(gw, gh, xs.min() - 13, cy, 3.6, 3.6)
    hole_r = ellipse(gw, gh, xs.max() + 12, cy, 3.6, 3.6)
    body = (body | lug_l | lug_r) & ~hole_l & ~hole_r

    rng = np.random.default_rng(7)
    base = np.zeros((gh, gw, 4), 'uint8')
    r = rng.random((gh, gw))
    tone = np.where(r < .22, 3, np.where(r > .85, 1, 2))
    tone = np.where(r < .03, 4, tone)
    # light from the top-left: two-cell bevel, highlight up-left, shadow down-right
    def shifted(dy, dx):
        return np.roll(np.roll(body, dy, 0), dx, 1)
    tone = np.where(body & ~shifted(2, 2), 3, tone)
    tone = np.where(body & ~shifted(1, 1), 5, tone)
    tone = np.where(body & ~shifted(-2, -2), 1, tone)
    tone = np.where(body & ~shifted(-1, -1), 0, tone)
    # the groove's far side catches light, its near side is in shadow
    cav1 = grid_mask(fish_mask, dilate=2)
    tone = np.where(body & cav1 & ~np.roll(np.roll(cav1, -2, 0), -2, 1), 4, tone)
    pal = np.array(IRON, 'uint8')
    base[..., :3] = pal[np.clip(tone, 0, 5)]
    base[..., 3] = body * 255
    # 1-cell dark outline
    outline = Image.fromarray((body * 255).astype('uint8')).filter(ImageFilter.MaxFilter(3))
    outline = (np.array(outline) > 0) & ~body
    base[outline] = (*IRON[0], 255)
    # hole rims
    for hole in (hole_l, hole_r):
        rim = np.array(Image.fromarray((hole * 255).astype('uint8')).filter(ImageFilter.MaxFilter(3))) > 0
        base[rim & ~hole] = (*IRON[0], 255)
    # cavity rim: dark groove around the fish
    groove = grid_mask(fish_mask, dilate=1) & ~cavity
    base[groove] = (*IRON[1], 255)
    plate = up(base)

    # soft shadow on the counter
    shadow = Image.new('RGBA', (W, H))
    sm = Image.fromarray((np.array(plate)[:, :, 3] > 0).astype('uint8') * 110).filter(ImageFilter.GaussianBlur(18))
    shadow.putalpha(sm)
    shadow = shadow.transform((W, H), Image.AFFINE, (1, 0, -10, 0, 1, -28))
    plate_all = Image.alpha_composite(shadow, plate)

    lum = (fa[..., :3].astype(float) @ [0.3, 0.55, 0.15]) / 255
    lum = (lum - lum[fish_mask].min()) / (np.ptp(lum[fish_mask]) or 1)

    edge_d = np.array(Image.fromarray((fish_mask * 255).astype('uint8')).filter(ImageFilter.GaussianBlur(14))) / 255.0

    def recolor(dark, light, contrast=1.0, rim=0.0):
        l = np.clip(0.5 + (lum - 0.5) * contrast, 0, 1)
        # batter browns where it touches the hot iron
        l = l - rim * np.clip(1 - edge_d * 1.6, 0, 1)
        l = np.clip(l, 0, 1)[..., None]
        rgb = np.array(dark) * (1 - l) + np.array(light) * l
        out = np.zeros((H, W, 4), 'uint8')
        out[..., :3] = rgb.astype('uint8')
        out[..., 3] = np.where(fish_mask, 255, 0)
        return Image.fromarray(out)

    def blob(cx, cy, rx, ry, fill, edge, seed):
        r = np.random.default_rng(seed)
        y, x = np.mgrid[0:gh, 0:gw]
        ang = np.arctan2((y - cy) / ry, (x - cx) / rx)
        wob = 1 + .18 * np.sin(ang * 3 + seed) + .1 * np.sin(ang * 5 + 2 * seed)
        m = (((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2) <= wob ** 2
        m &= cavity
        g = np.zeros((gh, gw, 4), 'uint8')
        g[m] = (*fill, 255)
        e = m & ~(np.roll(m, 1, 0) & np.roll(m, -1, 0) & np.roll(m, 1, 1) & np.roll(m, -1, 1))
        g[e] = (*edge, 255)
        spots = m & ~e & (r.random((gh, gw)) < .12)
        g[spots] = (*np.clip(np.array(fill) + 30, 0, 255), 255)
        return up(g)

    fcx = (xs.min() + xs.max()) / 2 - 2
    states = {
        'empty': recolor((14, 12, 13), (64, 58, 58), 1.1),
        'batter': recolor((176, 128, 64), (246, 226, 172), .45, rim=.9),
        'batter_top': recolor((190, 140, 70), (252, 234, 184), .3, rim=.8),
        'closed': None,
    }
    out = {}
    for name, inner in states.items():
        if inner is None:
            lid = recolor((40, 35, 36), (118, 108, 106), .9)
            img = Image.alpha_composite(plate_all, lid)
        else:
            img = Image.alpha_composite(plate_all, inner)
        out[name] = img
    for flavor, fill, edge in [('redbean', (98, 40, 36), (58, 22, 20)),
                               ('custard', (246, 206, 92), (196, 146, 50)),
                               ('cocoa', (92, 54, 32), (52, 28, 16))]:
        out[f'filling_{flavor}'] = Image.alpha_composite(out['batter'], blob(fcx, cy, 15, 8, fill, edge, 3))
    (IMAGES / 'mold').mkdir(exist_ok=True)
    for name, img in out.items():
        img.save(IMAGES / 'mold' / f'{name}.png')
    fy, fx = np.where(fish_mask)
    print('fish body in mold canvas:', fx.min(), fy.min(), fx.max() + 1, fy.max() + 1, 'canvas', W, H)


if __name__ == '__main__':
    clean_clear()
    build_mold()
