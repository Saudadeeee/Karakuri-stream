import bpy, math, os, sys
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import importlib, stylekit
importlib.reload(stylekit)
K = stylekit
OUT = sys.argv[sys.argv.index("--") + 1]

# NOTE ON AXES: Blender is Z-up, Godot is Y-up. glTF export converts Blender
# (x,y,z) -> Godot (x, z, -y). So to get a FLAT wheel in Godot (disc in X-Z,
# axle along Y) we author it FLAT in Blender (disc in X-Y, axle along Z), and to
# get something STANDING in Godot we author it tall along Blender Z.

# ---------------------------------------------------------------- gear (fixed)
def gear():
    # solid disc so teeth are clearly part of one wheel, teeth on the rim,
    # raised hub, axle through the middle. Authored flat (disc in Blender X-Y).
    disc = K.cyl(0.60, 0.26, 28, "disc")
    hub = K.cyl(0.26, 0.42, 20, "hub")
    axle = K.cyl(0.10, 1.35, 14, "axle")
    parts = [disc, hub, axle]
    N = 10
    for i in range(N):
        a = 2 * math.pi * i / N
        # radial box on the rim: sy = radial length, sx = tangential width
        t = K.box(0.15, 0.30, 0.26, "t%d" % i)
        t.location = (math.cos(a) * 0.66, math.sin(a) * 0.66, 0.0)
        t.rotation_euler = (0.0, 0.0, a + math.pi / 2)  # sy(radial) points out
        parts.append(t)
    g = K.join(parts, "gear")
    K.finish(g, bevel=0.04, angle=35); K.set_mat(g, K.WOOD)
    return g

# ---------------------------------------------------------------- bell (fixed)
def bell():
    # torii-like stand (two posts + beam) with a temple bell hanging under it.
    pl = K.box(0.11, 0.11, 1.25, "pl"); pl.location = (-0.5, 0.0, 0.62)
    pr = K.box(0.11, 0.11, 1.25, "pr"); pr.location = (0.5, 0.0, 0.62)
    beam = K.box(1.3, 0.14, 0.14, "beam"); beam.location = (0.0, 0.0, 1.25)
    for p in (pl, pr, beam):
        K.set_mat(p, K.WOOD)
    # bell body: tapered skirt + rounded shoulder + crown loop
    skirt = K.cone(0.36, 0.28, 0.42, 24, "skirt"); skirt.location = (0.0, 0.0, 0.62)
    dome = K.uvsphere(0.28, 20, 10, "dome"); dome.location = (0.0, 0.0, 0.86)
    bpy.ops.object.select_all(action='DESELECT'); dome.select_set(True)
    bpy.context.view_layer.objects.active = dome
    bpy.ops.transform.resize(value=(1.0, 1.0, 0.55))  # squash to a shoulder cap
    loop = K.cyl(0.05, 0.12, 10, "loop"); loop.location = (0.0, 0.0, 1.02)
    for p in (skirt, dome, loop):
        K.set_mat(p, K.STONE)
    clap = K.uvsphere(0.08, 10, 6, "clap"); clap.location = (0.0, 0.0, 0.5)
    K.set_mat(clap, K.STONE)
    string = K.box(0.04, 0.04, 0.16, "string"); string.location = (0.0, 0.0, 1.14)
    K.set_mat(string, K.ACCENT)
    ob = K.join([pl, pr, beam, skirt, dome, loop, clap, string], "bell")
    K.finish(ob, bevel=0.02, angle=35)
    return ob

# ---------------------------------------------------------------- bamboo pipe: straight
def pipe_straight():
    # a bamboo trough/tube running along Blender X -> Godot X. Ports = +/-X.
    tube = K.cyl(0.17, 0.98, 14, "tube"); tube.rotation_euler = (0, math.pi / 2, 0)
    n1 = K.cyl(0.2, 0.06, 14, "n1"); n1.rotation_euler = (0, math.pi / 2, 0); n1.location = (0.4, 0, 0)
    n2 = K.cyl(0.2, 0.06, 14, "n2"); n2.rotation_euler = (0, math.pi / 2, 0); n2.location = (-0.4, 0, 0)
    for p in (tube, n1, n2):
        K.set_mat(p, K.BAMBOO)
    band = K.cyl(0.205, 0.08, 14, "band"); band.rotation_euler = (0, math.pi / 2, 0)
    K.set_mat(band, K.ACCENT)
    ob = K.join([tube, n1, n2, band], "pipe_straight")
    K.finish(ob, bevel=0.03, angle=35)
    return ob

# ---------------------------------------------------------------- bamboo pipe: elbow
def pipe_elbow():
    # bend joining the TOP (+Z -> Godot +Y) and a SIDE (+X). Water in top, out +X.
    top = K.cyl(0.17, 0.5, 14, "top"); top.location = (0, 0, 0.25)          # +Z port
    side = K.cyl(0.17, 0.5, 14, "side"); side.rotation_euler = (0, math.pi / 2, 0)
    side.location = (0.25, 0, 0)                                            # +X port
    knee = K.uvsphere(0.19, 16, 10, "knee")
    nt = K.cyl(0.2, 0.06, 14, "nt"); nt.location = (0, 0, 0.48)
    ns = K.cyl(0.2, 0.06, 14, "ns"); ns.rotation_euler = (0, math.pi / 2, 0); ns.location = (0.48, 0, 0)
    for p in (top, side, knee, nt, ns):
        K.set_mat(p, K.BAMBOO)
    band = K.cyl(0.205, 0.07, 14, "band"); band.location = (0, 0, 0.32)
    K.set_mat(band, K.ACCENT)
    ob = K.join([top, side, knee, nt, ns, band], "pipe_elbow")
    K.finish(ob, bevel=0.03, angle=35)
    return ob

# ---------------------------------------------------------------- source spout
def source():
    # a shishi-odoshi style spout: an upright bamboo post feeding an angled
    # cut spout whose mouth points down -> emits the stream downward.
    post = K.cyl(0.18, 0.8, 14, "post"); post.location = (0, 0, 0.1)
    spout = K.cyl(0.15, 0.7, 14, "spout")
    spout.rotation_euler = (0, math.radians(58), 0)
    spout.location = (0.28, 0, 0.42)
    node = K.cyl(0.21, 0.06, 14, "node"); node.location = (0, 0, 0.42)
    for p in (post, spout, node):
        K.set_mat(p, K.BAMBOO)
    band = K.cyl(0.16, 0.07, 14, "band"); band.rotation_euler = (0, math.radians(58), 0)
    band.location = (0.42, 0, 0.18); K.set_mat(band, K.ACCENT)
    ob = K.join([post, spout, node, band], "source")
    K.finish(ob, bevel=0.03, angle=35)
    return ob

# ---------------------------------------------------------------- scenery
def pine_tree():
    trunk = K.cone(0.14, 0.1, 0.7, 8, "trunk"); trunk.location = (0, 0, 0.35)
    K.set_mat(trunk, K.WOOD)
    tiers = []
    for i, (z, r) in enumerate([(0.75, 0.6), (1.05, 0.45), (1.3, 0.3)]):
        c = K.cone(r, 0.0, 0.45, 10, "c%d" % i); c.location = (0, 0, z)
        K.set_mat(c, K.BAMBOO if i % 2 == 0 else K.LEAF_D); tiers.append(c)
    ob = K.join([trunk] + tiers, "pine_tree")
    K.finish(ob, bevel=0.02, angle=40)
    return ob

def bush():
    blobs = []
    for (x, y, z, r) in [(-0.2, 0, 0.25, 0.32), (0.22, 0.05, 0.22, 0.28),
                          (0.0, -0.15, 0.35, 0.3), (0.05, 0.2, 0.28, 0.24)]:
        b = K.ico(r, 1, "b"); b.location = (x, y, z); b.scale = (1, 1, 0.9)
        K.set_mat(b, K.BAMBOO if (x + z) > 0.4 else K.LEAF_D); blobs.append(b)
    ob = K.join(blobs, "bush")
    K.finish(ob, bevel=0.03, angle=45)
    return ob

def reeds():
    stalks = []
    for i in range(7):
        a = 2 * math.pi * i / 7
        r = 0.16
        h = 1.1 + 0.25 * (i % 3)
        s = K.cyl(0.035, h, 6, "s%d" % i)
        s.location = (math.cos(a) * r, math.sin(a) * r, h / 2)
        s.rotation_euler = (math.radians(6) * math.sin(a), math.radians(6) * math.cos(a), 0)
        K.set_mat(s, K.BAMBOO); stalks.append(s)
        # cattail head
        head = K.cyl(0.055, 0.22, 8, "h%d" % i)
        head.location = (math.cos(a) * r, math.sin(a) * r, h - 0.05)
        K.set_mat(head, K.WOOD); stalks.append(head)
    ob = K.join(stalks, "reeds")
    K.finish(ob, bevel=0.02, angle=40)
    return ob

def rock_cluster():
    a = K.ico(0.55, 1, "a"); a.scale = (1.2, 0.9, 0.7)
    b = K.ico(0.38, 1, "b"); b.location = (0.55, 0.1, 0.0); b.scale = (1.0, 0.8, 0.85)
    c = K.ico(0.3, 1, "c"); c.location = (-0.4, -0.2, -0.05); c.scale = (1.1, 0.9, 0.7)
    ob = K.join([a, b, c], "rock_cluster")
    K.finish(ob, bevel=0.05, angle=45); K.set_mat(ob, K.STONE)
    return ob

ASSETS = [("gear", gear), ("bell", bell), ("pipe_straight", pipe_straight),
          ("pipe_elbow", pipe_elbow), ("source", source),
          ("pine_tree", pine_tree), ("bush", bush), ("reeds", reeds),
          ("rock_cluster", rock_cluster)]
for name, fn in ASSETS:
    K.reset(); ob = fn(); K.export(ob, os.path.join(OUT, name + ".glb"))
print("ALL_DONE")
