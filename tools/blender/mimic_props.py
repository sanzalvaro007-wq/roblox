"""Genera los muebles de Mimic Manor en Blender y los exporta a .glb para Roblox Studio.

Uso (Blender 4.2+ o el módulo bpy de pip):
    blender -b -P tools/blender/mimic_props.py -- assets/models
    python tools/blender/mimic_props.py assets/models        (con `pip install bpy`)

Convenciones que espera el juego (ver PropModels en src/shared/PropCatalog.luau):
- 1 unidad de Blender = 1 stud. Origen en el centro del suelo del mueble.
- El frente mira a +Y en Blender, que al exportar a glTF queda en -Z (el frente en Roblox).
- Cada mueble es un Empty con el id del catálogo (Wardrobe, Chair...). Sus mallas se
  llaman "<Id>_<Acabado>" y el juego pone color y material de Roblox según el acabado
  (Wood, DarkWood, Brass, Cloth...), así que no hacen falta texturas.
"""

import math
import os
import sys

import bpy
import bmesh
from mathutils import Vector

# Colores aproximados para la vista previa; en Roblox manda la paleta de PropCatalog.
FINISHES = {
    "Wood": (0.36, 0.25, 0.18),
    "DarkWood": (0.23, 0.16, 0.12),
    "Brass": (0.69, 0.55, 0.34),
    "Cloth": (0.43, 0.13, 0.16),
    "Porcelain": (0.80, 0.82, 0.84),
    "Stone": (0.59, 0.59, 0.57),
    "Glass": (0.12, 0.12, 0.12),
    "Mirror": (0.67, 0.73, 0.76),
    "Shade": (0.77, 0.67, 0.47),
    "BookRed": (0.35, 0.12, 0.12),
    "BookGreen": (0.12, 0.24, 0.16),
    "BookBlue": (0.16, 0.16, 0.31),
    "Blood": (0.47, 0.0, 0.0),
    "Black": (0.06, 0.05, 0.05),
}

_materials = {}


def material(finish):
    if finish not in _materials:
        mat = bpy.data.materials.new(finish)
        mat.use_nodes = True
        bsdf = mat.node_tree.nodes.get("Principled BSDF")
        r, g, b = FINISHES[finish]
        bsdf.inputs["Base Color"].default_value = (r, g, b, 1)
        bsdf.inputs["Roughness"].default_value = 0.35 if finish in ("Brass", "Mirror", "Porcelain") else 0.7
        if finish in ("Brass", "Mirror"):
            bsdf.inputs["Metallic"].default_value = 1.0
        _materials[finish] = mat
    return _materials[finish]


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _materials.clear()


def _finish_object(obj, finish, bevel=0.0):
    obj.data.materials.append(material(finish))
    obj["finish"] = finish
    if bevel > 0:
        mod = obj.modifiers.new("Bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 2
        mod.limit_method = "ANGLE"
    return obj


def _object_from_bmesh(bm, name):
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def box(finish, size, loc, bevel=0.04):
    """Caja de tamaño (x, y, z) con el centro en loc."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector(size), verts=bm.verts)
    obj = _object_from_bmesh(bm, finish)
    obj.location = loc
    return _finish_object(obj, finish, bevel)


def lathe(finish, profile, loc=(0, 0, 0), segments=20):
    """Pieza torneada: profile es una lista de (radio, altura) de abajo arriba."""
    bm = bmesh.new()
    rings = []
    for radius, z in profile:
        ring = []
        for i in range(segments):
            a = 2 * math.pi * i / segments
            ring.append(bm.verts.new((loc[0] + radius * math.cos(a), loc[1] + radius * math.sin(a), loc[2] + z)))
        rings.append(ring)
    for lower, upper in zip(rings, rings[1:]):
        for i in range(segments):
            j = (i + 1) % segments
            bm.faces.new((lower[i], lower[j], upper[j], upper[i]))
    if profile[0][0] > 0:
        bm.faces.new(list(reversed(rings[0])))
    if profile[-1][0] > 0:
        bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    obj = _object_from_bmesh(bm, finish)
    for poly in obj.data.polygons:
        poly.use_smooth = True
    return _finish_object(obj, finish)


def cylinder(finish, radius, height, loc, segments=20, axis="Z"):
    """Cilindro con la base en loc (eje Z) o centrado en loc (ejes X/Y)."""
    if axis == "Z":
        return lathe(finish, [(radius, 0), (radius, height)], loc, segments)
    obj = lathe(finish, [(radius, -height / 2), (radius, height / 2)], (0, 0, 0), segments)
    obj.rotation_euler = (math.pi / 2, 0, 0) if axis == "Y" else (0, math.pi / 2, 0)
    obj.location = loc
    return obj


def sphere(finish, radius, loc, scale=(1, 1, 1)):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=20, v_segments=12, radius=radius)
    bmesh.ops.scale(bm, vec=Vector(scale), verts=bm.verts)
    bmesh.ops.translate(bm, vec=Vector(loc), verts=bm.verts)
    obj = _object_from_bmesh(bm, finish)
    for poly in obj.data.polygons:
        poly.use_smooth = True
    return _finish_object(obj, finish)


def turned_leg(finish, height, base_r, loc):
    """Pata torneada victoriana."""
    h = height
    r = base_r
    return lathe(finish, [
        (r * 0.7, 0), (r * 0.9, h * 0.04), (r * 0.6, h * 0.1), (r * 0.55, h * 0.35),
        (r * 1.0, h * 0.45), (r * 0.6, h * 0.55), (r * 0.7, h * 0.85), (r * 1.0, h * 0.9), (r * 1.0, h),
    ], loc, 14)


# ---------------------------------------------------------------- muebles
# Frente hacia +Y. Medidas iguales a los placeholders de PropCatalog para no cambiar el equilibrio.

def wardrobe():
    box("DarkWood", (5, 2.4, 0.5), (0, 0, 0.25))                     # zócalo
    box("DarkWood", (4.8, 2.3, 7.8), (0, 0, 4.4))                    # cuerpo
    box("DarkWood", (5.3, 2.7, 0.35), (0, 0, 8.45))                  # cornisa
    box("Wood", (4.4, 2.0, 0.25), (0, 0, 8.75))                      # remate
    box("DarkWood", (1.2, 0.3, 0.5), (0, 0.2, 9.1))                  # copete
    for side in (-1, 1):
        x = side * 1.17
        box("Wood", (2.25, 0.15, 7.4), (x, 1.2, 4.4))                # puerta
        box("DarkWood", (1.7, 0.08, 2.6), (x, 1.3, 6.2), 0.03)       # panel alto
        box("DarkWood", (1.7, 0.08, 3.4), (x, 1.3, 2.7), 0.03)       # panel bajo
        sphere("Brass", 0.13, (side * 0.25, 1.38, 4.6))              # pomo
        for z in (1.4, 7.3):
            box("Brass", (0.08, 0.1, 0.4), (side * 2.25, 1.25, z), 0.01)  # bisagras


def chair():
    for sx in (-1, 1):
        turned_leg("DarkWood", 1.8, 0.16, (sx * 0.95, -0.95, 0))      # patas traseras (y=-)
        turned_leg("DarkWood", 1.8, 0.16, (sx * 0.95, 0.95, 0))
    box("Wood", (2.4, 2.4, 0.3), (0, 0, 1.95))                       # asiento
    box("Cloth", (2.15, 2.15, 0.28), (0, 0.05, 2.22), 0.1)           # cojín
    for sx in (-1, 1):
        box("DarkWood", (0.22, 0.22, 3.2), (sx * 1.0, -1.05, 3.6))   # montantes
    box("DarkWood", (2.4, 0.25, 0.35), (0, -1.05, 5.2), 0.08)        # travesaño alto
    box("Cloth", (1.7, 0.18, 2.3), (0, -1.0, 3.75), 0.08)            # respaldo tapizado
    box("DarkWood", (1.0, 0.2, 0.25), (0, -1.05, 5.5), 0.06)         # copete


def table():
    box("Wood", (6, 3.5, 0.3), (0, 0, 3.05), 0.08)                   # tablero
    box("DarkWood", (5.6, 3.1, 0.4), (0, 0, 2.7))                    # faldón
    for sx in (-1, 1):
        for sy in (-1, 1):
            turned_leg("DarkWood", 2.5, 0.22, (sx * 2.55, sy * 1.35, 0))
    box("Cloth", (1.6, 3.6, 0.04), (0, 0, 3.22), 0.0)                # camino de mesa


def grandfather_clock():
    box("DarkWood", (2.2, 1.6, 0.5), (0, 0, 0.25))                   # base
    box("DarkWood", (1.8, 1.35, 4.6), (0, 0, 2.8))                   # tronco
    box("DarkWood", (2.2, 1.6, 2.2), (0, 0, 6.2))                    # capitel
    box("Wood", (2.4, 1.75, 0.3), (0, 0, 7.45))                      # cornisa
    box("DarkWood", (1.2, 0.4, 0.5), (0, 0.55, 7.85))                # copete
    cylinder("Porcelain", 0.72, 0.08, (0, 0.82, 6.25), 28, "Y")      # esfera
    cylinder("Brass", 0.8, 0.06, (0, 0.8, 6.25), 28, "Y")            # aro
    box("Black", (0.06, 0.03, 0.5), (0, 0.88, 6.45), 0.0)            # aguja larga
    box("Black", (0.35, 0.03, 0.06), (0.15, 0.88, 6.25), 0.0)        # aguja corta
    box("Glass", (1.2, 0.05, 3.0), (0, 0.69, 3.1), 0.0)              # vitrina
    box("Brass", (0.05, 0.05, 2.0), (0, 0.6, 3.6), 0.0)              # varilla péndulo
    cylinder("Brass", 0.28, 0.06, (0, 0.62, 2.5), 20, "Y")           # péndulo


def dresser():
    box("DarkWood", (4.5, 2.0, 0.35), (0, 0, 0.175))                 # zócalo
    box("Wood", (4.3, 1.9, 3.0), (0, 0, 1.85))                       # cuerpo
    box("DarkWood", (4.6, 2.1, 0.2), (0, 0, 3.45), 0.06)             # tapa
    for i, z in enumerate((0.85, 1.85, 2.85)):
        box("DarkWood", (3.9, 0.1, 0.8), (0, 0.98, z), 0.03)         # cajón
        for sx in (-1, 1):
            box("Brass", (0.4, 0.08, 0.1), (sx * 1.0, 1.06, z), 0.02)  # tirador
    for sx in (-1, 1):
        turned_leg("DarkWood", 0.35, 0.15, (sx * 2.0, 0.8, 0))


def chest():
    box("Wood", (3.4, 1.9, 1.7), (0, 0, 0.95))                       # cuerpo
    bm = bmesh.new()                                                  # tapa abombada
    seg = 10
    verts = []
    for side in (-1.75, 1.75):
        ring = []
        for i in range(seg + 1):
            a = math.pi * i / seg
            ring.append(bm.verts.new((side, 1.0 * math.cos(a), 1.8 + 0.55 * math.sin(a))))
        verts.append(ring)
    for i in range(seg):
        bm.faces.new((verts[0][i], verts[0][i + 1], verts[1][i + 1], verts[1][i]))
    bm.faces.new(verts[0])
    bm.faces.new(list(reversed(verts[1])))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    _finish_object(_object_from_bmesh(bm, "DarkWood"), "DarkWood")
    for x in (-1.2, 1.2):                                            # flejes
        box("Brass", (0.15, 2.0, 1.75), (x, 0, 0.95), 0.02)
    box("Brass", (0.4, 0.12, 0.5), (0, 1.0, 1.6), 0.02)              # cerradura


def floor_lamp():
    lathe("Brass", [(0.8, 0), (0.8, 0.08), (0.5, 0.2), (0.15, 0.35), (0.12, 0.4)], segments=24)
    lathe("Brass", [(0.08, 0.4), (0.08, 4.6), (0.14, 4.7), (0.06, 4.9)], segments=12)
    lathe("Shade", [(0.45, 4.7), (1.0, 4.75), (0.55, 6.4), (0.5, 6.45)], segments=24)
    for i in range(12):                                              # flecos
        a = 2 * math.pi * i / 12
        box("Brass", (0.05, 0.05, 0.3), (0.98 * math.cos(a), 0.98 * math.sin(a), 4.6), 0.0)


def bust():
    lathe("Stone", [(0.9, 0), (0.9, 0.3), (0.65, 0.45), (0.55, 0.6), (0.5, 2.8), (0.7, 2.95), (0.85, 3.05), (0.85, 3.2)], segments=24)
    sphere("Stone", 0.75, (0, 0, 3.55), (1.0, 0.6, 0.55))           # hombros
    lathe("Stone", [(0.22, 3.6), (0.2, 4.05)], segments=12)          # cuello
    sphere("Stone", 0.42, (0, 0.02, 4.45), (0.85, 0.95, 1.1))         # cabeza
    sphere("Stone", 0.09, (0, 0.42, 4.4))                            # nariz


def vase():
    lathe("Porcelain", [(0.35, 0), (0.45, 0.1), (0.75, 0.6), (0.8, 1.0), (0.6, 1.6), (0.3, 2.0), (0.28, 2.4), (0.42, 2.7), (0.38, 2.8)], segments=28)
    lathe("BookBlue", [(0.79, 0.85), (0.81, 1.05)], segments=28)     # franja azul


def bookshelf():
    box("DarkWood", (5, 1.4, 0.3), (0, -0.1, 0.15))                  # base
    for sx in (-1, 1):
        box("DarkWood", (0.25, 1.4, 8), (sx * 2.38, -0.1, 4))         # laterales
    box("DarkWood", (5, 0.15, 8), (0, -0.72, 4), 0.0)                # fondo
    box("DarkWood", (5.3, 1.6, 0.3), (0, -0.05, 7.95))               # cornisa
    colors = ["BookRed", "BookGreen", "BookBlue"]
    for row, z in enumerate((0.3, 2.3, 4.3, 6.3)):
        box("DarkWood", (4.5, 1.3, 0.12), (0, -0.1, z))              # balda
        if row == 3:
            continue
        x = -2.1
        k = row
        while x < 2.0:
            w = 0.22 + 0.12 * ((k * 7) % 3)
            h = 1.2 + 0.25 * ((k * 5) % 3)
            box(colors[k % 3], (w, 0.9, h), (x + w / 2, 0.05, z + 0.06 + h / 2), 0.015)
            x += w + 0.03
            k += 1


def cuckoo_clock():
    lathe("DarkWood", [(0.3, 0), (0.3, 4.4)], segments=12)            # poste
    box("Wood", (2.2, 1.3, 2.2), (0, 0, 5.6))                        # casa
    for side in (-1, 1):                                             # tejado a dos aguas
        roof = box("DarkWood", (1.65, 1.6, 0.18), (side * 0.6, 0, 7.05), 0.02)
        roof.rotation_euler = (0, side * math.radians(35), 0)
    cylinder("Porcelain", 0.55, 0.06, (0, 0.67, 5.4), 24, "Y")
    box("Black", (0.05, 0.03, 0.4), (0, 0.71, 5.55), 0.0)
    box("Black", (0.3, 0.6, 0.45), (0, 0.4, 6.4), 0.02)               # puertecita
    sphere("Brass", 0.12, (0, 0.72, 6.4))                             # cuco
    for sx in (-0.4, 0.4):                                           # piñas
        box("Brass", (0.03, 0.03, 1.0), (sx, 0.5, 4.0), 0.0)
        lathe("Brass", [(0.05, 0), (0.14, 0.15), (0.12, 0.45), (0.02, 0.6)], (sx, 0.5, 2.9), 10)


def cursed_mirror():
    box("DarkWood", (2.2, 0.9, 0.3), (0, 0, 0.15))                   # pie
    lathe("Brass", [(0.12, 0.3), (0.12, 0.6)], segments=12)
    bm = bmesh.new()                                                 # marco ovalado
    seg = 32
    outer, inner = [], []
    for i in range(seg):
        a = 2 * math.pi * i / seg
        outer.append((1.5 * math.cos(a), 3.2 * math.sin(a)))
        inner.append((1.22 * math.cos(a), 2.9 * math.sin(a)))
    front, back = [], []
    for y in (0.25, -0.25):
        ring_o = [bm.verts.new((x, y, 3.75 + z)) for x, z in outer]
        ring_i = [bm.verts.new((x, y, 3.75 + z)) for x, z in inner]
        (front if y > 0 else back).append((ring_o, ring_i))
    (fo, fi), (bo, bi) = front[0], back[0]
    for i in range(seg):
        j = (i + 1) % seg
        bm.faces.new((fo[i], fo[j], fi[j], fi[i]))
        bm.faces.new((bo[j], bo[i], bi[i], bi[j]))
        bm.faces.new((fo[j], fo[i], bo[i], bo[j]))
        bm.faces.new((fi[i], fi[j], bi[j], bi[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    _finish_object(_object_from_bmesh(bm, "Brass"), "Brass")
    sphere("Mirror", 1.0, (0, 0.0, 3.75), (1.24, 0.06, 2.92))
    sphere("Brass", 0.25, (0, 0.1, 7.1))                              # remate


def bloody_statue():
    box("Stone", (2.2, 2.2, 1.0), (0, 0, 0.5), 0.06)                 # peana
    lathe("Stone", [(0.85, 1.0), (0.8, 1.6), (0.65, 3.0), (0.55, 4.2), (0.5, 4.8), (0.3, 5.0)], segments=24)  # túnica
    for sx in (-1, 1):                                               # manos juntas
        sphere("Stone", 0.22, (sx * 0.12, 0.55, 3.9), (1.0, 1.2, 1.4))
    lathe("Stone", [(0.18, 4.95), (0.18, 5.25)], segments=12)        # cuello
    sphere("Stone", 0.48, (0, 0, 5.65), (0.9, 0.95, 1.1))             # cabeza
    lathe("Stone", [(0.6, 5.2), (0.58, 5.9), (0.3, 6.35), (0.0, 6.45)], (0, -0.08, 0), 20)  # velo
    for sx in (-0.16, 0.16):                                         # lágrimas de sangre
        box("Blood", (0.07, 0.04, 0.55), (sx, 0.42, 5.4), 0.01)


PROPS = {
    "Wardrobe": wardrobe,
    "Chair": chair,
    "Table": table,
    "GrandfatherClock": grandfather_clock,
    "Dresser": dresser,
    "Chest": chest,
    "FloorLamp": floor_lamp,
    "Bust": bust,
    "Vase": vase,
    "Bookshelf": bookshelf,
    "CuckooClock": cuckoo_clock,
    "CursedMirror": cursed_mirror,
    "BloodyStatue": bloody_statue,
}


def build_prop(prop_id, offset=(0, 0, 0)):
    """Construye un mueble, aplica modificadores y une las mallas por acabado."""
    before = set(bpy.data.objects)
    PROPS[prop_id]()
    created = [o for o in bpy.data.objects if o not in before]
    depsgraph = bpy.context.evaluated_depsgraph_get()
    by_finish = {}
    for obj in created:
        by_finish.setdefault(obj["finish"], []).append(obj)

    root = bpy.data.objects.new(prop_id, None)
    bpy.context.scene.collection.objects.link(root)
    for finish, objs in by_finish.items():
        bm = bmesh.new()
        for obj in objs:
            evaluated = obj.evaluated_get(depsgraph)
            mesh = evaluated.to_mesh()
            mesh.transform(obj.matrix_world)
            bm.from_mesh(mesh)
            evaluated.to_mesh_clear()
        joined = _object_from_bmesh(bm, f"{prop_id}_{finish}")
        joined.data.materials.append(material(finish))
        for poly in joined.data.polygons:
            poly.use_smooth = False
        joined.parent = root
    for obj in created:
        bpy.data.objects.remove(obj)
    root.location = offset
    return root


def export(path, roots):
    bpy.ops.object.select_all(action="DESELECT")
    for root in roots:
        root.select_set(True)
        for child in root.children:
            child.select_set(True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_yup=True, export_apply=True)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    out = os.path.abspath(argv[0] if argv else "assets/models")
    os.makedirs(out, exist_ok=True)

    # Un archivo por mueble...
    for prop_id in PROPS:
        reset()
        root = build_prop(prop_id)
        export(os.path.join(out, f"{prop_id}.glb"), [root])

    # ...y todos juntos en fila, para importarlos de una vez en Studio.
    reset()
    roots = []
    x = 0.0
    for prop_id in PROPS:
        roots.append(build_prop(prop_id, (x, 0, 0)))
        x += 8
    export(os.path.join(out, "MimicProps.glb"), roots)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out, "MimicProps.blend"))
    print(f"Exportados {len(PROPS)} muebles en {out}")


if __name__ == "__main__":
    main()
