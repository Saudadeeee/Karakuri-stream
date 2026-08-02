@tool
extends SceneTree

## Rasterise icon.svg into the PNG the Windows .ico is packed from.
##
##   godot --headless --path . --script tools/gen_icon.gd
##   python tools/gen_icon.py          # PNG -> assets/icon/icon.ico
##
## Why not just point the export preset at icon.svg: Windows executables carry
## an .ico resource, and Godot writes that resource itself — it takes an .ico or
## nothing, which is why the exe shipped with the generic Godot icon.
##
## 256 px is the largest size Explorer uses; PIL downsamples the rest when it
## packs the .ico, so one clean raster is all this has to produce.

const SVG_PATH := "res://icon.svg"
const OUT_DIR := "res://assets/icon"

## Every size a store or an OS asks for. Each is rasterised FROM THE SVG rather
## than resampled from one big PNG — vector art has no reason to go through a
## downscale, and the 1 px border on this icon smears when it does.
##   256  packed into icon.ico for Windows (tools/gen_icon.py)
##   192  Android launcher
##   120/152/167/180  iPhone / iPad
##   1024 App Store listing
const SIZES: Array[int] = [120, 152, 167, 180, 192, 256, 1024]

func _init() -> void:
	var f := FileAccess.open(SVG_PATH, FileAccess.READ)
	if f == null:
		push_error("gen_icon: cannot read %s" % SVG_PATH)
		quit(1)
		return
	var svg := f.get_buffer(f.get_length())
	f.close()

	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	for size in SIZES:
		var img := Image.new()
		var err := img.load_svg_from_buffer(svg, float(size) / 128.0)  # source is 128x128
		if err != OK or img.is_empty():
			push_error("gen_icon: SVG rasterise failed at %d (%d)" % [size, err])
			quit(1)
			return
		var path := "%s/icon_%d.png" % [OUT_DIR, size]
		if img.save_png(path) != OK:
			push_error("gen_icon: could not write %s" % path)
			quit(1)
			return
		print("ICON %dx%d -> %s" % [img.get_width(), img.get_height(), path])
	quit(0)
