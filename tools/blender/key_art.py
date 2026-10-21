"""Renderiza el icono y las miniaturas de Escape the Monster con los muebles de mimic_props.py.

Uso (con `pip install bpy`, Python 3.13):
    python tools/blender/key_art.py assets/marketing/renders [icon|thumb1|thumb2|thumb3] [--preview]

Saca PNG sin texto; tools/blender/key_art_text.py les pone el título encima.
"""

import math
import os
import sys

import bpy
import bmesh
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mimic_props as mp  # noqa: E402

PREVIEW = "--preview" in sys.argv

# ---------------------------------------------------------------- materiales

_extra = {}


def flat(name, color, rough=0.7, metal=0.0):
    if name not in _extra:
        mat = bpy.data.materials.new(name)
        mat.use_nodes = True
        bsdf = mat.node_tree.nodes["Principled BSDF"]
        bsdf.inputs["Base Color"].default_value = (*color, 1)
        bsdf.inputs["Roughness"].default_value = rough
        bsdf.inputs["Metallic"].default_value = metal
        _extra[name] = mat
    return _extra[name]


def glow(name, color, strength):
    if name not in _extra:
        mat = bpy.data.materials.new(name)
        mat.use_nodes = True
        nodes = mat.node_tree.nodes
        nodes.remove(nodes["Principled BSDF"])
        em = nodes.new("ShaderNodeEmission")
        em.inputs["Color"].default_value = (*color, 1)
        em.inputs["Strength"].default_value = strength
        mat.node_tree.links.new(em.outputs[0], nodes["Material Output"].inputs["Surface"])
        _extra[name] = mat
    return _extra[name]


def wallpaper():
    """Papel pintado a rayas verde botella."""
    if "Wallpaper" in _extra:
        return _extra["Wallpaper"]
    mat = bpy.data.materials.new("Wallpaper")
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = 0.85
    coord = nt.nodes.new("ShaderNodeTexCoord")
    wave = nt.nodes.new("ShaderNodeTexWave")
    wave.wave_type = "BANDS"
    wave.bands_direction = "X"
    wave.wave_profile = "SAW"
    wave.inputs["Scale"].default_value = 0.6
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.interpolation = "CONSTANT"
    ramp.color_ramp.elements[0].color = (0.035, 0.07, 0.055, 1)
    ramp.color_ramp.elements[1].position = 0.55
    ramp.color_ramp.elements[1].color = (0.05, 0.10, 0.075, 1)
    nt.links.new(coord.outputs["Object"], wave.inputs["Vector"])
    nt.links.new(wave.outputs["Fac"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], bsdf.inputs["Base Color"])
    _extra["Wallpaper"] = mat
    return mat


def beam_material():
    """Haz de linterna falso: brilla en el centro y se apaga con la distancia."""
    if "Beam" in _extra:
        return _extra["Beam"]
    mat = bpy.data.materials.new("Beam")
    mat.use_nodes = True
    nt = mat.node_tree
    nodes, links = nt.nodes, nt.links
    nodes.remove(nodes["Principled BSDF"])
    out = nodes["Material Output"]
    coord = nodes.new("ShaderNodeTexCoord")
    sep = nodes.new("ShaderNodeSeparateXYZ")
    fade = nodes.new("ShaderNodeMapRange")          # z local: 0 en la linterna, -1 al final
    fade.inputs["From Min"].default_value = 0.0
    fade.inputs["From Max"].default_value = -1.0
    fade.inputs["To Min"].default_value = 1.0
    fade.inputs["To Max"].default_value = 0.0
    weight = nodes.new("ShaderNodeLayerWeight")
    weight.inputs["Blend"].default_value = 0.35
    soft = nodes.new("ShaderNodeMath")
    soft.operation = "SUBTRACT"
    soft.inputs[0].default_value = 1.0
    mul = nodes.new("ShaderNodeMath")
    mul.operation = "MULTIPLY"
    mul2 = nodes.new("ShaderNodeMath")
    mul2.operation = "MULTIPLY"
    mul2.inputs[1].default_value = 0.22
    em = nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = (1.0, 0.86, 0.6, 1)
    em.inputs["Strength"].default_value = 1.0
    tr = nodes.new("ShaderNodeBsdfTransparent")
    mix = nodes.new("ShaderNodeMixShader")
    links.new(coord.outputs["Object"], sep.inputs[0])
    links.new(sep.outputs["Z"], fade.inputs["Value"])
    links.new(weight.outputs["Facing"], soft.inputs[1])
    links.new(fade.outputs["Result"], mul.inputs[0])
    links.new(soft.outputs[0], mul.inputs[1])
    links.new(mul.outputs[0], mul2.inputs[0])
    links.new(mul2.outputs[0], mix.inputs["Fac"])
    links.new(tr.outputs[0], mix.inputs[1])
    links.new(em.outputs[0], mix.inputs[2])
    links.new(mix.outputs[0], out.inputs["Surface"])
    _extra["Beam"] = mat
    return mat


# ---------------------------------------------------------------- piezas

def link(obj):
    bpy.context.scene.collection.objects.link(obj)
    return obj


def cube(mat, size, loc, bevel=0.03, parent=None, rot=(0, 0, 0)):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector(size), verts=bm.verts)
    mesh = bpy.data.meshes.new("c")
    bm.to_mesh(mesh)
    bm.free()
    obj = link(bpy.data.objects.new("c", mesh))
    obj.data.materials.append(mat)
    obj.location = loc
    obj.rotation_euler = rot
    if bevel > 0:
        mod = obj.modifiers.new("Bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 2
    obj.parent = parent
    return obj


def ball(mat, radius, loc, scale=(1, 1, 1), parent=None):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=24, v_segments=14, radius=radius)
    bmesh.ops.scale(bm, vec=Vector(scale), verts=bm.verts)
    mesh = bpy.data.meshes.new("s")
    bm.to_mesh(mesh)
    bm.free()
    for p in mesh.polygons:
        p.use_smooth = True
    obj = link(bpy.data.objects.new("s", mesh))
    obj.data.materials.append(mat)
    obj.location = loc
    obj.parent = parent
    return obj


def prism(mat, pts, depth, loc, parent=None):
    """Prisma de perfil pts (x, z) y grosor depth en Y: dientes, ojos almendrados..."""
    bm = bmesh.new()
    front = [bm.verts.new((x, depth / 2, z)) for x, z in pts]
    back = [bm.verts.new((x, -depth / 2, z)) for x, z in pts]
    bm.faces.new(front)
    bm.faces.new(list(reversed(back)))
    n = len(pts)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((front[j], front[i], back[i], back[j]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new("p")
    bm.to_mesh(mesh)
    bm.free()
    obj = link(bpy.data.objects.new("p", mesh))
    obj.data.materials.append(mat)
    obj.location = loc
    obj.parent = parent
    return obj


def point_light(loc, color, power, radius=0.3, parent=None):
    data = bpy.data.lights.new("p", "POINT")
    data.color = color
    data.energy = power
    data.shadow_soft_size = radius
    obj = link(bpy.data.objects.new("p", data))
    obj.location = loc
    obj.parent = parent
    return obj


def area_light(loc, rot, color, power, size):
    data = bpy.data.lights.new("a", "AREA")
    data.color = color
    data.energy = power
    data.shape = "RECTANGLE"
    data.size, data.size_y = size
    obj = link(bpy.data.objects.new("a", data))
    obj.location = loc
    obj.rotation_euler = rot
    return obj


def empty(name, loc=(0, 0, 0), parent=None):
    obj = link(bpy.data.objects.new(name, None))
    obj.location = loc
    obj.parent = parent
    return obj


# ---------------------------------------------------------------- escenario

def room(width=44, back=-14, front=30, height=16, window_x=None):
    """Salón con suelo de tablones, papel pintado, friso de madera y ventana con luna."""
    wood_a = flat("PlankA", (0.20, 0.12, 0.075), 0.55)
    wood_b = flat("PlankB", (0.15, 0.09, 0.055), 0.55)
    dark = flat("Trim", (0.085, 0.05, 0.035), 0.5)
    depth = front - back
    x = -width / 2
    i = 0
    while x < width / 2:
        cube(wood_a if i % 2 else wood_b, (1.48, depth, 0.2), (x + 0.75, (back + front) / 2, -0.1), 0.02)
        x += 1.5
        i += 1
    # pared del fondo
    cube(wallpaper(), (width, 0.5, height), (0, back - 0.25, height / 2), 0)
    cube(dark, (width, 0.4, 3.2), (0, back + 0.1, 1.6), 0.02)                    # friso
    cube(dark, (width, 0.6, 0.3), (0, back + 0.2, 3.3), 0.05)                    # moldura
    cube(dark, (width, 0.7, 0.6), (0, back + 0.1, height - 0.3), 0.05)           # cornisa
    # paredes laterales
    for sx in (-1, 1):
        cube(wallpaper(), (0.5, depth, height), (sx * (width / 2 + 0.25), (back + front) / 2, height / 2), 0)
        cube(dark, (0.4, depth, 3.2), (sx * (width / 2 - 0.1), (back + front) / 2, 1.6), 0.02)
    # techo
    cube(flat("Ceiling", (0.05, 0.04, 0.04)), (width, depth, 0.4), (0, (back + front) / 2, height + 0.2), 0)
    if window_x is not None:
        window(window_x, back)


def window(x, back):
    """Ventana alta con parteluces y luz de luna azul entrando."""
    dark = flat("Trim", (0.085, 0.05, 0.035), 0.5)
    w, h, z0 = 5.0, 8.5, 4.6
    sky = glow("Moon", (0.35, 0.5, 0.9), 2.2)
    cube(sky, (w, 0.1, h), (x, back + 0.02, z0 + h / 2), 0)
    cube(dark, (w + 0.8, 0.6, 0.5), (x, back + 0.1, z0 - 0.25), 0.04)
    cube(dark, (w + 0.8, 0.6, 0.5), (x, back + 0.1, z0 + h + 0.25), 0.04)
    for sx in (-1, 0, 1):
        cube(dark, (0.3 if sx == 0 else 0.45, 0.5, h), (x + sx * w / 2, back + 0.1, z0 + h / 2), 0.02)
    for k in (1, 2, 3):
        cube(dark, (w, 0.4, 0.15), (x, back + 0.1, z0 + k * h / 4), 0.01)
    curtain = flat("Curtain", (0.22, 0.03, 0.05), 0.9)
    for sx in (-1, 1):
        cube(curtain, (1.4, 0.5, h + 1.5), (x + sx * (w / 2 + 0.9), back + 0.5, z0 + h / 2 + 0.5), 0.3)
    moon = area_light((x, back + 0.6, z0 + h / 2), (math.radians(90), 0, 0), (0.45, 0.6, 1.0), 900, (w, h))
    moon.visible_camera = False


def painting(x, z, back, w=3.2, h=4.0):
    frame = flat("Frame", (0.55, 0.42, 0.22), 0.35, 1.0)
    cube(frame, (w, 0.25, h), (x, back + 0.15, z), 0.05)
    cube(flat("Canvas", (0.05, 0.035, 0.03), 0.9), (w - 0.5, 0.3, h - 0.5), (x, back + 0.15, z), 0)


def fog(density=0.006, size=(60, 60, 20)):
    """Neblina muy fina para que se vean los haces de luz."""
    mat = bpy.data.materials.new("Fog")
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.remove(nt.nodes["Principled BSDF"])
    vol = nt.nodes.new("ShaderNodeVolumePrincipled")
    vol.inputs["Density"].default_value = density
    vol.inputs["Color"].default_value = (0.75, 0.8, 0.9, 1)
    nt.links.new(vol.outputs[0], nt.nodes["Material Output"].inputs["Volume"])
    cube(mat, size, (0, 0, size[2] / 2 - 0.5), 0)


def lamp_bulb(x, y):
    point_light((x, y, 5.6), (1.0, 0.62, 0.3), 700, 0.5)


def prop(prop_id, loc, rot_deg=0.0):
    root = mp.build_prop(prop_id, loc)
    root.rotation_euler = (0, 0, math.radians(rot_deg))
    return root


# ---------------------------------------------------------------- la Anomalía

EYE = (1.0, 0.78, 0.15)


def mimic_face(root, center, eye_gap, eye_size, mouth_w, mouth_z, y, grin=True, glow_power=60, eyes=True):
    """Ojos amarillos brillantes y sonrisa dentada pegados al frente de un mueble.
    center = (x, z) del entrecejo en coordenadas del mueble; y = superficie del frente."""
    eye_mat = glow("Eye", EYE, 18)
    pupil = flat("Pupil", (0.01, 0.005, 0.0), 0.3)
    cx, cz = center
    for sx in ((-1, 1) if eyes else ()):
        # ojo enfadado: el borde de arriba baja hacia la nariz
        w, h = eye_size
        pts = [(-w / 2, -0.05 * h), (w / 2, 0.55 * h), (0.38 * w, -0.15 * h), (0.05 * w, -0.45 * h), (-0.3 * w, -0.32 * h)]
        if sx < 0:
            pts = [(-x, z) for x, z in reversed(pts)]
        eye = prism(eye_mat, pts, 0.12, (cx + sx * eye_gap / 2, y + 0.04, cz), root)
        eye.visible_diffuse = False                                   # que ilumine solo la luz puntual
        cube(pupil, (w * 0.11, 0.14, h * 0.62), (cx + sx * (eye_gap / 2 - 0.04 * w), y + 0.07, cz - 0.02 * h), 0, root)
        point_light((cx + sx * eye_gap / 2, y + 0.9, cz), EYE, glow_power / 2, 0.2, root)
    if not grin:
        return
    mouth = flat("Mouth", (0.012, 0.0, 0.004), 0.6)
    teeth = flat("Teeth", (0.9, 0.86, 0.72), 0.35)
    # boca: media luna ancha
    seg = 14
    top, bot = [], []
    for i in range(seg + 1):
        t = i / seg
        x = (t - 0.5) * mouth_w
        curve = (2 * t - 1) ** 2
        top.append((x, 0.25 * mouth_w * curve * 0.6))
        bot.append((x, -0.22 * mouth_w * (1 - curve) + 0.25 * mouth_w * curve * 0.6))
    outline = top + list(reversed(bot[1:-1]))
    prism(mouth, outline, 0.1, (cx, y + 0.03, mouth_z), root)
    n = 9
    for i in range(n):
        t0, t1 = (i + 0.15) / n, (i + 0.85) / n
        tm = (t0 + t1) / 2
        x0, x1, xm = [(t - 0.5) * mouth_w for t in (t0, t1, tm)]
        ztop = 0.25 * mouth_w * ((2 * tm - 1) ** 2) * 0.6
        length = 0.11 * mouth_w * (1 - 0.6 * abs(2 * tm - 1))
        prism(teeth, [(x0, ztop + 0.02), (x1, ztop + 0.02), (xm, ztop - length)], 0.12, (cx, y + 0.06, mouth_z), root)
        if 0 < i < n - 1:
            zb = -0.22 * mouth_w * (1 - (2 * tm - 1) ** 2) + 0.25 * mouth_w * ((2 * tm - 1) ** 2) * 0.6
            prism(teeth, [(x0, zb - 0.02), (xm, zb + length * 0.8), (x1, zb - 0.02)], 0.12, (cx, y + 0.06, mouth_z), root)


# ---------------------------------------------------------------- Investigador

def investigator(loc, facing_deg, target, coat=(0.09, 0.22, 0.32), hat=True, beam_len=26, power=9000, cones=False):
    """Personaje de bloques tipo Roblox con linterna apuntando a target."""
    root = empty("Investigator", loc)
    root.rotation_euler = (0, 0, math.radians(facing_deg))
    skin = flat("Skin", (0.78, 0.56, 0.4), 0.6)
    jacket = flat(f"Coat{coat}", coat, 0.75)
    pants = flat("Pants", (0.05, 0.05, 0.07), 0.8)
    brown = flat("Hat", (0.12, 0.07, 0.04), 0.7)
    for sx in (-1, 1):
        cube(pants, (0.95, 0.95, 2.0), (sx * 0.5, 0, 1.0), 0.06, root)
    cube(jacket, (2.0, 1.0, 2.0), (0, 0, 3.0), 0.08, root)
    cube(jacket, (2.1, 1.1, 0.25), (0, 0, 2.1), 0.05, root)          # bajo de la gabardina
    cube(skin, (1.15, 1.1, 1.1), (0, 0, 4.6), 0.18, root)
    if hat:
        cube(brown, (1.9, 1.8, 0.12), (0, 0, 5.18), 0.05, root)
        cube(brown, (1.25, 1.2, 0.6), (0, 0, 5.5), 0.1, root)
        cube(flat("Band", (0.3, 0.08, 0.06), 0.6), (1.27, 1.22, 0.15), (0, 0, 5.28), 0.02, root)
    # brazo izquierdo colgando
    cube(jacket, (0.95, 0.95, 2.0), (-1.5, 0, 3.0), 0.06, root)
    # brazo derecho: hombro que apunta a target
    shoulder = empty("Shoulder", (1.5, 0, 3.8), root)
    cube(jacket, (0.95, 0.95, 2.0), (0, 0, -0.9), 0.06, shoulder)
    cube(skin, (0.8, 0.8, 0.3), (0, 0, -2.0), 0.08, shoulder)
    body = flat("Torch", (0.08, 0.08, 0.09), 0.3, 0.8)
    tip = empty("Tip", (0, 0, -2.6), shoulder)
    cube(body, (0.32, 0.32, 1.1), (0, 0, -2.2), 0.05, shoulder)
    cube(body, (0.5, 0.5, 0.3), (0, 0, -2.75), 0.06, shoulder)
    cube(glow("Lens", (1.0, 0.9, 0.7), 40), (0.4, 0.4, 0.05), (0, 0, -2.92), 0, shoulder)
    con = shoulder.constraints.new("DAMPED_TRACK")
    con.target = target
    con.track_axis = "TRACK_NEGATIVE_Z"
    # luz y haz desde la lente
    spot = bpy.data.lights.new("Flashlight", "SPOT")
    spot.energy = power
    spot.color = (1.0, 0.88, 0.68)
    spot.spot_size = math.radians(34)
    spot.spot_blend = 0.45
    spot.shadow_soft_size = 0.15
    light = link(bpy.data.objects.new("Flashlight", spot))
    light.parent = tip
    light.location = (0, 0, -0.4)
    if not cones:
        return root
    cone_r = math.tan(math.radians(15)) * beam_len
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=False, segments=32, radius1=0.2, radius2=cone_r, depth=beam_len)
    bmesh.ops.translate(bm, vec=Vector((0, 0, -beam_len / 2)), verts=bm.verts)
    bmesh.ops.scale(bm, vec=Vector((1, 1, -1)), verts=bm.verts)  # z de 0 a -L
    bmesh.ops.scale(bm, vec=Vector((1 / beam_len, 1 / beam_len, 1 / beam_len)), verts=bm.verts)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new("Beam")
    bm.to_mesh(mesh)
    bm.free()
    for p in mesh.polygons:
        p.use_smooth = True
    cone = link(bpy.data.objects.new("Beam", mesh))
    cone.data.materials.append(beam_material())
    cone.parent = tip
    cone.location = (0, 0, -0.35)
    cone.scale = (beam_len, beam_len, beam_len)
    for attr in ("visible_shadow", "visible_diffuse", "visible_glossy", "visible_transmission", "visible_volume_scatter"):
        setattr(cone, attr, False)
    return root


# ---------------------------------------------------------------- render

def setup(res, samples=128):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 24 if PREVIEW else samples
    scene.cycles.use_denoising = True
    scene.cycles.max_bounces = 6
    scene.cycles.transparent_max_bounces = 16
    scene.render.resolution_x, scene.render.resolution_y = res
    scene.render.resolution_percentage = 35 if PREVIEW else 100
    scene.render.film_transparent = False
    try:
        scene.view_settings.view_transform = "AgX"
        scene.view_settings.look = "AgX - Medium High Contrast"
    except TypeError:
        pass
    world = bpy.data.worlds.new("World")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.006, 0.007, 0.014, 1)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 1.0
    scene.world = world


def camera(loc, target, lens=35):
    data = bpy.data.cameras.new("Cam")
    data.lens = lens
    cam = link(bpy.data.objects.new("Cam", data))
    cam.location = loc
    direction = Vector(target) - Vector(loc)
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = cam
    return cam


def fresh():
    mp.reset()
    _extra.clear()


# ---------------------------------------------------------------- tomas

def shot_icon():
    """Primer plano del armario-Anomalía iluminado por una linterna."""
    fresh()
    setup((1024, 1024), 160)
    room(width=30, back=-6, front=20, window_x=-8.5)
    painting(8.5, 8.2, -6)
    wardrobe = prop("Wardrobe", (0.3, -3.2, 0))
    mimic_face(wardrobe, (0, 6.15), 2.35, (1.55, 0.85), 3.4, 3.35, 1.32, glow_power=20)
    prop("FloorLamp", (5.6, -3.0, 0), -10)
    prop("Chair", (-4.6, -1.2, 0), 25)
    target = empty("Aim", (0.6, -2.0, 4.6))
    investigator((-6.5, 12, 0), -150, target, power=4500)
    lamp_bulb(5.6, -3.0)
    fog()
    camera((-1.0, 9.0, 3.4), (0.2, -2.5, 5.1), 26)


def rim(loc, target, power=600, size=(6, 6), color=(0.4, 0.55, 1.0)):
    """Luz de contorno azul (luna) para separar siluetas del fondo."""
    light = area_light(loc, (0, 0, 0), color, power, size)
    light.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    light.visible_camera = False
    return light


def shot_thumb1():
    """¿Cuál está vivo? Un investigador ilumina los muebles y el reloj de detrás le mira."""
    fresh()
    setup((1920, 1080))
    room(width=48, back=-12, front=24, window_x=-14.0)
    painting(-4.0, 8.8, -12)
    painting(4.5, 9.0, -12, 2.6, 3.2)
    prop("Dresser", (-8.5, -9.5, 0))
    prop("Vase", (-8.5, -9.5, 3.55))
    prop("Chair", (-2.0, -7.5, 0), 10)
    prop("Table", (-9.0, -2.5, 0), 5)
    prop("Bust", (-15.5, -5.0, 0), 25)
    prop("Bookshelf", (4.5, -10.8, 0))
    clock = prop("GrandfatherClock", (9.0, -7.5, 0), -25)
    mimic_face(clock, (0, 4.25), 1.0, (0.62, 0.36), 1.25, 3.05, 0.72, glow_power=8)
    prop("Chest", (16.0, -1.0, 0), -40)
    investigator((8.0, 2.5, 0), 120, empty("Aim", (-6.0, -7.0, 2.5)), power=12000)
    rim((14, -4, 9), (8, 2.5, 3), 500)
    fog(0.012)
    camera((12.5, 17.0, 6.0), (-0.5, -4.5, 3.6), 30)


def shot_thumb2():
    """La Anomalía en primer plano, disfrazada de silla, y el investigador detrás sin verla."""
    fresh()
    setup((1920, 1080))
    room(width=48, back=-16, front=24, window_x=-9.0)
    painting(4.5, 8.6, -16)
    painting(12.5, 8.6, -16, 2.6, 3.4)
    chair = prop("Chair", (5.5, 6.5, 0), -25)
    mimic_face(chair, (0, 4.35), 0.8, (0.6, 0.32), 1.1, 3.3, -0.88, glow_power=6)
    prop("Bookshelf", (-15.0, -14.5, 0))
    prop("CuckooClock", (14.0, -13.0, 0))
    prop("Dresser", (2.0, -14.0, 0))
    prop("Vase", (2.0, -14.0, 3.55))
    prop("BloodyStatue", (-4.0, -12.0, 0), 15)
    prop("Table", (-10.0, -6.0, 0), 10)
    investigator((-6.5, -3.5, 0), 205, empty("Aim", (-14.0, -12.0, 3.0)), power=10000)
    rim((-12, -10, 9), (-6.5, -3.5, 3), 500)
    fog(0.012)
    camera((10.0, 15.5, 4.2), (0.5, -4.0, 3.6), 28)


def shot_thumb3():
    """Dos investigadores entran en la sala; el armario y el jarrón del fondo tienen ojos."""
    fresh()
    setup((1920, 1080))
    room(width=52, back=-16, front=26, window_x=0.0)
    painting(-11.0, 8.8, -16)
    painting(11.0, 8.8, -16)
    ward = prop("Wardrobe", (-14.0, -12.5, 0), 15)
    mimic_face(ward, (0, 6.15), 2.35, (1.4, 0.75), 3.2, 3.35, 1.32, glow_power=12)
    prop("GrandfatherClock", (-6.5, -14.0, 0))
    prop("Table", (3.0, -8.0, 0))
    vase = prop("Vase", (3.0, -8.0, 3.25))
    mimic_face(vase, (0, 1.55), 0.52, (0.36, 0.2), 0.7, 1.05, 0.78, glow_power=3)
    prop("Bookshelf", (13.5, -14.5, 0))
    prop("FloorLamp", (19.0, -10.0, 0))
    lamp_bulb(19.0, -10.0)
    prop("Chest", (9.0, -5.0, 0), -20)
    prop("Chair", (-4.0, -6.0, 0), 30)
    investigator((-5.0, 7.0, 0), 195, empty("Aim", (-2.0, -7.0, 2.0)), power=9000)
    investigator((5.5, 8.0, 0), 165, empty("Aim", (12.0, -12.0, 4.0)), coat=(0.32, 0.12, 0.08), power=9000)
    rim((0, -6, 10), (0, 8.5, 3), 700, (10, 4))
    fog(0.012)
    camera((0.5, 26.0, 6.0), (0.5, -6.0, 4.2), 30)


SHOTS = {"icon": shot_icon, "thumb1": shot_thumb1, "thumb2": shot_thumb2, "thumb3": shot_thumb3}


def main():
    args = [a for a in (sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]) if not a.startswith("--")]
    out = os.path.abspath(args[0] if args else "assets/marketing/renders")
    names = args[1:] or list(SHOTS)
    os.makedirs(out, exist_ok=True)
    for name in names:
        SHOTS[name]()
        bpy.context.scene.render.filepath = os.path.join(out, f"{name}.png")
        bpy.ops.render.render(write_still=True)
        print("render", name)


if __name__ == "__main__":
    main()
