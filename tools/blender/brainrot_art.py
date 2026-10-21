"""Renderiza por capas (fondo transparente) el monstruo en primer plano y noobs muertos de miedo
para las miniaturas llamativas. brainrot_text.py las monta sobre fondos de colores con el texto.

Uso (con `pip install bpy`, Python 3.13):
    python tools/blender/brainrot_art.py assets/marketing/layers [monster|noob_a|...] [--preview]
"""

import math
import os
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import key_art as ka  # noqa: E402

PREVIEW = "--preview" in sys.argv

NOOBS = {
    "a": {"skin": (0.95, 0.78, 0.05), "shirt": (0.02, 0.35, 0.95), "pants": (0.15, 0.7, 0.1)},     # noob clásico
    "b": {"skin": (0.95, 0.78, 0.05), "shirt": (0.95, 0.15, 0.55), "pants": (0.25, 0.05, 0.5)},
    "c": {"skin": (0.62, 0.42, 0.28), "shirt": (1.0, 0.45, 0.02), "pants": (0.03, 0.03, 0.04)},
}


def setup(res, samples=64):
    ka.setup(res, samples)
    scene = bpy.context.scene
    scene.render.film_transparent = True
    scene.cycles.samples = 16 if PREVIEW else samples
    scene.render.resolution_percentage = 40 if PREVIEW else 100
    scene.view_settings.look = "AgX - Punchy"


def spot(loc, target, color, power, size_deg=40):
    data = bpy.data.lights.new("s", "SPOT")
    data.energy = power
    data.color = color
    data.spot_size = math.radians(size_deg)
    data.spot_blend = 0.6
    obj = ka.link(bpy.data.objects.new("s", data))
    obj.location = loc
    obj.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    return obj


def scared_face(head, size):
    """Ojos como platos con pupilas diminutas, cejas de susto, boca abierta gritando y gota de sudor."""
    white = ka.flat("EyeWhite", (1, 1, 1), 0.3)
    black = ka.flat("Black", (0.005, 0.005, 0.005), 0.4)
    red = ka.flat("Tongue", (0.9, 0.08, 0.12), 0.5)
    sweat = ka.flat("Sweat", (0.35, 0.75, 1.0), 0.1)
    f = size / 2 + 0.01
    for sx in (-1, 1):
        ka.ball(white, 0.2 * size, (sx * 0.22 * size, f, 0.12 * size), (1.0, 0.25, 1.3), head)
        ka.ball(black, 0.05 * size, (sx * 0.2 * size, f + 0.05 * size, 0.1 * size), (1, 0.4, 1), head)
        ka.cube(black, (0.28 * size, 0.05 * size, 0.06 * size), (sx * 0.24 * size, f, 0.42 * size), 0.01, head,
                (0, math.radians(sx * 25), 0))
    ka.ball(black, 0.2 * size, (0, f, -0.25 * size), (1.1, 0.25, 0.9), head)
    ka.ball(red, 0.11 * size, (0, f + 0.02 * size, -0.33 * size), (1.2, 0.25, 0.6), head)
    ka.ball(sweat, 0.08 * size, (0.47 * size, f - 0.1 * size, 0.3 * size), (1, 1, 1.5), head)


def noob(loc, facing_deg, colors, run=1.0, arms_up=True):
    """Personaje de bloques tipo Roblox huyendo con cara de pánico."""
    root = ka.empty("Noob", loc)
    root.rotation_euler = (math.radians(8 * run), 0, math.radians(facing_deg))
    skin = ka.flat(f"Skin{colors['skin']}", colors["skin"], 0.5)
    shirt = ka.flat(f"Shirt{colors['shirt']}", colors["shirt"], 0.6)
    pants = ka.flat(f"Pants{colors['pants']}", colors["pants"], 0.7)
    for sx in (-1, 1):
        hip = ka.empty("Hip", (sx * 0.5, 0, 2.0), root)
        hip.rotation_euler = (math.radians(sx * 40 * run), 0, 0)
        ka.cube(pants, (0.95, 0.95, 2.0), (0, 0, -1.0), 0.06, hip)
    ka.cube(shirt, (2.0, 1.0, 2.0), (0, 0, 3.0), 0.08, root)
    for sx in (-1, 1):
        sh = ka.empty("Shoulder", (sx * 1.5, 0, 3.8), root)
        sh.rotation_euler = (math.radians(15 if sx < 0 else -20), math.radians(sx * (-150 if arms_up else -10)), 0)
        ka.cube(skin, (0.95, 0.95, 2.0), (0, 0, -0.9), 0.06, sh)
    head = ka.empty("Head", (0, 0, 4.6), root)
    head.rotation_euler = (math.radians(-8), 0, math.radians(6))
    ka.cube(skin, (1.2, 1.2, 1.2), (0, 0, 0), 0.22, head)
    scared_face(head, 1.2)
    return root


def monster_face(root, k=1.0):
    """Ojos rojos encendidos en la cara blanca del monstruo."""
    red = ka.glow("RedEye", (1.0, 0.05, 0.02), 40)
    z = 7.6 * k + 5.0 * k + 1.35 * k
    for sx in (-1, 1):
        pts = [(-0.17 * k, -0.04 * k), (0.2 * k, 0.1 * k), (0.17 * k, -0.08 * k), (-0.1 * k, -0.15 * k)]
        if sx < 0:
            pts = [(-x, zz) for x, zz in reversed(pts)]
        ka.prism(red, pts, 0.1, (sx * 0.24 * k, 0.6 * k, z), root)
        ka.point_light((sx * 0.24 * k, 1.4 * k, z), (1.0, 0.1, 0.05), 25, 0.1, root)
    black = ka.flat("Black", (0.005, 0.005, 0.005), 0.4)
    teeth = ka.flat("Teeth", (0.95, 0.93, 0.85), 0.35)
    # sonrisa enorme de oreja a oreja
    mz = z - 0.55 * k
    seg = 12
    pts = []
    for i in range(seg + 1):
        t = i / seg
        pts.append(((t - 0.5) * 0.9 * k, 0.12 * k * (2 * t - 1) ** 2))
    for i in range(seg, -1, -1):
        t = i / seg
        pts.append(((t - 0.5) * 0.9 * k, -0.16 * k * (1 - (2 * t - 1) ** 2) + 0.12 * k * (2 * t - 1) ** 2))
    ka.prism(black, pts[:-1], 0.1, (0, 0.55 * k, mz), root)
    for i in range(8):
        t = (i + 0.5) / 8
        x = (t - 0.5) * 0.9 * k
        top = 0.12 * k * (2 * t - 1) ** 2
        ka.prism(teeth, [(x - 0.045 * k, top + 0.01), (x + 0.045 * k, top + 0.01), (x, top - 0.07 * k)], 0.12,
                 (0, 0.57 * k, mz), root)


def shot_monster():
    """Busto del monstruo desde abajo, manos hacia la cámara y tentáculos abiertos."""
    ka.fresh()
    setup((1600, 1600))
    root = ka.monster((0, 0, 0), 0, 15.0)
    monster_face(root)
    for obj in root.children:
        if obj.name.startswith("MShoulder"):
            sx = 1 if obj.location.x > 0 else -1
            obj.rotation_euler = (math.radians(20), math.radians(sx * 30), 0)
    spot((-6, 9, 10), (0, 0, 13.5), (0.3, 0.9, 1.0), 9000, 35)        # relleno cian
    spot((5, 6, 16), (0, 0, 13), (1.0, 0.95, 0.9), 5000, 30)         # luz principal
    spot((0, -8, 16), (0, 0, 13), (1.0, 0.1, 0.05), 20000, 45)       # contra roja
    ka.camera((0.5, 5.0, 12.2), (0.0, 0.0, 13.0), 30)


def shot_noob(colors, name):
    def shot():
        ka.fresh()
        setup((1200, 1200))
        noob((0, 0, 0), 0, colors)
        spot((-5, 8, 8), (0, 0, 3), (1.0, 0.95, 0.85), 4000, 40)
        spot((6, 4, 6), (0, 0, 3), (0.3, 0.9, 1.0), 2500, 40)
        spot((0, -7, 8), (0, 0, 3.5), (1.0, 0.2, 0.1), 4000, 45)
        ka.camera((1.2, 11.0, 2.6), (0.0, 0.0, 3.2), 55)
    shot.__name__ = name
    return shot


def shot_face():
    """Primer plano de la cara del noob gritando, para el icono."""
    ka.fresh()
    setup((1200, 1200))
    noob((0, 0, 0), 0, NOOBS["a"], run=0.3, arms_up=True)
    spot((-4, 6, 7), (0, 0, 4.6), (1.0, 0.95, 0.85), 2500, 30)
    spot((4, 4, 5), (0, 0, 4.6), (0.3, 0.9, 1.0), 1500, 30)
    ka.camera((0.4, 4.2, 4.4), (0.0, 0.0, 4.4), 35)


SHOTS = {"monster": shot_monster, "face": shot_face}
SHOTS.update({f"noob_{k}": shot_noob(v, f"noob_{k}") for k, v in NOOBS.items()})


def main():
    args = [a for a in (sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]) if not a.startswith("--")]
    out = os.path.abspath(args[0] if args else "assets/marketing/layers")
    names = args[1:] or list(SHOTS)
    os.makedirs(out, exist_ok=True)
    for name in names:
        SHOTS[name]()
        bpy.context.scene.render.filepath = os.path.join(out, f"{name}.png")
        bpy.ops.render.render(write_still=True)
        print("render", name)


if __name__ == "__main__":
    main()
