"""Monta las miniaturas e icono llamativos con las capas de brainrot_art.py: fondo de rayos de color,
personajes con contorno blanco y brillo, flecha roja y texto enorme.

Uso (necesita Pillow):
    python tools/blender/brainrot_text.py assets/marketing/layers assets/marketing

Fuente (Google Fonts, licencia Apache 2.0): Luckiest Guy. Se descarga sola a tools/blender/.fonts.
"""

import math
import os
import sys
import urllib.request

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageFont

FONT = "apache/luckiestguy/LuckiestGuy-Regular.ttf"
FONT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), ".fonts")
NAME = "SLENDERMAN.EXE"

YELLOW = (255, 230, 0)
WHITE = (255, 255, 255)
RED = (235, 20, 30)
BLACK = (0, 0, 0)

# miniatura -> (lema en inglés, en español)
TAGLINES = {
    1: ("RUN!!!", "¡CORRE!"),
    2: ("CAN YOU ESCAPE?", "¿PUEDES ESCAPAR?"),
    3: ("DON'T LOOK BACK!", "¡NO MIRES ATRÁS!"),
}


def font(size):
    path = os.path.join(FONT_DIR, os.path.basename(FONT))
    if not os.path.exists(path):
        os.makedirs(FONT_DIR, exist_ok=True)
        urllib.request.urlretrieve("https://raw.githubusercontent.com/google/fonts/main/" + FONT, path)
    return ImageFont.truetype(path, size)


def burst(size, center, inner, outer, ray, rays=24):
    """Fondo de rayos que salen de center, con degradado radial de inner a outer."""
    w, h = size
    img = Image.new("RGB", size, outer)
    grad = Image.radial_gradient("L").resize((w * 2, w * 2))
    grad = grad.crop((w - center[0], w - center[1], w - center[0] + w, w - center[1] + h))
    img = Image.composite(Image.new("RGB", size, outer), Image.new("RGB", size, inner), grad)
    layer = Image.new("RGBA", size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    r = math.hypot(w, h) * 1.2
    for i in range(rays):
        a0 = 2 * math.pi * i / rays
        a1 = a0 + math.pi / rays
        d.polygon([center, (center[0] + r * math.cos(a0), center[1] + r * math.sin(a0)),
                   (center[0] + r * math.cos(a1), center[1] + r * math.sin(a1))], fill=(*ray, 70))
    img = img.convert("RGBA")
    img.alpha_composite(layer)
    return img


def sticker(layer, scale, outline=10, glow=(255, 255, 255), glow_radius=18, saturation=1.35):
    """Capa escalada con más color, contorno blanco grueso y halo."""
    w, h = layer.size
    layer = layer.resize((int(w * scale), int(h * scale)), Image.LANCZOS)
    rgb = ImageEnhance.Contrast(ImageEnhance.Color(layer.convert("RGB")).enhance(saturation)).enhance(1.1)
    layer = Image.merge("RGBA", (*rgb.split(), layer.getchannel("A")))
    pad = outline + glow_radius * 2
    canvas = Image.new("RGBA", (layer.width + pad * 2, layer.height + pad * 2), (0, 0, 0, 0))
    alpha = Image.new("L", canvas.size, 0)
    alpha.paste(layer.getchannel("A"), (pad, pad))
    alpha = alpha.point(lambda v: 255 if v > 90 else 0)
    thick = alpha.filter(ImageFilter.MaxFilter(outline * 2 + 1))
    halo = Image.new("RGBA", canvas.size, (*glow, 255))
    halo.putalpha(thick.filter(ImageFilter.GaussianBlur(glow_radius)))
    canvas.alpha_composite(halo)
    canvas.alpha_composite(halo)
    stroke = Image.new("RGBA", canvas.size, (255, 255, 255, 255))
    stroke.putalpha(thick)
    canvas.alpha_composite(stroke)
    canvas.alpha_composite(layer, (pad, pad))
    return canvas


def place(img, st, center):
    img.alpha_composite(st, (int(center[0] - st.width / 2), int(center[1] - st.height / 2)))


def text(img, xy, s, size, fill=YELLOW, stroke=None, angle=0.0, max_w=None, anchor="mm", shadow=True):
    fnt = font(size)
    while max_w and fnt.getlength(s) > max_w and size > 20:
        size -= 4
        fnt = font(size)
    stroke = stroke or max(4, size // 9)
    pad = stroke * 4 + size // 3
    tw = int(fnt.getlength(s)) + pad * 2
    th = size + pad * 2
    layer = Image.new("RGBA", (tw, th), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    c = (tw / 2, th / 2)
    if shadow:
        sh = Image.new("RGBA", layer.size, (0, 0, 0, 0))
        ImageDraw.Draw(sh).text((c[0] + stroke, c[1] + stroke * 1.4), s, font=fnt, fill=(0, 0, 0, 220), anchor="mm",
                                stroke_width=stroke, stroke_fill=(0, 0, 0, 220))
        layer.alpha_composite(sh)
    d.text(c, s, font=fnt, fill=(*fill, 255), anchor="mm", stroke_width=stroke, stroke_fill=(*BLACK, 255))
    layer = layer.rotate(angle, resample=Image.BICUBIC, expand=True)
    x, y = xy
    if anchor == "lm":
        x += layer.width / 2 - pad
    img.alpha_composite(layer, (int(x - layer.width / 2), int(y - layer.height / 2)))


def arrow(img, start, end, width=46, color=RED):
    """Flecha gorda con contorno blanco."""
    sx, sy = start
    ex, ey = end
    ang = math.atan2(ey - sy, ex - sx)
    length = math.hypot(ex - sx, ey - sy)
    head = width * 2.2
    pts = [(0, -width / 2), (length - head, -width / 2), (length - head, -head / 1.4), (length, 0),
           (length - head, head / 1.4), (length - head, width / 2), (0, width / 2)]
    rot = [(sx + x * math.cos(ang) - y * math.sin(ang), sy + x * math.sin(ang) + y * math.cos(ang)) for x, y in pts]
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.polygon(rot, fill=(*color, 255), outline=WHITE, width=10)
    shadow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).polygon([(x + 8, y + 10) for x, y in rot], fill=(0, 0, 0, 160))
    img.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(6)))
    img.alpha_composite(layer)


def vignette(img, strength=0.5):
    w, h = img.size
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).ellipse((-w * 0.2, -h * 0.25, w * 1.2, h * 1.25), fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(min(w, h) * 0.1))
    dark = Image.new("RGBA", (w, h), (0, 0, 0, int(255 * strength)))
    return Image.composite(img, Image.alpha_composite(img, dark), mask)


def name_bar(img, y, size):
    text(img, (img.width / 2, y), NAME, size, fill=WHITE, stroke=max(6, size // 8))


def thumb1(L, tag):
    """¡CORRE!: el monstruo gigante a la derecha, el noob huyendo a la izquierda y una flecha."""
    img = burst((1920, 1080), (1350, 420), (255, 60, 30), (70, 0, 10), (255, 200, 60))
    place(img, sticker(L["monster"], 0.95, 8, (255, 40, 20), 30), (1380, 600))
    place(img, sticker(L["noob_a"], 0.95, 12), (470, 640))
    text(img, (560, 170), tag, 230, YELLOW, angle=6, max_w=1000)
    arrow(img, (880, 330), (1150, 420))
    name_bar(img, 990, 120)
    return vignette(img, 0.35)


def thumb2(L, tag):
    """¿Puedes escapar?: el monstruo en el centro y tres noobs huyendo."""
    img = burst((1920, 1080), (960, 380), (200, 40, 255), (25, 0, 60), (255, 80, 220))
    place(img, sticker(L["monster"], 0.85, 8, (255, 0, 120), 30), (960, 560))
    place(img, sticker(L["noob_b"], 0.62, 10), (300, 780))
    place(img, sticker(L["noob_c"], 0.62, 10), (1620, 780))
    place(img, sticker(L["noob_a"], 0.5, 10), (620, 880))
    text(img, (960, 140), tag, 170, YELLOW, angle=-3, max_w=1800)
    name_bar(img, 1000, 110)
    return vignette(img, 0.35)


def thumb3(L, tag):
    """¡No mires atrás!: cara del noob gritando enorme y el monstruo asomando detrás."""
    img = burst((1920, 1080), (1400, 380), (0, 230, 200), (0, 30, 40), (180, 255, 120))
    place(img, sticker(L["monster"], 0.8, 8, (255, 30, 30), 30), (1450, 520))
    place(img, sticker(L["face"], 0.95, 14), (560, 600))
    text(img, (1320, 930), tag, 150, YELLOW, angle=4, max_w=1100)
    arrow(img, (1150, 250), (1300, 330), 40)
    name_bar(img, 70, 100)
    return vignette(img, 0.35)


def icon(L):
    img = burst((1024, 1024), (680, 360), (255, 50, 30), (60, 0, 10), (255, 210, 60))
    place(img, sticker(L["monster"], 0.72, 8, (255, 40, 20), 26), (680, 470))
    place(img, sticker(L["face"], 0.62, 12), (300, 640))
    text(img, (512, 860), "SLENDERMAN", 150, YELLOW, angle=-4, max_w=960)
    text(img, (700, 960), ".EXE", 110, WHITE, angle=-4)
    return vignette(img, 0.3).convert("RGB").resize((512, 512), Image.LANCZOS)


def main():
    src = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else "assets/marketing/layers")
    out = os.path.abspath(sys.argv[2] if len(sys.argv) > 2 else "assets/marketing")
    L = {n[:-4]: Image.open(os.path.join(src, n)).convert("RGBA") for n in os.listdir(src) if n.endswith(".png")}
    os.makedirs(os.path.join(out, "es"), exist_ok=True)
    icon(L).save(os.path.join(out, "icon_512.png"), optimize=True)
    for i, make in ((1, thumb1), (2, thumb2), (3, thumb3)):
        en, es = TAGLINES[i]
        make(L, en).convert("RGB").save(os.path.join(out, f"thumbnail_{i}.png"), optimize=True)
        make(L, es).convert("RGB").save(os.path.join(out, "es", f"thumbnail_{i}.png"), optimize=True)
    print("listo en", out)


if __name__ == "__main__":
    main()
