"""Pone el título y los lemas sobre los renders de key_art.py y saca los PNG para Roblox.

Uso (necesita Pillow):
    python tools/blender/key_art_text.py assets/marketing/renders assets/marketing

Fuentes (Google Fonts, licencia OFL): Cinzel Decorative para el título y Creepster para
los lemas. Se descargan solas a tools/blender/.fonts la primera vez.
"""

import os
import sys
import urllib.request

from PIL import Image, ImageDraw, ImageFilter, ImageFont

FONTS = {
    "title": "ofl/cinzeldecorative/CinzelDecorative-Black.ttf",
    "tag": "ofl/creepster/Creepster-Regular.ttf",
}
FONT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), ".fonts")

BONE = (238, 226, 198)
EYE = (255, 200, 40)
INK = (12, 8, 6)

TITLE = "ESCAPE THE MONSTER"

# id del render -> lemas (inglés / español)
TAGLINES = {
    "thumb1": ("WHICH ONE IS ALIVE?", "¿CUÁL ESTÁ VIVO?"),
    "thumb2": ("HIDE AS FURNITURE", "DISFRÁZATE DE MUEBLE"),
    "thumb3": ("FIND IT. ESCAPE.", "ENCUÉNTRALO. ESCAPA."),
}


def font(kind, size):
    path = os.path.join(FONT_DIR, os.path.basename(FONTS[kind]))
    if not os.path.exists(path):
        os.makedirs(FONT_DIR, exist_ok=True)
        urllib.request.urlretrieve("https://raw.githubusercontent.com/google/fonts/main/" + FONTS[kind], path)
    return ImageFont.truetype(path, size)


def glow_text(img, xy, text, fnt, fill, glow, glow_radius, stroke, anchor="mm"):
    """Texto con resplandor de color, contorno oscuro y sombra."""
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.text(xy, text, font=fnt, fill=(*glow, 255), anchor=anchor, stroke_width=stroke * 2, stroke_fill=(*glow, 255))
    halo = layer.filter(ImageFilter.GaussianBlur(glow_radius))
    img.alpha_composite(halo)
    img.alpha_composite(halo)
    shadow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).text((xy[0] + stroke, xy[1] + stroke * 1.5), text, font=fnt, fill=(0, 0, 0, 200), anchor=anchor,
                                stroke_width=stroke, stroke_fill=(0, 0, 0, 200))
    img.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(stroke)))
    ImageDraw.Draw(img).text(xy, text, font=fnt, fill=(*fill, 255), anchor=anchor, stroke_width=stroke, stroke_fill=(*INK, 255))


def vignette(img, strength=0.55):
    w, h = img.size
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).ellipse((-w * 0.15, -h * 0.2, w * 1.15, h * 1.2), fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(min(w, h) * 0.12))
    dark = Image.new("RGBA", (w, h), (0, 0, 0, int(255 * strength)))
    out = Image.composite(img, Image.alpha_composite(img, dark), mask)
    return out


def fit(kind, size, text, max_w):
    """Fuente del tamaño pedido, o más pequeña si el texto no cabe en max_w."""
    fnt = font(kind, size)
    while size > 10 and fnt.getlength(text) > max_w:
        size -= 2
        fnt = font(kind, size)
    return fnt


def make_icon(src, dst):
    img = vignette(Image.open(src).convert("RGBA"), 0.5)
    w, h = img.size
    glow_text(img, (w / 2, h * 0.115), "ESCAPE", fit("title", int(h * 0.16), "ESCAPE", w * 0.9), BONE, (200, 120, 20), h * 0.02, int(h * 0.008))
    glow_text(img, (w / 2, h * 0.255), "THE MONSTER", fit("title", int(h * 0.115), "THE MONSTER", w * 0.92), BONE, (200, 120, 20), h * 0.02, int(h * 0.007))
    img.convert("RGB").resize((512, 512), Image.LANCZOS).save(dst, optimize=True)


def make_thumb(src, dst, tagline):
    img = vignette(Image.open(src).convert("RGBA"), 0.45)
    w, h = img.size
    # banda oscura arriba para que se lea el texto
    band = Image.new("L", (1, h))
    for y in range(h):
        band.putpixel((0, y), int(170 * max(0.0, 1 - y / (h * 0.42)) ** 1.6))
    img.alpha_composite(Image.merge("RGBA", [Image.new("L", (w, h), 0)] * 3 + [band.resize((w, h))]))
    glow_text(img, (w / 2, h * 0.12), TITLE, fit("title", int(h * 0.12), TITLE, w * 0.9), BONE, (200, 120, 20), h * 0.015, int(h * 0.006))
    glow_text(img, (w / 2, h * 0.255), tagline, font("tag", int(h * 0.09)), EYE, (255, 120, 0), h * 0.012, int(h * 0.005))
    img.convert("RGB").save(dst, optimize=True)


def main():
    src = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else "assets/marketing/renders")
    out = os.path.abspath(sys.argv[2] if len(sys.argv) > 2 else "assets/marketing")
    os.makedirs(os.path.join(out, "es"), exist_ok=True)
    make_icon(os.path.join(src, "icon.png"), os.path.join(out, "icon_512.png"))
    for i, (name, (en, es)) in enumerate(TAGLINES.items(), 1):
        make_thumb(os.path.join(src, f"{name}.png"), os.path.join(out, f"thumbnail_{i}.png"), en)
        make_thumb(os.path.join(src, f"{name}.png"), os.path.join(out, "es", f"thumbnail_{i}.png"), es)
    print("listo en", out)


if __name__ == "__main__":
    main()
