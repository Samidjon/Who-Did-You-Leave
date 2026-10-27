#!/usr/bin/env python3
"""Процедурные текстуры-заглушки для «Кого ты оставил?».

Все изображения создаются с нуля (шум + геометрия), поэтому их можно
свободно использовать и позже заменить на настоящие фотоматериалы.
Тайлящиеся текстуры строятся на периодическом шуме (через FFT),
поэтому не дают швов при триплanarном наложении.

Запуск:  python3 tools/gen_textures.py <путь_к_проекту>
"""
import sys, os, math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = sys.argv[1] if len(sys.argv) > 1 else "."
OUT = os.path.join(ROOT, "assets", "textures")
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(1998)
N = 512
FONT_DIR = "/usr/share/fonts/truetype/dejavu/"


def pnoise(size=N, beta=2.0, aniso=(1.0, 1.0), seed=None):
    """Периодический (тайлящийся) шум со спектром 1/f^beta. Возвращает 0..1."""
    r = np.random.default_rng(seed) if seed is not None else rng
    w = r.standard_normal((size, size))
    F = np.fft.fft2(w)
    fy = np.fft.fftfreq(size)[:, None] * aniso[0]
    fx = np.fft.fftfreq(size)[None, :] * aniso[1]
    f = np.sqrt(fx * fx + fy * fy)
    f[0, 0] = 1.0
    F = F / (f ** (beta / 2.0))
    F[0, 0] = 0
    out = np.real(np.fft.ifft2(F))
    out -= out.min()
    out /= out.max() + 1e-9
    return out


def to_img(arr):
    return Image.fromarray(np.clip(arr * 255.0, 0, 255).astype(np.uint8))


def save(name, arr):
    to_img(arr).save(os.path.join(OUT, name))
    print("texture", name)


def colorize(base, rgb):
    return base[..., None] * np.array(rgb)[None, None, :]


def stains(img, amount=0.5, color=(0.55, 0.45, 0.28), seed=None):
    n = pnoise(beta=3.2, seed=seed)
    m = np.clip((n - (1.0 - amount * 0.5)) * 4.0, 0, 1)[..., None]
    ring = np.clip(1.0 - np.abs(n - (1.0 - amount * 0.5)) * 40.0, 0, 1)[..., None] * 0.25
    tint = np.array(color)[None, None, :]
    return img * (1 - m * 0.35) * (1 - ring * 0.5) + tint * m * 0.12


def grime(img, k=0.18, seed=None):
    n = pnoise(beta=2.4, seed=seed)
    return img * (1.0 - k + k * n[..., None])


# ---------------------------------------------------------------- обои
def wallpaper(name, bg, fg, stripe_period=64, motif="diamond", age=0.6, seed=0):
    y, x = np.mgrid[0:N, 0:N]
    img = np.ones((N, N, 3)) * np.array(bg)
    stripe = (np.sin(2 * np.pi * x / stripe_period) > 0.82).astype(float)
    img = img * (1 - stripe[..., None] * 0.10) + np.array(fg) * stripe[..., None] * 0.10
    cell = stripe_period
    cx = (x % cell) - cell / 2
    cy = (y % (cell * 2)) - cell
    if motif == "diamond":
        m = ((np.abs(cx) + np.abs(cy) * 0.5) < 9).astype(float)
        m2 = ((np.abs(cx) + np.abs(cy) * 0.5) < 6).astype(float)
        m = m - m2 * 0.7
    elif motif == "flower":
        rr = np.sqrt(cx ** 2 + cy ** 2)
        ang = np.arctan2(cy, cx)
        m = (rr < 8 + 4 * np.cos(5 * ang)).astype(float)
    else:
        m = np.zeros((N, N))
    m = np.array(Image.fromarray((m * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.8))) / 255.0
    img = img * (1 - m[..., None] * 0.35) + np.array(fg) * m[..., None] * 0.35
    # выцветание, неровная печать, пятна
    img = img * (0.92 + 0.08 * pnoise(beta=1.0, seed=seed + 1)[..., None])
    img = grime(img, 0.15 * age + 0.05, seed=seed + 2)
    img = stains(img, age * 0.6, seed=seed + 3)
    # желтизна к низу ячейки не нужна — триплан тайлит; лёгкая общая желтизна
    img = img * (1 - 0.12 * age) + np.array([0.6, 0.5, 0.3]) * 0.12 * age
    return img


# ---------------------------------------------------------------- краска
def painted_wall(base_rgb, chip_rgb=(0.78, 0.75, 0.68), chips=0.5, seed=10):
    streak = pnoise(beta=2.2, aniso=(6.0, 0.5), seed=seed)
    img = np.ones((N, N, 3)) * np.array(base_rgb)
    img = img * (0.9 + 0.12 * streak[..., None])
    n = pnoise(beta=2.6, seed=seed + 1)
    fine = pnoise(beta=1.2, seed=seed + 2)
    chipm = np.clip(((n * 0.7 + fine * 0.3) - (1.0 - chips * 0.25)) * 12, 0, 1)[..., None]
    edge = np.clip(1 - np.abs((n * 0.7 + fine * 0.3) - (1.0 - chips * 0.25)) * 60, 0, 1)[..., None]
    img = img * (1 - chipm) + np.array(chip_rgb) * chipm
    img = img * (1 - edge * 0.35)
    img = grime(img, 0.2, seed=seed + 3)
    return img


def whitewash(seed=20, tint=(0.80, 0.79, 0.74), stain=0.5):
    n = pnoise(beta=1.8, seed=seed)
    img = np.ones((N, N, 3)) * np.array(tint) * (0.9 + 0.1 * n[..., None])
    img = stains(img, stain, seed=seed + 1)
    return grime(img, 0.12, seed=seed + 2)


# ---------------------------------------------------------------- полы
def linoleum(seed=30):
    y, x = np.mgrid[0:N, 0:N]
    base = np.array([0.42, 0.24, 0.17])
    img = np.ones((N, N, 3)) * base
    tile = ((x // 128 + y // 128) % 2).astype(float)
    img = img * (1 - tile[..., None] * 0.06)
    speck = pnoise(beta=0.6, seed=seed)
    img = img * (0.9 + 0.15 * speck[..., None])
    wear = pnoise(beta=3.0, seed=seed + 1)
    wm = np.clip((wear - 0.55) * 3, 0, 1)[..., None]
    img = img * (1 - wm * 0.35) + np.array([0.45, 0.38, 0.30]) * wm * 0.35
    return grime(img, 0.2, seed=seed + 2)


def planks(seed=40, board_w=64, board_l=256, base=(0.38, 0.25, 0.14)):
    y, x = np.mgrid[0:N, 0:N]
    col = x // board_w
    offset = (col * 97) % board_l
    row = (y + offset) // board_l
    idx = col * 7 + row * 13
    tint = 0.82 + 0.25 * ((idx * 37) % 11) / 10.0
    grain = pnoise(beta=2.0, aniso=(0.3, 8.0), seed=seed)
    grain2 = pnoise(beta=1.0, aniso=(0.2, 6.0), seed=seed + 1)
    img = np.ones((N, N, 3)) * np.array(base)
    img = img * tint[..., None] * (0.8 + 0.3 * grain[..., None]) * (0.92 + 0.1 * grain2[..., None])
    gap_x = ((x % board_w) < 2).astype(float)
    gap_y = (((y + offset) % board_l) < 2).astype(float)
    gap = np.clip(gap_x + gap_y, 0, 1)[..., None]
    img = img * (1 - gap * 0.6)
    return grime(img, 0.18, seed=seed + 2)


def concrete(seed=50):
    n = pnoise(beta=2.0, seed=seed)
    pores = pnoise(beta=0.3, seed=seed + 1)
    pm = (pores > 0.93).astype(float)[..., None]
    img = np.ones((N, N, 3)) * np.array([0.46, 0.45, 0.43]) * (0.8 + 0.3 * n[..., None])
    img = img * (1 - pm * 0.4)
    return stains(img, 0.4, color=(0.3, 0.3, 0.28), seed=seed + 2)


def door_wood(seed=60, paint=(0.33, 0.20, 0.13)):
    grain = pnoise(beta=2.2, aniso=(0.25, 9.0), seed=seed)
    img = np.ones((N, N, 3)) * np.array(paint) * (0.85 + 0.25 * grain[..., None])
    scuff = pnoise(beta=2.8, seed=seed + 1)
    sm = np.clip((scuff - 0.7) * 5, 0, 1)[..., None]
    img = img * (1 - sm) + np.array([0.45, 0.35, 0.24]) * sm
    return grime(img, 0.25, seed=seed + 2)


def varnished_wood(seed=70):
    grain = pnoise(beta=2.3, aniso=(0.3, 10.0), seed=seed)
    rings = np.sin(grain * 40.0) * 0.5 + 0.5
    img = np.ones((N, N, 3)) * np.array([0.30, 0.17, 0.09])
    img = img * (0.75 + 0.2 * grain[..., None] + 0.12 * rings[..., None])
    return grime(img, 0.15, seed=seed + 1)


def metal(seed=80, base=(0.22, 0.24, 0.23)):
    n = pnoise(beta=2.0, seed=seed)
    img = np.ones((N, N, 3)) * np.array(base) * (0.85 + 0.25 * n[..., None])
    rust = pnoise(beta=2.8, seed=seed + 1)
    rm = np.clip((rust - 0.62) * 5, 0, 1)[..., None]
    img = img * (1 - rm) + np.array([0.36, 0.18, 0.08]) * rm
    return grime(img, 0.2, seed=seed + 2)


def fabric(seed=90, base=(0.32, 0.27, 0.30)):
    y, x = np.mgrid[0:N, 0:N]
    weave = (np.sin(x * np.pi / 2) * np.sin(y * np.pi / 2)) * 0.5 + 0.5
    n = pnoise(beta=1.6, seed=seed)
    check = (((x // 64) + (y // 64)) % 2).astype(float) * 0.06
    img = np.ones((N, N, 3)) * np.array(base) * (0.85 + 0.1 * weave[..., None] + 0.15 * n[..., None] - check[..., None])
    return grime(img, 0.2, seed=seed + 1)


def paper(seed=100):
    fib = pnoise(beta=1.0, aniso=(3.0, 0.5), seed=seed)
    n = pnoise(beta=2.5, seed=seed + 1)
    img = np.ones((N, N, 3)) * np.array([0.86, 0.83, 0.74]) * (0.94 + 0.04 * fib[..., None] + 0.04 * n[..., None])
    return stains(img, 0.35, seed=seed + 2)


def window_night():
    h = N
    y, x = np.mgrid[0:h, 0:N]
    sky = np.zeros((h, N, 3))
    t = y / h
    sky[...] = (np.array([0.05, 0.07, 0.12]) * (1 - t)[..., None] + np.array([0.10, 0.11, 0.15]) * t[..., None])
    img = Image.fromarray((sky * 255).astype(np.uint8))
    d = ImageDraw.Draw(img)
    r = np.random.default_rng(7)
    # силуэт дома напротив
    d.rectangle([0, 230, N, N], fill=(10, 11, 15))
    for bx in range(20, N - 30, 46):
        for by in range(250, N - 20, 52):
            if r.random() < 0.13:
                c = (int(150 + r.random() * 60), int(120 + r.random() * 40), 60)
                d.rectangle([bx, by, bx + 22, by + 28], fill=c)
            else:
                d.rectangle([bx, by, bx + 22, by + 28], fill=(16, 17, 22))
    img = img.filter(ImageFilter.GaussianBlur(2.2))
    img.save(os.path.join(OUT, "window_night.png"))
    print("texture window_night.png")


# ---------------------------------------------------------------- фотографии
def _sepia(img, strength=0.85):
    a = np.asarray(img).astype(float) / 255.0
    g = a.mean(axis=2)
    sep = np.stack([g * 1.07, g * 0.92, g * 0.72], axis=2)
    out = a * (1 - strength) + sep * strength
    return out


def _photo_finish(arr, seed):
    h, w = arr.shape[:2]
    r = np.random.default_rng(seed)
    grain = r.standard_normal((h, w))[..., None] * 0.045
    y, x = np.mgrid[0:h, 0:w]
    vig = 1 - 0.55 * (((x - w / 2) / (w / 2)) ** 2 + ((y - h / 2) / (h / 2)) ** 2) ** 1.2
    out = arr * np.clip(vig, 0.2, 1)[..., None] + grain
    out = np.clip(out, 0, 1)
    img = Image.fromarray((out * 255).astype(np.uint8))
    d = ImageDraw.Draw(img)
    for _ in range(14):
        x0, y0 = r.integers(0, w), r.integers(0, h)
        d.line([x0, y0, x0 + r.integers(-60, 60), y0 + r.integers(-90, 90)], fill=(230, 220, 200), width=1)
    # белая рамка
    framed = Image.new("RGB", (w + 36, h + 36), (222, 214, 196))
    framed.paste(img, (18, 18))
    return framed


def photo_yard(changed=False):
    w, h = 512, 384
    img = Image.new("RGB", (w, h), (150, 150, 140))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, w, 120], fill=(185, 185, 178))            # небо
    d.rectangle([0, 40, w, 270], fill=(118, 114, 104))           # фасад дома
    for i, wx in enumerate(range(20, w, 70)):
        for j, wy in enumerate(range(60, 250, 64)):
            fill = (62, 62, 60)
            d.rectangle([wx, wy, wx + 34, wy + 40], fill=fill)
            d.line([wx + 17, wy, wx + 17, wy + 40], fill=(130, 128, 118), width=2)
    d.rectangle([0, 270, w, h], fill=(96, 92, 80))               # двор
    d.rectangle([220, 180, 290, 270], fill=(52, 48, 42))         # подъезд
    people = [(110, 1.00, (60, 55, 50)), (175, 0.92, (80, 72, 62)), (330, 1.05, (45, 42, 40)), (400, 0.88, (70, 66, 60))]
    for px, s, c in people:
        top = int(300 - 120 * s)
        d.ellipse([px - 11 * s, top - 22 * s, px + 11 * s, top], fill=(150, 130, 110))
        d.rounded_rectangle([px - 22 * s, top, px + 22 * s, 340], radius=8, fill=c)
        d.rectangle([px - 14 * s, 340, px - 4 * s, 372], fill=(40, 38, 36))
        d.rectangle([px + 4 * s, 340, px + 14 * s, 372], fill=(40, 38, 36))
    # пожилой человек со скамейкой у подъезда — Г. П.
    d.rectangle([236, 300, 300, 312], fill=(70, 60, 50))
    d.ellipse([256, 228, 278, 250], fill=(160, 140, 120))
    d.rounded_rectangle([250, 250, 284, 312], radius=6, fill=(58, 58, 64))
    if changed:
        # новая деталь: в окне третьего этажа над подъездом — фигура;
        # лицо человека слева (Андрей) затёрто.
        wx, wy = 230, 124
        d.rectangle([wx, wy, wx + 34, wy + 40], fill=(28, 28, 28))
        d.ellipse([wx + 10, wy + 6, wx + 24, wy + 20], fill=(120, 112, 100))
        d.rectangle([wx + 7, wy + 20, wx + 27, wy + 40], fill=(70, 66, 60))
        px, s = 400, 0.88
        top = int(300 - 120 * s)
        d.ellipse([px - 14, top - 24, px + 14, top + 2], fill=(205, 198, 182))
        for k in range(9):
            d.line([px - 14 + k * 3, top - 22, px - 10 + k * 3, top + 2], fill=(235, 230, 215), width=2)
    img = img.filter(ImageFilter.GaussianBlur(1.6))
    arr = _sepia(img)
    out = _photo_finish(arr, 11)
    name = "photo_yard_changed.png" if changed else "photo_yard.png"
    out.save(os.path.join(OUT, name))
    print("texture", name)


def photo_portrait():
    w, h = 300, 400
    img = Image.new("RGB", (w, h), (120, 118, 112))
    d = ImageDraw.Draw(img)
    d.ellipse([95, 70, 205, 200], fill=(170, 150, 130))
    d.rectangle([70, 200, 230, 400], fill=(55, 55, 60))
    d.polygon([(130, 200), (150, 260), (170, 200)], fill=(200, 196, 186))
    d.rectangle([120, 120, 140, 128], fill=(90, 80, 70))
    d.rectangle([160, 120, 180, 128], fill=(90, 80, 70))
    # медаль
    d.ellipse([90, 250, 110, 270], fill=(170, 150, 90))
    img = img.filter(ImageFilter.GaussianBlur(2.0))
    arr = _sepia(img, 0.95)
    _photo_finish(arr, 12).save(os.path.join(OUT, "photo_portrait.png"))
    print("texture photo_portrait.png")


def calendar():
    w, h = 384, 512
    base = (paper()[:h, :w] * 255).astype(np.uint8)
    img = Image.fromarray(base)
    d = ImageDraw.Draw(img)
    fb = ImageFont.truetype(FONT_DIR + "DejaVuSerif-Bold.ttf", 40)
    f = ImageFont.truetype(FONT_DIR + "DejaVuSans.ttf", 22)
    d.rectangle([0, 0, w, 120], fill=(120, 40, 34))
    d.text((w / 2, 44), "АПРЕЛЬ", font=fb, fill=(235, 225, 210), anchor="mm")
    d.text((w / 2, 92), "1998", font=f, fill=(235, 225, 210), anchor="mm")
    days = ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"]
    for i, dn in enumerate(days):
        d.text((32 + i * 52, 148), dn, font=f, fill=(90, 70, 60), anchor="mm")
    day = 1
    start = 2  # 1 апреля 1998 — среда
    for row in range(5):
        for col in range(7):
            cell = row * 7 + col
            if cell < start or day > 30:
                continue
            cx, cy = 32 + col * 52, 196 + row * 60
            d.text((cx, cy), str(day), font=f, fill=(40, 35, 30), anchor="mm")
            if 14 <= day <= 22:
                d.line([cx - 16, cy - 16, cx + 16, cy + 16], fill=(30, 30, 90), width=3)
                d.line([cx + 16, cy - 16, cx - 16, cy + 16], fill=(30, 30, 90), width=3)
            day += 1
        if day > 30:
            break
    img.save(os.path.join(OUT, "calendar_1998.png"))
    print("texture calendar_1998.png")


def scratches_marks():
    """Следы на обоях кв. 13: группы по три вертикальные царапины."""
    img = wallpaper("x", (0.62, 0.52, 0.50), (0.45, 0.33, 0.33), 48, "flower", 1.0, 200)
    pil = to_img(img)
    d = ImageDraw.Draw(pil)
    r = np.random.default_rng(3)
    for gx in range(30, N - 40, 70):
        for gy in range(40, N - 80, 120):
            if r.random() < 0.55:
                for k in range(3):
                    x0 = gx + k * 9
                    d.line([x0, gy, x0 + r.integers(-3, 3), gy + 55], fill=(70, 50, 40), width=2)
    pil.save(os.path.join(OUT, "wallpaper_13_marks.png"))
    print("texture wallpaper_13_marks.png")


if __name__ == "__main__":
    save("wallpaper_a.png", wallpaper("a", (0.63, 0.62, 0.50), (0.42, 0.45, 0.33), 64, "diamond", 0.6, 1))
    save("wallpaper_b.png", wallpaper("b", (0.58, 0.48, 0.38), (0.40, 0.28, 0.20), 64, "flower", 0.7, 2))
    save("wallpaper_c.png", wallpaper("c", (0.52, 0.55, 0.57), (0.34, 0.38, 0.42), 32, "none", 0.5, 3))
    save("wallpaper_start.png", wallpaper("s", (0.60, 0.57, 0.52), (0.48, 0.40, 0.36), 128, "diamond", 0.55, 4))
    scratches_marks()
    save("paint_green.png", painted_wall((0.27, 0.38, 0.33), chips=0.6, seed=10))
    save("paint_blue.png", painted_wall((0.26, 0.33, 0.40), chips=0.5, seed=12))
    save("paint_grey.png", painted_wall((0.42, 0.42, 0.40), chips=0.4, seed=14))
    save("whitewash.png", whitewash())
    save("ceiling.png", whitewash(seed=24, tint=(0.74, 0.73, 0.69), stain=0.7))
    save("linoleum.png", linoleum())
    save("parquet.png", planks())
    save("concrete.png", concrete())
    save("door_wood.png", door_wood())
    save("door_wood_green.png", door_wood(seed=64, paint=(0.22, 0.27, 0.20)))
    save("wood_varnish.png", varnished_wood())
    save("metal_painted.png", metal())
    save("metal_rust.png", metal(seed=84, base=(0.30, 0.24, 0.20)))
    save("fabric_a.png", fabric())
    save("fabric_b.png", fabric(seed=94, base=(0.28, 0.30, 0.26)))
    save("paper.png", paper())
    window_night()
    photo_yard(False)
    photo_yard(True)
    photo_portrait()
    calendar()
