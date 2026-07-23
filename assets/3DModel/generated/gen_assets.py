import bpy, math, os, sys
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import importlib, stylekit
importlib.reload(stylekit)
K = stylekit

OUT = sys.argv[sys.argv.index("--") + 1]   # output dir

# ---------------------------------------------------------------- blocks
def wood_block():
    b = K.box(1.7, 1.7, 1.7, "wood")
    K.finish(b, bevel=0.14, angle=30); K.set_mat(b, K.WOOD)
    return b

def water_block():
    b = K.box(1.7, 1.6, 1.7, "water")
    K.finish(b, bevel=0.22, angle=45); K.set_mat(b, K.WATER)
    return b

def cogwheel():
    parts = [K.cyl(0.68, 0.44, 24, "hub"), K.cyl(0.24, 1.3, 16, "axle")]
    for i in range(8):
        a = 2 * math.pi * i / 8
        t = K.box(0.30, 0.44, 0.52, "t%d" % i)  # inner end 0.48 tucks into 0.68 hub
        t.location = (math.cos(a) * 0.74, 0, math.sin(a) * 0.74)
        t.rotation_euler = (0, -a, 0)
        parts.append(t)
    g = K.join(parts, "cogwheel")
    K.finish(g, bevel=0.05, angle=35); K.set_mat(g, K.WOOD)
    return g

def chime():
    # wooden frame
    post_l = K.box(0.12, 1.5, 0.12, "pl"); post_l.location = (-0.55, 0.0, 0)
    post_r = K.box(0.12, 1.5, 0.12, "pr"); post_r.location = (0.55, 0.0, 0)
    beam = K.box(1.35, 0.14, 0.14, "beam"); beam.location = (0, 0.75, 0)
    for p in (post_l, post_r, beam):
        K.set_mat(p, K.WOOD)
    # bell (stone) hanging under beam
    bell = K.cone(0.42, 0.16, 0.58, 20, "bell"); bell.location = (0, 0.28, 0)
    crown = K.uvsphere(0.12, 12, 6, "crown"); crown.location = (0, 0.60, 0)
    K.set_mat(bell, K.STONE); K.set_mat(crown, K.STONE)
    # red cinnabar string
    string = K.box(0.04, 0.16, 0.04, "str"); string.location = (0, 0.70, 0)
    K.set_mat(string, K.ACCENT)
    ob = K.join([post_l, post_r, beam, bell, crown, string], "chime")
    K.finish(ob, bevel=0.03, angle=35)
    return ob

# ---------------------------------------------------------------- nature
def grass_tuft():
    # upright clump: blades on a small circle, each leaning gently OUTWARD
    # along its own radial direction (stays vertical-ish, not splayed flat).
    blades = []
    heights = [1.5, 1.3, 1.65, 1.4, 1.55, 1.25, 1.45, 1.35]
    for i, h in enumerate(heights):
        a = 2 * math.pi * i / len(heights)
        dx, dz = math.cos(a), math.sin(a)
        r = 0.14
        lean = math.radians(14)
        bl = K.cone(0.075, 0.0, h, 6, "b%d" % i)
        bl.location = (dx * r, h * 0.5, dz * r)
        # tilt top outward: +Z-tilt moves top toward -x, +X-tilt toward +z
        bl.rotation_euler = (lean * dz, 0.0, -lean * dx)
        blades.append(bl)
    g = K.join(blades, "grass_tuft")
    K.finish(g, bevel=0.02, angle=40); K.set_mat(g, K.BAMBOO)
    return g

def bamboo_stalk():
    # tall + slim so it reads as bamboo, thin node rings, a slight lean
    parts = []
    y = 0.0
    SEG_H, R = 0.62, 0.1
    for i in range(3):
        seg = K.cyl(R, SEG_H, 12, "s%d" % i); seg.location = (0, y + SEG_H / 2, 0)
        parts.append(seg)
        node = K.cyl(R + 0.025, 0.05, 12, "n%d" % i); node.location = (0, y + 0.01, 0)
        parts.append(node)
        y += SEG_H
    top = K.cyl(R + 0.025, 0.05, 12, "ntop"); top.location = (0, y, 0); parts.append(top)
    # a couple of leaf blades near the top
    for j, (tilt, ang) in enumerate([(60, 30), (-55, 200)]):
        lf = K.cone(0.06, 0.0, 0.55, 6, "lf%d" % j)
        lf.location = (0.12 * math.cos(math.radians(ang)), y - 0.15, 0.12 * math.sin(math.radians(ang)))
        lf.rotation_euler = (math.radians(tilt), math.radians(ang), 0)
        parts.append(lf)
    st = K.join(parts, "bamboo_stalk")
    st.rotation_euler = (math.radians(3), 0, math.radians(4))
    K.finish(st, bevel=0.025, angle=35); K.set_mat(st, K.BAMBOO)
    return st

def bamboo_pipe():
    # angled spout: a tilted bamboo tube + node bands + a red string wrap
    tube = K.cyl(0.16, 1.3, 12, "tube")
    tube.rotation_euler = (0, 0, math.radians(55))
    tube.location = (0, 0.4, 0)
    n1 = K.cyl(0.18, 0.06, 12, "n1"); n1.rotation_euler = (0, 0, math.radians(55))
    n1.location = (-0.35, 0.9, 0)
    n2 = K.cyl(0.18, 0.06, 12, "n2"); n2.rotation_euler = (0, 0, math.radians(55))
    n2.location = (0.35, -0.1, 0)
    for p in (tube, n1, n2):
        K.set_mat(p, K.BAMBOO)
    wrap = K.cyl(0.185, 0.1, 12, "wrap"); wrap.rotation_euler = (0, 0, math.radians(55))
    wrap.location = (0, 0.4, 0); K.set_mat(wrap, K.ACCENT)
    ob = K.join([tube, n1, n2, wrap], "bamboo_pipe")
    K.finish(ob, bevel=0.03, angle=35)
    return ob

def lily_pad():
    pad = K.cyl(0.75, 0.08, 24, "pad")
    # notch: boolean a wedge out
    wedge = K.box(0.9, 0.4, 0.5, "wedge"); wedge.location = (0.7, 0, 0.0)
    wedge.rotation_euler = (0, math.radians(20), 0)
    bpy.context.view_layer.objects.active = pad
    boo = pad.modifiers.new("b", 'BOOLEAN'); boo.operation = 'DIFFERENCE'; boo.object = wedge
    bpy.ops.object.select_all(action='DESELECT'); pad.select_set(True)
    bpy.context.view_layer.objects.active = pad
    bpy.ops.object.modifier_apply(modifier="b")
    bpy.data.objects.remove(wedge, do_unlink=True)
    K.set_mat(pad, K.BAMBOO)
    # flower
    petals = []
    for i in range(6):
        a = 2 * math.pi * i / 6
        pt = K.cone(0.09, 0.0, 0.3, 6, "p%d" % i)
        pt.location = (math.cos(a) * 0.14, 0.14, math.sin(a) * 0.14)
        pt.rotation_euler = (math.radians(55) * math.cos(a), 0, math.radians(-55) * math.sin(a))
        K.set_mat(pt, K.ACCENT); petals.append(pt)
    center = K.uvsphere(0.08, 10, 6, "fc"); center.location = (0, 0.16, 0)
    K.set_mat(center, K.PAPER)
    ob = K.join([pad] + petals + [center], "lily_pad")
    K.finish(ob, bevel=0.02, angle=40)
    return ob

def rock():
    a = K.ico(0.7, 1, "a"); a.scale = (1.1, 0.8, 0.95)
    b = K.ico(0.42, 1, "b"); b.location = (0.5, -0.15, 0.25); b.scale = (1.0, 0.7, 1.0)
    r = K.join([a, b], "rock")
    K.finish(r, bevel=0.05, angle=45); K.set_mat(r, K.STONE)
    return r

def lantern():
    base = K.box(0.7, 0.16, 0.7, "base"); base.location = (0, 0.08, 0)
    top = K.box(0.8, 0.14, 0.8, "top"); top.location = (0, 1.35, 0)
    cap = K.cone(0.55, 0.1, 0.3, 4, "cap"); cap.location = (0, 1.55, 0); cap.rotation_euler=(0,math.radians(45),0)
    for p in (base, top, cap):
        K.set_mat(p, K.WOOD)
    posts = []
    for sx in (-1, 1):
        for sz in (-1, 1):
            po = K.box(0.08, 1.1, 0.08, "po")
            po.location = (0.28 * sx, 0.75, 0.28 * sz)
            K.set_mat(po, K.WOOD); posts.append(po)
    paper = K.box(0.5, 0.95, 0.5, "paper"); paper.location = (0, 0.75, 0)
    K.set_mat(paper, K.PAPER)
    string = K.box(0.05, 0.2, 0.05, "s"); string.location = (0, 1.62, 0)
    K.set_mat(string, K.ACCENT)
    ob = K.join([base, top, cap, paper, string] + posts, "lantern")
    K.finish(ob, bevel=0.03, angle=35)
    return ob

def bonsai():
    pot = K.cone(0.5, 0.4, 0.45, 12, "pot"); pot.location = (0, 0.22, 0)
    K.set_mat(pot, K.ACCENT)
    soil = K.cyl(0.44, 0.08, 12, "soil"); soil.location = (0, 0.44, 0)
    K.set_mat(soil, K.WOOD)
    trunk = K.cone(0.12, 0.07, 0.7, 8, "trunk"); trunk.location = (0, 0.8, 0)
    trunk.rotation_euler = (0, 0, math.radians(8))
    K.set_mat(trunk, K.WOOD)
    foliage = []
    for (x, y, z, r, c) in [(-0.15, 1.15, 0.05, 0.34, K.BAMBOO),
                             (0.22, 1.25, -0.1, 0.28, K.LEAF_D),
                             (0.05, 1.4, 0.15, 0.26, K.BAMBOO)]:
        f = K.ico(r, 1, "f"); f.location = (x, y, z); f.scale = (1.0, 0.75, 1.0)
        K.set_mat(f, c); foliage.append(f)
    ob = K.join([pot, soil, trunk] + foliage, "bonsai")
    K.finish(ob, bevel=0.03, angle=40)
    return ob

ASSETS = [
    ("wood_block", wood_block), ("water_block", water_block),
    ("cogwheel", cogwheel), ("chime", chime),
    ("grass_tuft", grass_tuft), ("bamboo_stalk", bamboo_stalk),
    ("bamboo_pipe", bamboo_pipe), ("lily_pad", lily_pad),
    ("rock", rock), ("lantern", lantern), ("bonsai", bonsai),
]

for name, fn in ASSETS:
    K.reset()
    ob = fn()
    K.export(ob, os.path.join(OUT, name + ".glb"))

print("ALL_DONE")
