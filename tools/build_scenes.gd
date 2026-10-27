extends SceneTree
## Генератор 3D-сцен прототипа: материалы, модульные пропсы, интерактивные
## объекты, игрок, фигура, уровень «Дом» и фон главного меню.
##
## Запуск (из папки проекта):
##   godot --headless --path . --script res://tools/build_scenes.gd
##
## Сцены сохраняются как обычные .tscn — после генерации их можно
## открывать и править в редакторе. ВНИМАНИЕ: повторный запуск генератора
## перезапишет сгенерированные сцены (scenes/props, scenes/interactables,
## scenes/player, scenes/characters, scenes/levels/HouseLevel.tscn,
## scenes/menus/MenuBackdrop.tscn). Ручные правки делайте после генерации
## либо вносите изменения прямо в этот скрипт.

const T := 0.2            # толщина стены
const H := 2.8            # высота этажа
const DOOR_W := 1.0
const DOOR_H := 2.1
const TEX := "res://assets/textures/"
const MAT_DIR := "res://resources/materials/"

var mats: Dictionary = {}
var fonts: Dictionary = {}
var _errors := 0


## _initialize (а не _init): к этому моменту автозагрузки уже зарегистрированы,
## и скрипты, ссылающиеся на GameState/Loc и т.п., компилируются.
func _initialize() -> void:
	print("== build_scenes ==")
	fonts["serif"] = load("res://assets/fonts/DejaVuSerif.ttf")
	fonts["sans"] = load("res://assets/fonts/DejaVuSans.ttf")
	_build_materials()
	_build_theme()
	_build_props()
	_build_interactables()
	_build_player()
	_build_characters()
	_build_level()
	_build_menu_backdrop()
	print("== done, errors: %d ==" % _errors)
	quit(1 if _errors > 0 else 0)


# =====================================================================
# Материалы
# =====================================================================

func _tex_mat(name_: String, tex: String, scale: float, world: bool, rough: float = 0.88, tint := Color.WHITE) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.resource_name = name_
	m.albedo_texture = load(TEX + tex)
	m.albedo_color = tint
	m.roughness = rough
	m.uv1_triplanar = true
	m.uv1_world_triplanar = world
	m.uv1_scale = Vector3.ONE * scale
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m


func _color_mat(name_: String, c: Color, rough: float = 0.7, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.resource_name = name_
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m


func _uv_mat(name_: String, tex: String, rough: float = 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.resource_name = name_
	m.albedo_texture = load(TEX + tex)
	m.roughness = rough
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m


func _save_mat(m: Material) -> void:
	var path := MAT_DIR + m.resource_name + ".tres"
	var err := ResourceSaver.save(m, path)
	if err != OK:
		_fail("material " + path + ": " + error_string(err))
	mats[m.resource_name] = load(path)


func _build_materials() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MAT_DIR))
	var list: Array[Material] = [
		_tex_mat("wallpaper_a", "wallpaper_a.png", 1.0, true),
		_tex_mat("wallpaper_b", "wallpaper_b.png", 1.0, true),
		_tex_mat("wallpaper_c", "wallpaper_c.png", 1.0, true),
		_tex_mat("wallpaper_start", "wallpaper_start.png", 0.8, true),
		_tex_mat("wallpaper_13", "wallpaper_13_marks.png", 0.9, true),
		_tex_mat("paint_green", "paint_green.png", 0.6, true, 0.6),
		_tex_mat("paint_blue", "paint_blue.png", 0.6, true, 0.6),
		_tex_mat("paint_grey", "paint_grey.png", 0.6, true, 0.75),
		_tex_mat("whitewash", "whitewash.png", 0.5, true, 0.88, Color(0.78, 0.77, 0.74)),
		_tex_mat("ceiling", "ceiling.png", 0.45, true, 0.9, Color(0.8, 0.8, 0.78)),
		_tex_mat("linoleum", "linoleum.png", 0.8, true, 0.55),
		_tex_mat("parquet", "parquet.png", 0.6, true, 0.6),
		_tex_mat("concrete", "concrete.png", 0.5, true, 0.95),
		_tex_mat("door_wood", "door_wood.png", 1.0, false, 0.7),
		_tex_mat("door_wood_green", "door_wood_green.png", 1.0, false, 0.65),
		_tex_mat("wood_varnish", "wood_varnish.png", 1.5, false, 0.45),
		_tex_mat("wood_trim", "door_wood.png", 2.0, false, 0.6),
		_tex_mat("metal_painted", "metal_painted.png", 1.0, false, 0.6),
		_tex_mat("metal_rust", "metal_rust.png", 1.0, false, 0.75),
		_tex_mat("fabric_a", "fabric_a.png", 2.0, false, 0.95),
		_tex_mat("fabric_b", "fabric_b.png", 2.0, false, 0.95),
		_tex_mat("paper_local", "paper.png", 3.0, false, 0.95),
		_color_mat("enamel", Color(0.78, 0.77, 0.72), 0.35),
		_color_mat("window_frame", Color(0.5, 0.5, 0.47), 0.6),
		_color_mat("brass", Color(0.62, 0.48, 0.26), 0.35, 0.85),
		_color_mat("steel", Color(0.55, 0.56, 0.57), 0.4, 0.8),
		_color_mat("black_plastic", Color(0.05, 0.05, 0.05), 0.4),
		_color_mat("ivory_plastic", Color(0.72, 0.68, 0.58), 0.45),
		_color_mat("cord", Color(0.08, 0.07, 0.06), 0.8),
		_color_mat("figure_dark", Color(0.025, 0.025, 0.03), 1.0),
		_color_mat("book_red", Color(0.35, 0.09, 0.07), 0.8),
		_color_mat("book_green", Color(0.12, 0.22, 0.14), 0.8),
		_color_mat("book_blue", Color(0.1, 0.13, 0.25), 0.8),
		_color_mat("book_brown", Color(0.3, 0.2, 0.12), 0.8),
		_color_mat("screen", Color(0.06, 0.08, 0.07), 0.15),
		_uv_mat("paper", "paper.png"),
		_uv_mat("photo_yard", "photo_yard.png", 0.5),
		_uv_mat("photo_portrait", "photo_portrait.png", 0.5),
		_uv_mat("calendar", "calendar_1998.png", 0.9),
	]
	for m in list:
		_save_mat(m)
	# Светящиеся материалы
	var bulb := StandardMaterial3D.new()
	bulb.resource_name = "bulb_warm"
	bulb.albedo_color = Color(1.0, 0.86, 0.62)
	bulb.emission_enabled = true
	bulb.emission = Color(1.0, 0.8, 0.55)
	bulb.emission_energy_multiplier = 3.0
	_save_mat(bulb)
	var shade := StandardMaterial3D.new()
	shade.resource_name = "lampshade"
	shade.albedo_color = Color(0.75, 0.62, 0.42)
	shade.emission_enabled = true
	shade.emission = Color(0.55, 0.38, 0.2)
	shade.emission_energy_multiplier = 0.6
	shade.roughness = 0.9
	shade.cull_mode = BaseMaterial3D.CULL_DISABLED
	_save_mat(shade)
	var glass := StandardMaterial3D.new()
	glass.resource_name = "window_night"
	glass.albedo_texture = load(TEX + "window_night.png")
	glass.emission_enabled = true
	glass.emission_texture = load(TEX + "window_night.png")
	glass.emission_energy_multiplier = 1.4
	glass.roughness = 0.1
	_save_mat(glass)
	print("materials: ", mats.size())


func _build_theme() -> void:
	var th := Theme.new()
	th.default_font = fonts["serif"]
	th.default_font_size = 22
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.05, 0.05, 0.055, 0.92)
	panel.border_color = Color(0.45, 0.4, 0.32, 0.6)
	panel.set_border_width_all(1)
	panel.set_content_margin_all(18)
	th.set_stylebox("panel", "PanelContainer", panel)
	th.set_stylebox("panel", "Panel", panel)
	var btn := StyleBoxFlat.new()
	btn.bg_color = Color(0, 0, 0, 0)
	btn.set_content_margin_all(8)
	btn.content_margin_left = 14
	var btn_h := btn.duplicate() as StyleBoxFlat
	btn_h.bg_color = Color(0.75, 0.65, 0.45, 0.12)
	btn_h.border_color = Color(0.78, 0.68, 0.5, 0.7)
	btn_h.border_width_left = 3
	var btn_p := btn_h.duplicate() as StyleBoxFlat
	btn_p.bg_color = Color(0.75, 0.65, 0.45, 0.22)
	for st: String in ["normal", "disabled"]:
		th.set_stylebox(st, "Button", btn)
	th.set_stylebox("hover", "Button", btn_h)
	th.set_stylebox("focus", "Button", btn_h)
	th.set_stylebox("pressed", "Button", btn_p)
	th.set_color("font_color", "Button", Color(0.82, 0.79, 0.72))
	th.set_color("font_hover_color", "Button", Color(1, 0.95, 0.85))
	th.set_color("font_focus_color", "Button", Color(1, 0.95, 0.85))
	th.set_color("font_pressed_color", "Button", Color(1, 0.9, 0.7))
	th.set_color("font_color", "Label", Color(0.84, 0.81, 0.74))
	th.set_color("default_color", "RichTextLabel", Color(0.86, 0.83, 0.76))
	th.set_font_size("font_size", "Button", 24)
	var il := StyleBoxFlat.new()
	il.bg_color = Color(0, 0, 0, 0.25)
	il.set_content_margin_all(6)
	th.set_stylebox("panel", "ItemList", il)
	th.set_color("font_color", "ItemList", Color(0.8, 0.77, 0.7))
	th.set_color("font_selected_color", "ItemList", Color(1, 0.95, 0.85))
	var err := ResourceSaver.save(th, "res://resources/ui_theme.tres")
	if err != OK:
		_fail("theme: " + error_string(err))


# =====================================================================
# Помощники построения
# =====================================================================

func _fail(msg: String) -> void:
	_errors += 1
	push_error("BUILD: " + msg)


func _m(name_: String) -> Material:
	if not mats.has(name_):
		_fail("нет материала " + name_)
		return null
	return mats[name_]


func _mesh_box(size: Vector3, mat: String) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	b.material = _m(mat)
	return b


## Видимый ящик (без столкновений)
func vbox(parent: Node, name_: String, pos: Vector3, size: Vector3, mat: String, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name_
	mi.mesh = _mesh_box(size, mat)
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


func vcyl(parent: Node, name_: String, pos: Vector3, radius_top: float, radius_bottom: float, height: float, mat: String, rot := Vector3.ZERO, segments := 16) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = radius_top
	c.bottom_radius = radius_bottom
	c.height = height
	c.radial_segments = segments
	c.rings = 1
	c.material = _m(mat)
	var mi := MeshInstance3D.new()
	mi.name = name_
	mi.mesh = c
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


func vsphere(parent: Node, name_: String, pos: Vector3, r: float, mat: String) -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2
	s.radial_segments = 12
	s.rings = 6
	s.material = _m(mat)
	var mi := MeshInstance3D.new()
	mi.name = name_
	mi.mesh = s
	mi.position = pos
	parent.add_child(mi)
	return mi


func vquad(parent: Node, name_: String, pos: Vector3, size: Vector2, mat: String, rot := Vector3.ZERO) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = size
	q.material = _m(mat)
	var mi := MeshInstance3D.new()
	mi.name = name_
	mi.mesh = q
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


func col_box(parent: Node, name_: String, pos: Vector3, size: Vector3, rot := Vector3.ZERO) -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	cs.name = name_
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = pos
	cs.rotation = rot
	parent.add_child(cs)
	return cs


## Статичный твёрдый ящик: StaticBody3D + меш + столкновение
func sbox(parent: Node, name_: String, pos: Vector3, size: Vector3, mat: String, rot := Vector3.ZERO) -> StaticBody3D:
	var sb := StaticBody3D.new()
	sb.name = name_
	sb.position = pos
	sb.rotation = rot
	parent.add_child(sb)
	vbox(sb, "Mesh", Vector3.ZERO, size, mat)
	col_box(sb, "Col", Vector3.ZERO, size)
	return sb


func node3d(parent: Node, name_: String, pos := Vector3.ZERO, rot_y_deg := 0.0) -> Node3D:
	var n := Node3D.new()
	n.name = name_
	n.position = pos
	n.rotation_degrees.y = rot_y_deg
	if parent:
		parent.add_child(n)
	return n


func label3d(parent: Node, name_: String, text: String, pos: Vector3, rot_y_deg: float, size: int = 64, color := Color(0.85, 0.82, 0.72), font := "serif") -> Label3D:
	var l := Label3D.new()
	l.name = name_
	l.text = text
	l.font = fonts[font]
	l.font_size = size
	l.pixel_size = 0.0018
	l.modulate = color
	l.outline_size = 0
	l.position = pos
	l.rotation_degrees.y = rot_y_deg
	l.shaded = true
	parent.add_child(l)
	return l


func _set_owner_rec(n: Node, owner_: Node) -> void:
	for c in n.get_children():
		c.owner = owner_
		if c.scene_file_path.is_empty():
			_set_owner_rec(c, owner_)


func save_scene(root: Node, path: String) -> void:
	_set_owner_rec(root, root)
	var ps := PackedScene.new()
	var err := ps.pack(root)
	if err != OK:
		_fail("pack " + path + ": " + error_string(err))
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	err = ResourceSaver.save(ps, path)
	if err != OK:
		_fail("save " + path + ": " + error_string(err))
	else:
		print("scene ", path)
	root.free()


func inst(parent: Node, path: String, name_: String, pos: Vector3, rot_y_deg := 0.0, props := {}) -> Node3D:
	var ps := load(path) as PackedScene
	if ps == null:
		_fail("не загружается " + path)
		return null
	var n := ps.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node3D
	n.name = name_
	n.position = pos
	n.rotation_degrees.y = rot_y_deg
	for k: String in props:
		n.set(k, props[k])
	parent.add_child(n)
	return n


func _script(n: Node, path: String) -> void:
	var s := load(path) as Script
	if s == null:
		_fail("нет скрипта " + path)
		return
	n.set_script(s)


# =====================================================================
# Пропсы (мебель и детали окружения)
# =====================================================================

func _prop_root(name_: String) -> StaticBody3D:
	var sb := StaticBody3D.new()
	sb.name = name_
	return sb


func _build_props() -> void:
	var p: StaticBody3D

	# Стол обеденный 1.2 x 0.8
	p = _prop_root("Table")
	vbox(p, "Top", Vector3(0, 0.74, 0), Vector3(1.2, 0.04, 0.8), "wood_varnish")
	for i in 4:
		var sx := -1 if i % 2 == 0 else 1
		var sz := -1 if i < 2 else 1
		vbox(p, "Leg%d" % i, Vector3(sx * 0.54, 0.36, sz * 0.34), Vector3(0.05, 0.72, 0.05), "wood_varnish")
	vbox(p, "Cloth", Vector3(0, 0.765, 0), Vector3(0.9, 0.006, 0.6), "fabric_b")
	col_box(p, "Col", Vector3(0, 0.38, 0), Vector3(1.2, 0.76, 0.8))
	save_scene(p, "res://scenes/props/Table.tscn")

	# Письменный стол 1.2 x 0.6 с тумбой
	p = _prop_root("Desk")
	vbox(p, "Top", Vector3(0, 0.74, 0), Vector3(1.2, 0.04, 0.6), "wood_varnish")
	vbox(p, "Drawers", Vector3(0.38, 0.36, 0), Vector3(0.42, 0.72, 0.56), "wood_varnish")
	for i in 3:
		vbox(p, "Handle%d" % i, Vector3(0.38, 0.6 - i * 0.22, 0.285), Vector3(0.1, 0.015, 0.015), "brass")
	vbox(p, "LegL1", Vector3(-0.56, 0.36, -0.26), Vector3(0.05, 0.72, 0.05), "wood_varnish")
	vbox(p, "LegL2", Vector3(-0.56, 0.36, 0.26), Vector3(0.05, 0.72, 0.05), "wood_varnish")
	col_box(p, "Col", Vector3(0, 0.38, 0), Vector3(1.2, 0.76, 0.6))
	save_scene(p, "res://scenes/props/Desk.tscn")

	# Стул (смотрит в -Z: сиденье, спинка сзади по +Z)
	p = _prop_root("Chair")
	vbox(p, "Seat", Vector3(0, 0.45, 0), Vector3(0.44, 0.04, 0.42), "wood_varnish")
	vbox(p, "Back", Vector3(0, 0.72, 0.19), Vector3(0.44, 0.5, 0.03), "wood_varnish")
	for i in 4:
		var sx := -1 if i % 2 == 0 else 1
		var sz := -1 if i < 2 else 1
		vbox(p, "Leg%d" % i, Vector3(sx * 0.19, 0.22, sz * 0.18), Vector3(0.035, 0.45, 0.035), "wood_varnish")
	col_box(p, "Col", Vector3(0, 0.48, 0.0), Vector3(0.44, 0.96, 0.42))
	save_scene(p, "res://scenes/props/Chair.tscn")

	# Кровать 0.9 x 2.0 (длинная сторона по Z, изголовье на -Z)
	p = _prop_root("Bed")
	vbox(p, "Frame", Vector3(0, 0.2, 0), Vector3(0.9, 0.3, 2.0), "wood_varnish")
	vbox(p, "Mattress", Vector3(0, 0.42, 0.02), Vector3(0.86, 0.16, 1.94), "fabric_b")
	vbox(p, "Blanket", Vector3(0, 0.51, 0.35), Vector3(0.88, 0.04, 1.2), "fabric_a")
	vbox(p, "Pillow", Vector3(0, 0.55, -0.75), Vector3(0.6, 0.1, 0.35), "enamel")
	vbox(p, "Headboard", Vector3(0, 0.5, -1.0), Vector3(0.9, 0.9, 0.05), "wood_varnish")
	col_box(p, "Col", Vector3(0, 0.3, 0), Vector3(0.9, 0.6, 2.0))
	save_scene(p, "res://scenes/props/Bed.tscn")

	# Шкаф 1.0 x 0.6 x 2.0 (фасад на +Z)
	p = _prop_root("Wardrobe")
	vbox(p, "Body", Vector3(0, 1.0, 0), Vector3(1.0, 2.0, 0.6), "wood_varnish")
	vbox(p, "Split", Vector3(0, 1.0, 0.301), Vector3(0.01, 1.9, 0.005), "cord")
	vbox(p, "HandleL", Vector3(-0.05, 1.05, 0.31), Vector3(0.015, 0.12, 0.015), "brass")
	vbox(p, "HandleR", Vector3(0.05, 1.05, 0.31), Vector3(0.015, 0.12, 0.015), "brass")
	vbox(p, "Cornice", Vector3(0, 2.02, 0.01), Vector3(1.04, 0.04, 0.64), "wood_varnish")
	col_box(p, "Col", Vector3(0, 1.0, 0), Vector3(1.0, 2.0, 0.6))
	save_scene(p, "res://scenes/props/Wardrobe.tscn")

	# Комод 1.2 x 0.5 x 0.9 (фасад на +Z)
	p = _prop_root("Sideboard")
	vbox(p, "Body", Vector3(0, 0.45, 0), Vector3(1.2, 0.9, 0.5), "wood_varnish")
	for i in 3:
		vbox(p, "Drawer%d" % i, Vector3(0, 0.75 - i * 0.27, 0.252), Vector3(1.1, 0.22, 0.01), "wood_trim")
		vbox(p, "Handle%d" % i, Vector3(0, 0.75 - i * 0.27, 0.27), Vector3(0.14, 0.015, 0.02), "brass")
	vbox(p, "Doily", Vector3(0, 0.903, 0), Vector3(0.5, 0.004, 0.3), "enamel")
	col_box(p, "Col", Vector3(0, 0.45, 0), Vector3(1.2, 0.9, 0.5))
	save_scene(p, "res://scenes/props/Sideboard.tscn")

	# Книжный стеллаж 1.0 x 0.35 x 1.8 (открыт на +Z)
	p = _prop_root("Bookshelf")
	vbox(p, "Back", Vector3(0, 0.9, -0.165), Vector3(1.0, 1.8, 0.02), "wood_varnish")
	vbox(p, "SideL", Vector3(-0.49, 0.9, 0), Vector3(0.02, 1.8, 0.35), "wood_varnish")
	vbox(p, "SideR", Vector3(0.49, 0.9, 0), Vector3(0.02, 1.8, 0.35), "wood_varnish")
	var book_mats := ["book_red", "book_green", "book_blue", "book_brown"]
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 77
	for s in 5:
		var y := 0.02 + s * 0.44
		vbox(p, "Shelf%d" % s, Vector3(0, y, 0), Vector3(0.96, 0.02, 0.34), "wood_varnish")
		if s < 4:
			var x := -0.45
			var bi := 0
			while x < 0.42:
				var w := rnd.randf_range(0.03, 0.06)
				var h := rnd.randf_range(0.22, 0.34)
				if rnd.randf() > 0.12:
					vbox(p, "Book%d_%d" % [s, bi], Vector3(x + w / 2, y + 0.01 + h / 2, 0.02), Vector3(w, h, 0.22), book_mats[rnd.randi() % 4])
				x += w + 0.004
				bi += 1
	col_box(p, "Col", Vector3(0, 0.9, 0), Vector3(1.0, 1.8, 0.35))
	save_scene(p, "res://scenes/props/Bookshelf.tscn")

	# Кресло (смотрит в -Z)
	p = _prop_root("Armchair")
	vbox(p, "Seat", Vector3(0, 0.3, 0), Vector3(0.8, 0.3, 0.75), "fabric_a")
	vbox(p, "Back", Vector3(0, 0.65, 0.32), Vector3(0.8, 0.7, 0.15), "fabric_a")
	vbox(p, "ArmL", Vector3(-0.36, 0.52, 0), Vector3(0.12, 0.2, 0.75), "fabric_a")
	vbox(p, "ArmR", Vector3(0.36, 0.52, 0), Vector3(0.12, 0.2, 0.75), "fabric_a")
	col_box(p, "Col", Vector3(0, 0.5, 0), Vector3(0.8, 1.0, 0.8))
	save_scene(p, "res://scenes/props/Armchair.tscn")

	# Диван 1.8 x 0.8 (смотрит в -Z)
	p = _prop_root("Sofa")
	vbox(p, "Seat", Vector3(0, 0.25, 0), Vector3(1.8, 0.3, 0.8), "fabric_b")
	vbox(p, "Back", Vector3(0, 0.6, 0.34), Vector3(1.8, 0.6, 0.14), "fabric_b")
	vbox(p, "ArmL", Vector3(-0.85, 0.48, 0), Vector3(0.12, 0.2, 0.8), "fabric_b")
	vbox(p, "ArmR", Vector3(0.85, 0.48, 0), Vector3(0.12, 0.2, 0.8), "fabric_b")
	col_box(p, "Col", Vector3(0, 0.45, 0), Vector3(1.8, 0.9, 0.8))
	save_scene(p, "res://scenes/props/Sofa.tscn")

	# Холодильник
	p = _prop_root("Fridge")
	vbox(p, "Body", Vector3(0, 0.75, 0), Vector3(0.6, 1.5, 0.6), "enamel")
	vbox(p, "Gap", Vector3(0, 1.05, 0.301), Vector3(0.58, 0.01, 0.005), "cord")
	vbox(p, "Handle", Vector3(0.22, 1.25, 0.32), Vector3(0.03, 0.2, 0.03), "steel")
	col_box(p, "Col", Vector3(0, 0.75, 0), Vector3(0.6, 1.5, 0.6))
	save_scene(p, "res://scenes/props/Fridge.tscn")

	# Чугунный радиатор (плоскость XY, толщина по Z)
	p = _prop_root("Radiator")
	for i in 8:
		vbox(p, "Fin%d" % i, Vector3(-0.35 + i * 0.1, 0.42, 0), Vector3(0.07, 0.5, 0.1), "paint_grey")
	vbox(p, "PipeTop", Vector3(0, 0.66, 0), Vector3(0.82, 0.04, 0.05), "paint_grey")
	vbox(p, "PipeBot", Vector3(0, 0.18, 0), Vector3(0.82, 0.04, 0.05), "paint_grey")
	col_box(p, "Col", Vector3(0, 0.42, 0), Vector3(0.82, 0.54, 0.12))
	save_scene(p, "res://scenes/props/Radiator.tscn")

	# Деревянный ящик
	p = _prop_root("Crate")
	vbox(p, "Body", Vector3(0, 0.25, 0), Vector3(0.5, 0.5, 0.5), "door_wood")
	for i in 3:
		vbox(p, "Slat%d" % i, Vector3(0, 0.08 + i * 0.17, 0.252), Vector3(0.5, 0.05, 0.01), "wood_trim")
	col_box(p, "Col", Vector3(0, 0.25, 0), Vector3(0.5, 0.5, 0.5))
	save_scene(p, "res://scenes/props/Crate.tscn")

	# Верстак 1.4 x 0.6
	p = _prop_root("Workbench")
	vbox(p, "Top", Vector3(0, 0.84, 0), Vector3(1.4, 0.06, 0.6), "door_wood")
	vbox(p, "Frame", Vector3(0, 0.42, 0), Vector3(1.3, 0.04, 0.5), "metal_rust")
	for i in 4:
		var sx := -1 if i % 2 == 0 else 1
		var sz := -1 if i < 2 else 1
		vbox(p, "Leg%d" % i, Vector3(sx * 0.66, 0.41, sz * 0.26), Vector3(0.05, 0.82, 0.05), "metal_rust")
	vbox(p, "Vise", Vector3(0.5, 0.92, 0.2), Vector3(0.15, 0.1, 0.12), "metal_painted")
	col_box(p, "Col", Vector3(0, 0.44, 0), Vector3(1.4, 0.88, 0.6))
	save_scene(p, "res://scenes/props/Workbench.tscn")

	# Картотечный шкаф 0.5 x 0.6 x 1.3 (фасад +Z)
	p = _prop_root("FilingCabinet")
	vbox(p, "Body", Vector3(0, 0.65, 0), Vector3(0.5, 1.3, 0.6), "metal_painted")
	for i in 4:
		vbox(p, "Drawer%d" % i, Vector3(0, 1.12 - i * 0.31, 0.302), Vector3(0.46, 0.27, 0.01), "steel")
		vbox(p, "Handle%d" % i, Vector3(0, 1.12 - i * 0.31, 0.32), Vector3(0.12, 0.02, 0.02), "black_plastic")
	col_box(p, "Col", Vector3(0, 0.65, 0), Vector3(0.5, 1.3, 0.6))
	save_scene(p, "res://scenes/props/FilingCabinet.tscn")

	# Старый телевизор на тумбе (экран +Z)
	p = _prop_root("TVStand")
	vbox(p, "Stand", Vector3(0, 0.3, 0), Vector3(0.8, 0.6, 0.45), "wood_varnish")
	vbox(p, "TV", Vector3(0, 0.85, 0), Vector3(0.6, 0.5, 0.45), "black_plastic")
	vbox(p, "Screen", Vector3(-0.05, 0.86, 0.226), Vector3(0.42, 0.34, 0.005), "screen")
	col_box(p, "Col", Vector3(0, 0.55, 0), Vector3(0.8, 1.1, 0.45))
	save_scene(p, "res://scenes/props/TVStand.tscn")

	# Маленький столик под телефон 0.5 x 0.4
	p = _prop_root("SmallTable")
	vbox(p, "Top", Vector3(0, 0.7, 0), Vector3(0.5, 0.03, 0.4), "wood_varnish")
	vbox(p, "Shelf", Vector3(0, 0.25, 0), Vector3(0.46, 0.02, 0.36), "wood_varnish")
	for i in 4:
		var sx := -1 if i % 2 == 0 else 1
		var sz := -1 if i < 2 else 1
		vbox(p, "Leg%d" % i, Vector3(sx * 0.22, 0.35, sz * 0.17), Vector3(0.03, 0.7, 0.03), "wood_varnish")
	col_box(p, "Col", Vector3(0, 0.36, 0), Vector3(0.5, 0.72, 0.4))
	save_scene(p, "res://scenes/props/SmallTable.tscn")

	# Почтовые ящики на стену (фасад +Z)
	p = _prop_root("Mailboxes")
	for i in 6:
		var x := -0.45 + (i % 3) * 0.3
		var y := 1.0 + (i / 3) * 0.32
		vbox(p, "Box%d" % i, Vector3(x, y, 0), Vector3(0.28, 0.3, 0.2), "metal_painted")
		vbox(p, "Slot%d" % i, Vector3(x, y + 0.08, 0.101), Vector3(0.18, 0.02, 0.005), "cord")
	col_box(p, "Col", Vector3(0, 1.16, 0), Vector3(0.9, 0.64, 0.2))
	save_scene(p, "res://scenes/props/Mailboxes.tscn")

	# Бойлер / бак
	p = _prop_root("WaterTank")
	vcyl(p, "Tank", Vector3(0, 0.8, 0), 0.3, 0.3, 1.6, "metal_rust")
	vcyl(p, "Pipe", Vector3(0, 2.1, 0), 0.04, 0.04, 1.0, "metal_rust")
	var cs := CollisionShape3D.new()
	cs.name = "Col"
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.3
	cyl.height = 1.6
	cs.shape = cyl
	cs.position = Vector3(0, 0.8, 0)
	p.add_child(cs)
	save_scene(p, "res://scenes/props/WaterTank.tscn")

	# Ковёр (без столкновений)
	var rug := node3d(null, "Rug")
	vbox(rug, "Mesh", Vector3(0, 0.005, 0), Vector3(2.0, 0.01, 1.4), "fabric_a")
	save_scene(rug, "res://scenes/props/Rug.tscn")

	# Электрощит (фасад +Z)
	p = _prop_root("ElectricPanel")
	vbox(p, "Box", Vector3(0, 0, 0), Vector3(0.5, 0.7, 0.16), "metal_painted")
	vbox(p, "Door", Vector3(-0.05, 0, 0.082), Vector3(0.36, 0.6, 0.01), "metal_rust")
	label3d(p, "Sign", "⚡ 380 В", Vector3(0.0, 0.25, 0.09), 0, 36, Color(0.75, 0.2, 0.1), "sans")
	col_box(p, "Col", Vector3.ZERO, Vector3(0.5, 0.7, 0.16))
	save_scene(p, "res://scenes/props/ElectricPanel.tscn")

	# Окно с ночным видом и холодным «лунным» светом.
	# Плоскость XY, внутренняя сторона — +Z. Центр — центр проёма.
	var win := node3d(null, "Window")
	vquad(win, "Glass", Vector3(0, 0, -0.05), Vector2(0.96, 1.16), "window_night")
	vbox(win, "FrameTop", Vector3(0, 0.6, 0), Vector3(1.04, 0.06, 0.08), "window_frame")
	vbox(win, "FrameBot", Vector3(0, -0.6, 0.02), Vector3(1.1, 0.06, 0.2), "window_frame")
	vbox(win, "FrameL", Vector3(-0.5, 0, 0), Vector3(0.06, 1.2, 0.08), "window_frame")
	vbox(win, "FrameR", Vector3(0.5, 0, 0), Vector3(0.06, 1.2, 0.08), "window_frame")
	vbox(win, "Mullion", Vector3(0, 0, -0.02), Vector3(0.04, 1.16, 0.05), "window_frame")
	vbox(win, "Transom", Vector3(0, 0.25, -0.02), Vector3(0.96, 0.04, 0.05), "window_frame")
	var moon := OmniLight3D.new()
	moon.name = "Moonlight"
	moon.position = Vector3(0, 0.3, 0.6)
	moon.light_color = Color(0.55, 0.65, 0.9)
	moon.light_energy = 0.35
	moon.omni_range = 4.5
	moon.omni_attenuation = 1.4
	win.add_child(moon)
	save_scene(win, "res://scenes/props/Window.tscn")

	# Потолочная лампа. Корень — сам источник света (FlickerLight), чтобы
	# параметры (зона, яркость, режим) правились прямо на экземпляре.
	var lamp := OmniLight3D.new()
	lamp.name = "CeilingLamp"
	_script(lamp, "res://scripts/lighting/flicker_light.gd")
	lamp.light_color = Color(1.0, 0.8, 0.58)
	lamp.light_energy = 1.3
	lamp.omni_range = 6.0
	lamp.omni_attenuation = 1.2
	lamp.shadow_enabled = true
	lamp.shadow_bias = 0.05
	vcyl(lamp, "Cord", Vector3(0, 0.2, 0), 0.006, 0.006, 0.3, "cord")
	vcyl(lamp, "Shade", Vector3(0, 0.02, 0), 0.04, 0.2, 0.14, "lampshade")
	var bulb := vsphere(lamp, "Bulb", Vector3(0, -0.06, 0), 0.045, "bulb_warm")
	bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(lamp.get_node("Shade") as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lamp.set("emissive_mesh", NodePath("Bulb"))
	save_scene(lamp, "res://scenes/props/CeilingLamp.tscn")

	# Голая лампочка на проводе
	var bare := OmniLight3D.new()
	bare.name = "BareBulb"
	_script(bare, "res://scripts/lighting/flicker_light.gd")
	bare.light_color = Color(1.0, 0.85, 0.65)
	bare.light_energy = 1.0
	bare.omni_range = 5.0
	bare.shadow_enabled = true
	vcyl(bare, "Cord", Vector3(0, 0.3, 0), 0.006, 0.006, 0.55, "cord")
	vcyl(bare, "Socket", Vector3(0, 0.03, 0), 0.02, 0.02, 0.05, "black_plastic")
	var bb := vsphere(bare, "Bulb", Vector3(0, -0.03, 0), 0.04, "bulb_warm")
	bb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bare.set("emissive_mesh", NodePath("Bulb"))
	save_scene(bare, "res://scenes/props/BareBulb.tscn")

	# Настольная лампа: корень — свет на уровне абажура, основание ниже.
	var tl := OmniLight3D.new()
	tl.name = "TableLamp"
	_script(tl, "res://scripts/lighting/flicker_light.gd")
	tl.light_color = Color(1.0, 0.76, 0.5)
	tl.light_energy = 0.9
	tl.omni_range = 4.0
	tl.shadow_enabled = true
	tl.shadow_bias = 0.04
	vcyl(tl, "Base", Vector3(0, -0.36, 0), 0.07, 0.09, 0.03, "brass")
	vcyl(tl, "Stem", Vector3(0, -0.2, 0), 0.01, 0.01, 0.3, "brass")
	var tshade := vcyl(tl, "Shade", Vector3(0, 0.02, 0), 0.08, 0.14, 0.16, "lampshade")
	tshade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var tbulb := vsphere(tl, "Bulb", Vector3(0, -0.02, 0), 0.035, "bulb_warm")
	tbulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tl.set("emissive_mesh", NodePath("Bulb"))
	save_scene(tl, "res://scenes/props/TableLamp.tscn")


# =====================================================================
# Интерактивные объекты
# =====================================================================

func _area_root(name_: String, script: String) -> Area3D:
	var a := Area3D.new()
	a.name = name_
	_script(a, script)
	return a


func _build_interactables() -> void:
	# --- Дверь деревянная. Корень в центре проёма на уровне пола,
	# полотно в плоскости XY, петля — на левом краю (x = -ширина/2).
	for variant: Array in [["Door", "door_wood"], ["DoorGreen", "door_wood_green"]]:
		var d := _area_root(variant[0], "res://scripts/interaction/door.gd")
		col_box(d, "InteractShape", Vector3(0, 1.03, 0), Vector3(0.96, 2.06, 0.3))
		# Петля — само физическое тело: поворачиваем именно его, иначе
		# столкновение полотна остаётся в закрытом положении.
		var hinge := AnimatableBody3D.new()
		hinge.name = "Hinge"
		hinge.position = Vector3(-0.46, 0, 0)
		hinge.sync_to_physics = true
		d.add_child(hinge)
		col_box(hinge, "Col", Vector3(0.46, 1.025, 0), Vector3(0.92, 2.05, 0.05))
		var panel := node3d(hinge, "Panel", Vector3(0.46, 1.025, 0))
		vbox(panel, "Leaf", Vector3.ZERO, Vector3(0.92, 2.05, 0.045), variant[1])
		vbox(panel, "InsetUp", Vector3(0, 0.45, 0.024), Vector3(0.7, 0.8, 0.006), variant[1])
		vbox(panel, "InsetDn", Vector3(0, -0.5, 0.024), Vector3(0.7, 0.7, 0.006), variant[1])
		vbox(panel, "InsetUpB", Vector3(0, 0.45, -0.024), Vector3(0.7, 0.8, 0.006), variant[1])
		vbox(panel, "InsetDnB", Vector3(0, -0.5, -0.024), Vector3(0.7, 0.7, 0.006), variant[1])
		for side: int in [1, -1]:
			vbox(panel, "Handle%s" % ("F" if side > 0 else "B"), Vector3(0.36, -0.02, side * 0.045), Vector3(0.12, 0.02, 0.03), "brass")
			vbox(panel, "Rose%s" % ("F" if side > 0 else "B"), Vector3(0.38, -0.02, side * 0.026), Vector3(0.04, 0.16, 0.008), "brass")
		vbox(panel, "Keyhole", Vector3(0.38, -0.12, 0.027), Vector3(0.015, 0.03, 0.004), "cord")
		save_scene(d, "res://scenes/interactables/%s.tscn" % variant[0])

	# --- Решётчатая калитка (поднята на 0.2 м, чтобы не задевать ступень)
	var g := _area_root("DoorGrate", "res://scripts/interaction/door.gd")
	g.set("sound_open", "grate_open")
	g.set("sound_close", "door_locked")
	col_box(g, "InteractShape", Vector3(0, 1.2, 0), Vector3(0.95, 2.0, 0.3))
	var gh := AnimatableBody3D.new()
	gh.name = "Hinge"
	gh.position = Vector3(-0.475, 0, 0)
	gh.sync_to_physics = true
	g.add_child(gh)
	col_box(gh, "Col", Vector3(0.475, 1.2, 0), Vector3(0.93, 2.0, 0.05))
	var gp := node3d(gh, "Panel", Vector3(0.475, 1.2, 0))
	vbox(gp, "FrameT", Vector3(0, 0.98, 0), Vector3(0.93, 0.04, 0.04), "metal_rust")
	vbox(gp, "FrameB", Vector3(0, -0.98, 0), Vector3(0.93, 0.04, 0.04), "metal_rust")
	vbox(gp, "FrameM", Vector3(0, 0.0, 0), Vector3(0.93, 0.03, 0.03), "metal_rust")
	for i in 9:
		vbox(gp, "Bar%d" % i, Vector3(-0.44 + i * 0.11, 0, 0), Vector3(0.02, 2.0, 0.02), "metal_rust")
	vbox(gp, "Padlock", Vector3(0.42, 0.0, 0.05), Vector3(0.06, 0.08, 0.03), "brass")
	save_scene(g, "res://scenes/interactables/DoorGrate.tscn")

	# --- Записка (лежит в плоскости XZ)
	var note := _area_root("Note", "res://scripts/interaction/readable.gd")
	col_box(note, "Shape", Vector3(0, 0.02, 0), Vector3(0.3, 0.08, 0.36))
	var nv := node3d(note, "Visual")
	vbox(nv, "Paper", Vector3(0, 0.002, 0), Vector3(0.21, 0.003, 0.29), "paper_local")
	for i in 7:
		vbox(nv, "Line%d" % i, Vector3(-0.01 + (i % 2) * 0.01, 0.004, -0.1 + i * 0.03), Vector3(0.15 - (i % 3) * 0.02, 0.001, 0.004), "cord")
	save_scene(note, "res://scenes/interactables/Note.tscn")

	# --- Тетрадь/папка (толще)
	var book := _area_root("Notebook", "res://scripts/interaction/readable.gd")
	col_box(book, "Shape", Vector3(0, 0.03, 0), Vector3(0.3, 0.1, 0.36))
	var bv := node3d(book, "Visual")
	vbox(bv, "Cover", Vector3(0, 0.008, 0), Vector3(0.22, 0.016, 0.3), "book_green")
	vbox(bv, "Pages", Vector3(0.005, 0.01, 0), Vector3(0.21, 0.012, 0.29), "paper_local")
	save_scene(book, "res://scenes/interactables/Notebook.tscn")

	# --- Фотография в рамке (на стене; лицевая сторона +Z)
	var ph := _area_root("Photo", "res://scripts/interaction/inspectable.gd")
	col_box(ph, "Shape", Vector3(0, 0, 0.03), Vector3(0.36, 0.3, 0.1))
	var pv := node3d(ph, "Visual")
	vbox(pv, "Frame", Vector3(0, 0, 0), Vector3(0.34, 0.27, 0.02), "wood_varnish")
	vquad(pv, "Picture", Vector3(0, 0, 0.011), Vector2(0.3, 0.23), "photo_yard")
	ph.set("texture_mesh_path", NodePath("Visual/Picture"))
	save_scene(ph, "res://scenes/interactables/Photo.tscn")

	# --- Портрет на подставке (вертикальный)
	var pp := _area_root("PhotoStand", "res://scripts/interaction/inspectable.gd")
	col_box(pp, "Shape", Vector3(0, 0.13, 0), Vector3(0.24, 0.3, 0.16))
	var ppv := node3d(pp, "Visual")
	vbox(ppv, "Frame", Vector3(0, 0.13, 0), Vector3(0.2, 0.26, 0.015), "wood_varnish", Vector3(-0.15, 0, 0))
	vquad(ppv, "Picture", Vector3(0, 0.13, 0.009), Vector2(0.17, 0.22), "photo_portrait", Vector3(-0.15, 0, 0))
	vbox(ppv, "Leg", Vector3(0, 0.1, -0.05), Vector3(0.03, 0.2, 0.01), "wood_varnish", Vector3(0.4, 0, 0))
	save_scene(pp, "res://scenes/interactables/PhotoStand.tscn")

	# --- Календарь на стене
	var cal := _area_root("Calendar", "res://scripts/interaction/inspectable.gd")
	cal.set("inspect_id", "calendar")
	col_box(cal, "Shape", Vector3(0, 0, 0.03), Vector3(0.34, 0.44, 0.08))
	var cv := node3d(cal, "Visual")
	vquad(cv, "Sheet", Vector3(0, 0, 0.005), Vector2(0.3, 0.4), "calendar")
	vbox(cv, "Nail", Vector3(0, 0.21, 0.01), Vector3(0.01, 0.01, 0.02), "steel")
	save_scene(cal, "res://scenes/interactables/Calendar.tscn")

	# --- Ключ
	var key := _area_root("KeyPickup", "res://scripts/interaction/key_pickup.gd")
	col_box(key, "Shape", Vector3.ZERO, Vector3(0.18, 0.18, 0.12))
	var kv := node3d(key, "Visual")
	vcyl(kv, "Ring", Vector3(0, 0.03, 0), 0.018, 0.018, 0.006, "brass", Vector3(PI / 2, 0, 0))
	vbox(kv, "Shaft", Vector3(0, -0.025, 0), Vector3(0.008, 0.07, 0.004), "brass")
	vbox(kv, "Bit", Vector3(0.008, -0.05, 0), Vector3(0.014, 0.012, 0.004), "brass")
	vbox(kv, "Tag", Vector3(0.0, 0.065, 0), Vector3(0.03, 0.04, 0.003), "enamel")
	save_scene(key, "res://scenes/interactables/KeyPickup.tscn")

	# --- Выключатель (плоскость XY, лицом +Z)
	var sw := _area_root("LightSwitch", "res://scripts/interaction/light_switch.gd")
	col_box(sw, "Shape", Vector3(0, 0, 0.03), Vector3(0.16, 0.2, 0.1))
	vbox(sw, "Plate", Vector3.ZERO, Vector3(0.08, 0.12, 0.012), "ivory_plastic")
	vbox(sw, "Toggle", Vector3(0, 0, 0.01), Vector3(0.03, 0.05, 0.012), "ivory_plastic")
	save_scene(sw, "res://scenes/interactables/LightSwitch.tscn")

	# --- Рубильник в щите (LightSwitch с защёлкой)
	var br := _area_root("Breaker", "res://scripts/interaction/light_switch.gd")
	br.set("latch", true)
	br.set("start_on", false)
	br.set("sound", "fuse")
	br.set("prompt_key", "prompt.breaker")
	col_box(br, "Shape", Vector3(0, -0.05, 0.1), Vector3(0.3, 0.4, 0.15))
	vbox(br, "Box", Vector3.ZERO, Vector3(0.5, 0.7, 0.16), "metal_painted")
	vbox(br, "Lever", Vector3(0.0, -0.08, 0.12), Vector3(0.04, 0.22, 0.04), "black_plastic", Vector3(0.5, 0, 0))
	vbox(br, "Knob", Vector3(0.0, -0.18, 0.17), Vector3(0.1, 0.04, 0.04), "book_red")
	label3d(br, "Sign", "ЩИТ ЛЕСТНИЦЫ", Vector3(0, 0.25, 0.085), 0, 30, Color(0.85, 0.8, 0.7), "sans")
	var brc := StaticBody3D.new()
	brc.name = "Body"
	br.add_child(brc)
	col_box(brc, "Col", Vector3.ZERO, Vector3(0.5, 0.7, 0.16))
	save_scene(br, "res://scenes/interactables/Breaker.tscn")

	# --- Радиоприёмник (лицом +Z)
	var radio := _area_root("Radio", "res://scripts/interaction/event_interactable.gd")
	radio.set("event_id", "radio")
	radio.set("prompt_key", "prompt.radio")
	col_box(radio, "Shape", Vector3(0, 0.15, 0.02), Vector3(0.5, 0.34, 0.3))
	var rv := node3d(radio, "Visual")
	vbox(rv, "Case", Vector3(0, 0.14, 0), Vector3(0.45, 0.28, 0.22), "wood_varnish")
	vbox(rv, "Cloth", Vector3(-0.08, 0.15, 0.111), Vector3(0.24, 0.2, 0.004), "fabric_b")
	vbox(rv, "Dial", Vector3(0.14, 0.18, 0.111), Vector3(0.11, 0.08, 0.004), "ivory_plastic")
	vcyl(rv, "Knob1", Vector3(0.11, 0.07, 0.12), 0.018, 0.018, 0.02, "black_plastic", Vector3(PI / 2, 0, 0))
	vcyl(rv, "Knob2", Vector3(0.17, 0.07, 0.12), 0.018, 0.018, 0.02, "black_plastic", Vector3(PI / 2, 0, 0))
	save_scene(radio, "res://scenes/interactables/Radio.tscn")

	# --- Телефон (дисковый, на столе)
	var phone := _area_root("Phone", "res://scripts/interaction/event_interactable.gd")
	phone.set("prompt_key", "prompt.phone")
	col_box(phone, "Shape", Vector3(0, 0.07, 0), Vector3(0.3, 0.18, 0.28))
	var phv := node3d(phone, "Visual")
	vbox(phv, "Base", Vector3(0, 0.04, 0), Vector3(0.22, 0.08, 0.2), "black_plastic")
	vcyl(phv, "DialDisc", Vector3(0, 0.085, 0.03), 0.06, 0.06, 0.01, "ivory_plastic")
	vbox(phv, "Handset", Vector3(0, 0.11, -0.04), Vector3(0.24, 0.04, 0.05), "black_plastic")
	vbox(phv, "Lamp", Vector3(0.08, 0.06, 0.1), Vector3(0.015, 0.015, 0.005), "book_red")
	save_scene(phone, "res://scenes/interactables/Phone.tscn")

	# --- Домофон / переговорное устройство на стене (лицом +Z)
	var ic := _area_root("Intercom", "res://scripts/interaction/event_interactable.gd")
	ic.set("event_id", "intercom")
	ic.set("prompt_key", "prompt.answer")
	col_box(ic, "Shape", Vector3(0, 0, 0.04), Vector3(0.24, 0.32, 0.12))
	var icv := node3d(ic, "Visual")
	vbox(icv, "Base", Vector3.ZERO, Vector3(0.12, 0.24, 0.03), "ivory_plastic")
	vbox(icv, "Handset", Vector3(0, 0, 0.03), Vector3(0.06, 0.22, 0.04), "ivory_plastic")
	vbox(icv, "Button", Vector3(0, -0.1, 0.017), Vector3(0.02, 0.02, 0.01), "book_red")
	save_scene(ic, "res://scenes/interactables/Intercom.tscn")

	# --- Висящая телефонная трубка (кв. 13). Корень на высоте аппарата.
	var rc := _area_root("HangingReceiver", "res://scripts/interaction/event_interactable.gd")
	rc.set("event_id", "receiver")
	rc.set("prompt_key", "prompt.listen")
	col_box(rc, "Shape", Vector3(0, -0.45, 0.06), Vector3(0.3, 1.1, 0.25))
	var rcv := node3d(rc, "Visual")
	vbox(rcv, "WallUnit", Vector3.ZERO, Vector3(0.18, 0.25, 0.08), "black_plastic")
	vcyl(rcv, "Cord", Vector3(0.03, -0.42, 0.06), 0.006, 0.006, 0.8, "cord")
	vbox(rcv, "Handset", Vector3(0.03, -0.9, 0.06), Vector3(0.05, 0.22, 0.05), "black_plastic")
	save_scene(rc, "res://scenes/interactables/HangingReceiver.tscn")

	# --- Стояк отопления (вертикальная труба с зоной взаимодействия)
	var pipe := _area_root("PipeRiser", "res://scripts/interaction/event_interactable.gd")
	pipe.set("prompt_key", "prompt.listen")
	col_box(pipe, "Shape", Vector3(0, 1.3, 0), Vector3(0.3, 1.0, 0.3))
	vcyl(pipe, "Pipe", Vector3(0, H / 2, 0), 0.045, 0.045, H, "paint_grey", Vector3.ZERO, 12)
	vcyl(pipe, "Clamp1", Vector3(0, 0.6, 0), 0.055, 0.055, 0.04, "steel", Vector3.ZERO, 12)
	vcyl(pipe, "Clamp2", Vector3(0, 2.1, 0), 0.055, 0.055, 0.04, "steel", Vector3.ZERO, 12)
	var pb := StaticBody3D.new()
	pb.name = "Body"
	pipe.add_child(pb)
	var pcs := CollisionShape3D.new()
	pcs.name = "Col"
	var pcyl := CylinderShape3D.new()
	pcyl.radius = 0.05
	pcyl.height = H
	pcs.shape = pcyl
	pcs.position = Vector3(0, H / 2, 0)
	pb.add_child(pcs)
	save_scene(pipe, "res://scenes/interactables/PipeRiser.tscn")

	# --- Письменный стол с бланком (кв. 13, финальное решение). Лицом +Z.
	var wd := _area_root("WritingDesk", "res://scripts/interaction/event_interactable.gd")
	wd.set("event_id", "desk")
	wd.set("prompt_key", "prompt.write")
	col_box(wd, "Shape", Vector3(0, 0.82, 0.1), Vector3(0.7, 0.2, 0.5))
	var wdb := StaticBody3D.new()
	wdb.name = "Body"
	wd.add_child(wdb)
	col_box(wdb, "Col", Vector3(0, 0.38, 0), Vector3(1.1, 0.76, 0.6))
	vbox(wd, "Top", Vector3(0, 0.74, 0), Vector3(1.1, 0.04, 0.6), "wood_varnish")
	for i in 4:
		var sx := -1 if i % 2 == 0 else 1
		var sz := -1 if i < 2 else 1
		vbox(wd, "Leg%d" % i, Vector3(sx * 0.5, 0.36, sz * 0.26), Vector3(0.05, 0.72, 0.05), "wood_varnish")
	vbox(wd, "Form", Vector3(0, 0.762, 0.08), Vector3(0.21, 0.003, 0.29), "paper_local", Vector3(0, 0.1, 0))
	vbox(wd, "FormHeader", Vector3(0, 0.764, -0.02), Vector3(0.1, 0.001, 0.012), "cord", Vector3(0, 0.1, 0))
	vcyl(wd, "Pen", Vector3(0.18, 0.765, 0.1), 0.005, 0.005, 0.14, "black_plastic", Vector3(PI / 2, 0, 0.6))
	save_scene(wd, "res://scenes/interactables/WritingDesk.tscn")

	# --- Входная дверь подъезда (выход; не открывается — событие "exit"). Лицом +Z.
	var ex := _area_root("ExitDoor", "res://scripts/interaction/event_interactable.gd")
	ex.set("event_id", "exit")
	ex.set("prompt_key", "prompt.leave")
	col_box(ex, "Shape", Vector3(0, 1.05, 0.08), Vector3(1.1, 2.1, 0.2))
	vbox(ex, "Leaf", Vector3(0, 1.05, 0), Vector3(1.0, 2.1, 0.06), "metal_painted")
	vbox(ex, "Plate", Vector3(0.35, 1.0, 0.035), Vector3(0.08, 0.3, 0.01), "steel")
	vbox(ex, "Bar", Vector3(0.0, 1.0, 0.07), Vector3(0.7, 0.04, 0.04), "steel")
	vquad(ex, "Glass", Vector3(0, 1.7, 0.031), Vector2(0.5, 0.3), "window_night")
	save_scene(ex, "res://scenes/interactables/ExitDoor.tscn")


# =====================================================================
# Игрок, персонажи
# =====================================================================

func _build_player() -> void:
	var p := CharacterBody3D.new()
	p.name = "Player"
	_script(p, "res://scripts/player/player.gd")
	p.collision_layer = 1 << 1
	p.collision_mask = 1
	var col := CollisionShape3D.new()
	col.name = "Collider"
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.75
	col.shape = cap
	col.position = Vector3(0, 0.875, 0)
	p.add_child(col)
	var head := node3d(p, "Head", Vector3(0, 1.63, 0))
	var cam := Camera3D.new()
	cam.name = "Camera"
	cam.fov = 72.0
	cam.near = 0.04
	cam.far = 80.0
	cam.current = true
	head.add_child(cam)
	var ray := RayCast3D.new()
	ray.name = "InteractRay"
	ray.target_position = Vector3(0, 0, -2.1)
	ray.collide_with_areas = true
	ray.collide_with_bodies = true
	ray.collision_mask = 1 | (1 << 2)
	cam.add_child(ray)
	var fl := SpotLight3D.new()
	fl.name = "Flashlight"
	fl.position = Vector3(0.15, -0.12, 0.05)
	fl.light_color = Color(0.97, 0.93, 0.82)
	fl.light_energy = 2.6
	fl.spot_range = 15.0
	fl.spot_angle = 27.0
	fl.spot_angle_attenuation = 1.6
	fl.spot_attenuation = 0.9
	fl.shadow_enabled = true
	fl.shadow_bias = 0.04
	fl.light_volumetric_fog_energy = 0.5
	cam.add_child(fl)
	var hands := node3d(cam, "HandsSlot", Vector3(0, -0.25, -0.2))
	_script(hands, "res://scripts/characters/model_slot.gd")
	hands.set("model_path", "res://assets/characters/player/fp_arms.glb")
	hands.set("default_animation", "idle")
	var body := node3d(p, "BodySlot")
	_script(body, "res://scripts/characters/model_slot.gd")
	body.set("model_path", "res://assets/characters/player/player_body.glb")
	body.visible = false
	var sc := ShapeCast3D.new()
	sc.name = "CeilingCheck"
	var sph := SphereShape3D.new()
	sph.radius = 0.27
	sc.shape = sph
	sc.position = Vector3(0, 1.0, 0)
	sc.target_position = Vector3(0, 0.78, 0)
	sc.collision_mask = 1
	sc.enabled = true
	p.add_child(sc)
	save_scene(p, "res://scenes/player/Player.tscn")


func _human_placeholder(parent: Node3D, mat: String, height := 1.8) -> Node3D:
	var ph := node3d(parent, "Placeholder")
	var cap := CapsuleMesh.new()
	cap.radius = 0.2
	cap.height = height * 0.78
	cap.material = _m(mat)
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = cap
	body.position = Vector3(0, height * 0.42, 0)
	body.scale = Vector3(1.05, 1.0, 0.7)
	ph.add_child(body)
	vsphere(ph, "Head", Vector3(0, height * 0.9, 0), 0.11, mat)
	vbox(ph, "Shoulders", Vector3(0, height * 0.74, 0), Vector3(0.46, 0.1, 0.18), mat)
	vbox(ph, "ArmL", Vector3(-0.24, height * 0.52, 0), Vector3(0.08, 0.6, 0.09), mat, Vector3(0, 0, 0.05))
	vbox(ph, "ArmR", Vector3(0.24, height * 0.52, 0), Vector3(0.08, 0.6, 0.09), mat, Vector3(0, 0, -0.05))
	return ph


func _build_characters() -> void:
	var fig := node3d(null, "Figure")
	_script(fig, "res://scripts/characters/figure.gd")
	var slot := node3d(fig, "ModelSlot")
	_script(slot, "res://scripts/characters/model_slot.gd")
	slot.set("model_path", "res://assets/characters/figure/figure.glb")
	_human_placeholder(slot, "figure_dark", 1.86)
	save_scene(fig, "res://scenes/characters/Figure.tscn")

	var res := node3d(null, "Resident")
	var rslot := node3d(res, "ModelSlot")
	_script(rslot, "res://scripts/characters/model_slot.gd")
	rslot.set("model_path", "res://assets/characters/residents/resident_base.glb")
	_human_placeholder(rslot, "fabric_a", 1.72)
	save_scene(res, "res://scenes/characters/Resident.tscn")


# =====================================================================
# Уровень «Дом»
# =====================================================================

var L: Node3D           # корень уровня
var G: Node3D           # геометрия
var _wall_i := 0


## Стена вдоль оси между точками a и b (в плоскости XZ).
## openings: массив словарей {c: координата центра вдоль стены, w, y0, y1, frame: bool}
## mat_neg/mat_pos — материал сторон (сторона с меньшей / большей координатой
## поперёк стены). Материал может быть строкой или {"low", "high", "split"} — двухцветная.
func wall(a: Vector2, b: Vector2, y0: float, height: float, openings: Array, mat_neg: Variant, mat_pos: Variant, base_neg := false, base_pos := false) -> void:
	var along_x := is_equal_approx(a.y, b.y)
	var s0 := minf(a.x, b.x) if along_x else minf(a.y, b.y)
	var s1 := maxf(a.x, b.x) if along_x else maxf(a.y, b.y)
	var line := a.y if along_x else a.x
	var y1 := y0 + height
	var ops := openings.duplicate()
	ops.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return p["c"] < q["c"])
	var cursor := s0
	var pieces: Array = []   # [s_from, s_to, y_from, y_to, is_full]
	for o: Dictionary in ops:
		var oa: float = o["c"] - o["w"] / 2.0
		var ob: float = o["c"] + o["w"] / 2.0
		if oa > cursor + 0.001:
			pieces.append([cursor, oa, y0, y1, true])
		if o["y1"] < y1 - 0.001:
			pieces.append([oa, ob, o["y1"], y1, false])
		if o["y0"] > y0 + 0.001:
			pieces.append([oa, ob, y0, o["y0"], false])
		cursor = ob
		if o.get("frame", false):
			_door_frame(along_x, line, o, mat_neg, mat_pos)
	if s1 > cursor + 0.001:
		pieces.append([cursor, s1, y0, y1, true])
	for pc: Array in pieces:
		_wall_piece(along_x, line, pc[0], pc[1], pc[2], pc[3], mat_neg, mat_pos)
		if pc[4]:
			if base_neg:
				_baseboard(along_x, line, pc[0], pc[1], y0, -1)
			if base_pos:
				_baseboard(along_x, line, pc[0], pc[1], y0, 1)


func _wall_piece(along_x: bool, line: float, s_a: float, s_b: float, y_a: float, y_b: float, mat_neg: Variant, mat_pos: Variant) -> void:
	var len := s_b - s_a
	var hh := y_b - y_a
	var mid := (s_a + s_b) / 2.0
	var center := Vector3(mid, (y_a + y_b) / 2.0, line) if along_x else Vector3(line, (y_a + y_b) / 2.0, mid)
	var size := Vector3(len, hh, T) if along_x else Vector3(T, hh, len)
	_wall_i += 1
	var sb := StaticBody3D.new()
	sb.name = "Wall%03d" % _wall_i
	sb.position = center
	G.add_child(sb)
	col_box(sb, "Col", Vector3.ZERO, size)
	for side: int in [-1, 1]:
		var spec: Variant = mat_neg if side < 0 else mat_pos
		var off := Vector3(0, 0, side * T / 4.0) if along_x else Vector3(side * T / 4.0, 0, 0)
		var half := Vector3(len, hh, T / 2.0) if along_x else Vector3(T / 2.0, hh, len)
		if spec is Dictionary:
			var split: float = spec["split"]
			if y_b <= split:
				vbox(sb, "S%d" % side, off, half, spec["low"])
			elif y_a >= split:
				vbox(sb, "S%d" % side, off, half, spec["high"])
			else:
				var hl := split - y_a
				var hu := y_b - split
				var lo_c := off + Vector3(0, -hh / 2.0 + hl / 2.0, 0)
				var up_c := off + Vector3(0, hh / 2.0 - hu / 2.0, 0)
				vbox(sb, "S%dL" % side, lo_c, Vector3(half.x, hl, half.z), spec["low"])
				vbox(sb, "S%dU" % side, up_c, Vector3(half.x, hu, half.z), spec["high"])
				# Тонкая полоса-разделитель краски
				var strip := Vector3(half.x, 0.025, half.z + 0.004) if along_x else Vector3(half.x + 0.004, 0.025, half.z)
				vbox(sb, "S%dStrip" % side, off + Vector3(0, -hh / 2.0 + hl, 0), strip, "wood_trim")
		else:
			vbox(sb, "S%d" % side, off, half, str(spec))


func _baseboard(along_x: bool, line: float, s_a: float, s_b: float, y0: float, side: int) -> void:
	var len := s_b - s_a
	var mid := (s_a + s_b) / 2.0
	var d := T / 2.0 + 0.012
	var pos := Vector3(mid, y0 + 0.045, line + side * d) if along_x else Vector3(line + side * d, y0 + 0.045, mid)
	var size := Vector3(len, 0.09, 0.024) if along_x else Vector3(0.024, 0.09, len)
	vbox(G, "Base%03d_%d" % [_wall_i, side + 1], pos, size, "wood_trim")


func _door_frame(along_x: bool, line: float, o: Dictionary, _mn: Variant, _mp: Variant) -> void:
	var c: float = o["c"]
	var w: float = o["w"]
	var y0: float = o["y0"]
	var y1: float = o["y1"]
	for side: int in [-1, 1]:
		var d := T / 2.0 + 0.01
		var fw := 0.07
		for edge: int in [-1, 1]:
			var s := c + edge * (w / 2.0 + fw / 2.0)
			var pos := Vector3(s, (y0 + y1 + 0.07) / 2.0, line + side * d) if along_x else Vector3(line + side * d, (y0 + y1 + 0.07) / 2.0, s)
			var size := Vector3(fw, y1 - y0 + 0.07, 0.02) if along_x else Vector3(0.02, y1 - y0 + 0.07, fw)
			vbox(G, "Frame%03d_%d_%d" % [_wall_i, side + 1, edge + 1], pos, size, "wood_trim")
		var tpos := Vector3(c, y1 + 0.035, line + side * d) if along_x else Vector3(line + side * d, y1 + 0.035, c)
		var tsize := Vector3(w + fw * 2, 0.07, 0.02) if along_x else Vector3(0.02, 0.07, w + fw * 2)
		vbox(G, "FrameT%03d_%d" % [_wall_i, side + 1], tpos, tsize, "wood_trim")


## Пол (верх на высоте y) и потолок (низ на y_ceil) прямоугольного помещения.
func floor_ceiling(name_: String, x0: float, x1: float, z0: float, z1: float, y: float, y_ceil: float, floor_mat: String, ceil_mat := "ceiling") -> void:
	var cx := (x0 + x1) / 2.0
	var cz := (z0 + z1) / 2.0
	sbox(G, "Floor_" + name_, Vector3(cx, y - 0.1, cz), Vector3(x1 - x0, 0.2, z1 - z0), floor_mat)
	if y_ceil > 0.0:
		sbox(G, "Ceil_" + name_, Vector3(cx, y_ceil + 0.1, cz), Vector3(x1 - x0, 0.2, z1 - z0), ceil_mat)


func door_op(c: float, y0 := 0.0) -> Dictionary:
	return {"c": c, "w": DOOR_W, "y0": y0, "y1": y0 + DOOR_H, "frame": true}


func win_op(c: float, y0: float, y1: float, w := 1.0) -> Dictionary:
	return {"c": c, "w": w, "y0": y0, "y1": y1, "frame": false}


func trigger(name_: String, trig_id: String, room: String, center: Vector3, size: Vector3, hard_floor := false) -> void:
	var tr := Area3D.new()
	tr.name = name_
	_script(tr, "res://scripts/narrative/story_trigger.gd")
	tr.set("trigger_id", trig_id)
	tr.set("room_id", room)
	tr.set("hard_floor", hard_floor)
	tr.position = center
	L.get_node("Triggers").add_child(tr)
	col_box(tr, "Shape", Vector3.ZERO, size)


func marker(parent: Node, name_: String, pos: Vector3, rot_y_deg := 0.0) -> Marker3D:
	var m := Marker3D.new()
	m.name = name_
	m.position = pos
	m.rotation_degrees.y = rot_y_deg
	parent.add_child(m)
	return m


func lamp(name_: String, scene: String, pos: Vector3, zone: String, energy: float, rng: float, faulty := false, shadows := true, buzz := "") -> Node3D:
	var l := inst(L.get_node("Lights"), "res://scenes/props/%s.tscn" % scene, name_, pos)
	l.set("zone", zone)
	l.set("light_energy", energy)
	l.set("omni_range", rng)
	l.set("shadow_enabled", shadows)
	if faulty:
		l.set("mode", 1)
	if not buzz.is_empty():
		l.set("buzz_slot", buzz)
	return l


func _build_level() -> void:
	L = node3d(null, "HouseLevel")
	G = node3d(L, "Geometry")
	for n: String in ["Props", "Doors", "Interact", "Lights", "Triggers", "Checkpoints", "Spots", "Audio", "Signs"]:
		node3d(L, n)

	# ---- Окружение
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.01, 0.012, 0.018)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.36, 0.4, 0.5)
	env.ambient_light_energy = 0.17
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.fog_enabled = true
	env.fog_light_color = Color(0.05, 0.055, 0.07)
	env.fog_density = 0.035
	env.glow_enabled = true
	env.glow_intensity = 0.45
	env.glow_bloom = 0.05
	env.ssao_enabled = true
	env.ssao_radius = 0.8
	env.ssao_intensity = 1.6
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.82
	env.adjustment_contrast = 1.05
	we.environment = env
	L.add_child(we)

	var lc := Node.new()
	lc.name = "Lighting"
	_script(lc, "res://scripts/lighting/lighting_controller.gd")
	L.add_child(lc)
	var dir := Node.new()
	dir.name = "Director"
	_script(dir, "res://scripts/narrative/house_director.gd")
	L.add_child(dir)

	var corridor := {"low": "paint_green", "high": "whitewash", "split": 1.5}
	var stair := {"low": "paint_blue", "high": "whitewash", "split": 1.5}

	# ---- Полы и потолки
	floor_ceiling("Corridor", 0, 2.2, -14, 6, 0, H, "linoleum")
	floor_ceiling("Room10", -4, 0, 1, 5, 0, H, "parquet")
	floor_ceiling("AptA", -5, 0, -5, 1, 0, H, "parquet")
	floor_ceiling("AptC", -5, 0, -12, -5, 0, H, "parquet")
	floor_ceiling("AptB", 2.2, 7.2, -5, 1, 0, H, "linoleum")
	floor_ceiling("Tech", 2.2, 6.2, -12, -5, 0, H, "concrete", "concrete")
	floor_ceiling("Landing", -3, 4.2, -18.2, -14, 0, 4.4, "concrete", "whitewash")
	floor_ceiling("Platform", -3, 4.2, -20.4, -18.2, 1.4, 4.4, "concrete", "whitewash")
	floor_ceiling("Apt13", -3, 1.5, -24.4, -20.4, 1.4, 4.2, "parquet")

	# ---- Стены коридора
	wall(Vector2(0, 5), Vector2(0, 6), 0, H, [], "whitewash", corridor, false, true)
	wall(Vector2(0, 1), Vector2(0, 5), 0, H, [door_op(3)], "wallpaper_start", corridor, true, true)
	wall(Vector2(0, -5), Vector2(0, 1), 0, H, [door_op(-1)], "wallpaper_a", corridor, true, true)
	wall(Vector2(0, -12), Vector2(0, -5), 0, H, [door_op(-8)], "wallpaper_c", corridor, true, true)
	wall(Vector2(0, -14), Vector2(0, -12), 0, H, [], "whitewash", corridor, false, true)
	wall(Vector2(2.2, 1), Vector2(2.2, 6), 0, H, [], corridor, "whitewash", true, false)
	wall(Vector2(2.2, -5), Vector2(2.2, 1), 0, H, [door_op(-1)], corridor, "wallpaper_b", true, true)
	wall(Vector2(2.2, -12), Vector2(2.2, -5), 0, H, [door_op(-9)], corridor, "paint_grey", true, true)
	wall(Vector2(2.2, -14), Vector2(2.2, -12), 0, H, [], corridor, "whitewash", true, false)
	wall(Vector2(-0.1, 6), Vector2(2.3, 6), 0, H, [], corridor, "whitewash", true, false)

	# ---- Комната 10 (стартовая)
	wall(Vector2(-4, 1), Vector2(-4, 5), 0, H, [win_op(3, 0.9, 2.1)], "whitewash", "wallpaper_start", false, true)
	wall(Vector2(-4.1, 5), Vector2(0.1, 5), 0, H, [], "wallpaper_start", "whitewash", true, false)
	wall(Vector2(-4, 1), Vector2(0, 1), 0, H, [], "wallpaper_a", "wallpaper_start", true, true)
	wall(Vector2(-5.1, 1), Vector2(-4, 1), 0, H, [], "wallpaper_a", "whitewash", true, false)

	# ---- Квартира A (11)
	wall(Vector2(-5, -5), Vector2(-5, 1), 0, H, [win_op(-2, 0.9, 2.1)], "whitewash", "wallpaper_a", false, true)
	wall(Vector2(-5.1, -5), Vector2(0, -5), 0, H, [], "wallpaper_c", "wallpaper_a", true, true)

	# ---- Квартира C (14)
	wall(Vector2(-5, -12), Vector2(-5, -5), 0, H, [win_op(-8.5, 0.9, 2.1)], "whitewash", "wallpaper_c", false, true)
	wall(Vector2(-5.1, -12), Vector2(0.1, -12), 0, H, [], "whitewash", "wallpaper_c", false, true)

	# ---- Квартира B (12)
	wall(Vector2(7.2, -5), Vector2(7.2, 1), 0, H, [win_op(-2, 0.9, 2.1)], "wallpaper_b", "whitewash", true, false)
	wall(Vector2(2.1, 1), Vector2(7.3, 1), 0, H, [], "wallpaper_b", "whitewash", true, false)
	wall(Vector2(2.2, -5), Vector2(6.2, -5), 0, H, [], "paint_grey", "wallpaper_b", true, true)
	wall(Vector2(6.2, -5), Vector2(7.3, -5), 0, H, [], "whitewash", "wallpaper_b", false, true)

	# ---- Щитовая
	wall(Vector2(6.2, -12), Vector2(6.2, -5), 0, H, [], "paint_grey", "whitewash", true, false)
	wall(Vector2(2.1, -12), Vector2(6.3, -12), 0, H, [], "whitewash", "paint_grey", false, true)

	# ---- Лестничная клетка (двусветная, высота 4.4)
	wall(Vector2(-3.1, -14), Vector2(4.3, -14), 0, 4.4, [{"c": 1.1, "w": 2.2, "y0": 0.0, "y1": H, "frame": false}], stair, "whitewash", true, false)
	wall(Vector2(-3, -20.4), Vector2(-3, -14), 0, 4.4, [win_op(-16, 2.4, 3.6)], "whitewash", stair, false, true)
	wall(Vector2(4.2, -20.4), Vector2(4.2, -14), 0, 4.4, [], stair, "whitewash", true, false)
	wall(Vector2(-3.1, -20.4), Vector2(4.3, -20.4), 0, 4.4, [door_op(-1, 1.4)], "wallpaper_13", stair, false, false)
	# Стенка под площадкой (нижний ярус) и перила верхней площадки
	wall(Vector2(-3, -18.2), Vector2(2.2, -18.2), 0, 1.4, [], "whitewash", stair, false, true)
	sbox(G, "Railing", Vector3(-0.4, 1.4 + 0.5, -18.2), Vector3(5.2, 1.0, 0.08), "paint_blue")
	vbox(G, "Handrail", Vector3(-0.4, 2.42, -18.2), Vector3(5.2, 0.05, 0.1), "wood_varnish")
	# Ограждение лестничного марша со стороны нижней площадки
	sbox(G, "StairWall", Vector3(2.2, 1.2, -16.6), Vector3(0.12, 2.4, 3.2), "paint_blue")
	vbox(G, "StairHandrail", Vector3(2.2, 2.44, -16.6), Vector3(0.14, 0.05, 3.2), "wood_varnish")

	# Лестница: 8 ступеней по 0.175 м вверх, ход 0.3 м, в сторону -Z.
	# Видимые ступени без столкновений + невидимый пандус для плавного подъёма.
	var steps := node3d(G, "Stairs")
	for i in 8:
		var top := (i + 1) * 0.175
		var zc := -15.8 - i * 0.3 - 0.15
		vbox(steps, "Step%d" % i, Vector3(3.2, top / 2.0, zc), Vector3(2.0, top, 0.3), "concrete")
		vbox(steps, "Nose%d" % i, Vector3(3.2, top - 0.01, zc + 0.14), Vector3(2.0, 0.02, 0.03), "steel")
	var ramp := StaticBody3D.new()
	ramp.name = "StairRamp"
	var run := 2.4
	var rise := 1.4
	var ang := atan2(rise, run)
	var length := sqrt(run * run + rise * rise)
	var th := 0.1
	var mid := Vector3(3.2, rise / 2.0, -15.8 - run / 2.0)
	var normal := Vector3(0, cos(ang), sin(ang))
	ramp.position = mid - normal * (th / 2.0)
	ramp.rotation = Vector3(ang, 0, 0)
	steps.add_child(ramp)
	col_box(ramp, "Col", Vector3.ZERO, Vector3(2.0, th, length + 0.02))
	# Неподвижная половина решётки (рядом с калиткой)
	var gf := sbox(G, "GrateFixed", Vector3(2.68, 1.2, -15.0), Vector3(0.96, 2.0, 0.05), "metal_rust")
	(gf.get_node("Mesh") as MeshInstance3D).visible = false
	for i in 9:
		vbox(gf, "Bar%d" % i, Vector3(-0.44 + i * 0.11, 0, 0), Vector3(0.02, 2.0, 0.02), "metal_rust")
	vbox(gf, "Top", Vector3(0, 0.98, 0), Vector3(1.0, 0.04, 0.04), "metal_rust")
	vbox(gf, "Mid", Vector3(0, 0.0, 0), Vector3(1.0, 0.03, 0.03), "metal_rust")
	vbox(gf, "Bot", Vector3(0, -0.98, 0), Vector3(1.0, 0.04, 0.04), "metal_rust")
	sbox(G, "GratePost", Vector3(3.17, 1.2, -15.0), Vector3(0.05, 2.4, 0.05), "metal_rust")

	# ---- Квартира 13 (на полуэтаже, пол 1.4)
	wall(Vector2(-3, -24.4), Vector2(-3, -20.4), 1.4, H, [], "whitewash", "wallpaper_13", false, true)
	wall(Vector2(-3.1, -24.4), Vector2(1.6, -24.4), 1.4, H, [win_op(-0.75, 2.4, 3.5)], "whitewash", "wallpaper_13", false, true)
	wall(Vector2(1.5, -24.4), Vector2(1.5, -20.4), 1.4, H, [], "wallpaper_13", "whitewash", true, false)
	# Пространство под кв. 13 закрываем снизу, чтобы не было «дыры»
	sbox(G, "Under13", Vector3(-0.75, 0.6, -22.4), Vector3(4.5, 1.2, 4.0), "concrete")

	# ---- Двери
	var doors := L.get_node("Doors")
	inst(doors, "res://scenes/interactables/Door.tscn", "Door10", Vector3(0, 0, 3), -90,
		{"door_id": "door_10", "required_flag": "intercom_heard", "locked_message_key": "door.stuck_start"})
	inst(doors, "res://scenes/interactables/Door.tscn", "Door11", Vector3(0, 0, -1), -90, {"door_id": "door_11"})
	inst(doors, "res://scenes/interactables/Door.tscn", "Door14", Vector3(0, 0, -8), -90,
		{"door_id": "door_14", "start_locked": true, "key_item": "key_14", "locked_message_key": "door.locked_key"})
	inst(doors, "res://scenes/interactables/Door.tscn", "Door12", Vector3(2.2, 0, -1), -90, {"door_id": "door_12"})
	inst(doors, "res://scenes/interactables/DoorGreen.tscn", "DoorTech", Vector3(2.2, 0, -9), -90, {"door_id": "door_tech"})
	inst(doors, "res://scenes/interactables/DoorGrate.tscn", "Grate", Vector3(3.65, 0, -15.0), 0,
		{"door_id": "grate", "start_locked": true, "key_item": "key_grate", "locked_message_key": "door.grate_locked", "can_close": false})
	inst(doors, "res://scenes/interactables/DoorGreen.tscn", "Door13", Vector3(-1, 1.4, -20.4), 0,
		{"door_id": "door_13", "required_flag": "figure_seen", "locked_message_key": "door.stuck_13"})

	# ---- Таблички с номерами
	var signs := L.get_node("Signs")
	label3d(signs, "N10", "10", Vector3(0.115, 2.3, 3.0), 90)
	label3d(signs, "N11", "11", Vector3(0.115, 2.3, -1.0), 90)
	label3d(signs, "N14", "14", Vector3(0.115, 2.3, -8.0), 90)
	label3d(signs, "N12", "12", Vector3(2.085, 2.3, -1.0), -90)
	label3d(signs, "NTech", "ЩИТОВАЯ", Vector3(2.085, 2.3, -9.0), -90, 40, Color(0.75, 0.72, 0.65), "sans")
	label3d(signs, "N13", "13", Vector3(-1.0, 3.7, -20.285), 0, 80, Color(0.55, 0.5, 0.45))
	label3d(signs, "Floor", "1 этаж", Vector3(-2.885, 1.8, -15.0), 90, 46, Color(0.75, 0.75, 0.72), "sans")

	# ---- Мебель и детали
	var props := L.get_node("Props")
	# Комната 10
	inst(props, "res://scenes/props/Bed.tscn", "Bed10", Vector3(-3.5, 0, 2.2), 0)
	inst(props, "res://scenes/props/Desk.tscn", "Desk10", Vector3(-2.0, 0, 4.58), 180)
	inst(props, "res://scenes/props/Chair.tscn", "Chair10", Vector3(-2.0, 0, 4.05), 180)
	inst(props, "res://scenes/props/Wardrobe.tscn", "Wardrobe10", Vector3(-0.75, 0, 1.45), 0)
	inst(props, "res://scenes/props/Rug.tscn", "Rug10", Vector3(-2.1, 0, 2.9), 90)
	inst(props, "res://scenes/props/Window.tscn", "Window10", Vector3(-3.9, 1.5, 3), 90)
	# Квартира A
	inst(props, "res://scenes/props/Table.tscn", "TableA", Vector3(-2.6, 0, -2.0), 0)
	inst(props, "res://scenes/props/Chair.tscn", "ChairA_Normal", Vector3(-2.6, 0, -1.3), 0)
	inst(props, "res://scenes/props/Chair.tscn", "ChairA_Moved", Vector3(-4.1, 0, -4.05), 43)
	inst(props, "res://scenes/props/Sideboard.tscn", "SideboardA", Vector3(-4.7, 0, -0.1), 90)
	inst(props, "res://scenes/props/Wardrobe.tscn", "WardrobeA", Vector3(-3.6, 0, 0.6), 180)
	inst(props, "res://scenes/props/Armchair.tscn", "ArmchairA", Vector3(-1.1, 0, -4.2), -150)
	inst(props, "res://scenes/props/Rug.tscn", "RugA", Vector3(-2.6, 0, -2.2), 0)
	inst(props, "res://scenes/props/Radiator.tscn", "RadiatorA", Vector3(-4.83, 0, -2.0), 90)
	inst(props, "res://scenes/props/Window.tscn", "WindowA", Vector3(-4.9, 1.5, -2), 90)
	# Квартира B
	inst(props, "res://scenes/props/SmallTable.tscn", "PhoneTableB", Vector3(2.6, 0, -3.6), 90)
	inst(props, "res://scenes/props/Table.tscn", "TableB", Vector3(5.0, 0, -1.6), 0)
	inst(props, "res://scenes/props/Chair.tscn", "ChairB", Vector3(5.0, 0, -0.95), 10)
	inst(props, "res://scenes/props/Bed.tscn", "BedB", Vector3(6.65, 0, -0.12), 180)
	inst(props, "res://scenes/props/Fridge.tscn", "FridgeB", Vector3(2.65, 0, 0.6), 90)
	inst(props, "res://scenes/props/TVStand.tscn", "TVB", Vector3(5.0, 0, -4.65), 0)
	inst(props, "res://scenes/props/Crate.tscn", "CrateB", Vector3(3.6, 0, -4.6), 15)
	inst(props, "res://scenes/props/Window.tscn", "WindowB", Vector3(7.1, 1.5, -2), -90)
	# Квартира C
	inst(props, "res://scenes/props/Desk.tscn", "DeskC", Vector3(-3.0, 0, -11.6), 0)
	inst(props, "res://scenes/props/Chair.tscn", "ChairC", Vector3(-3.0, 0, -11.0), 0)
	inst(props, "res://scenes/props/FilingCabinet.tscn", "CabinetC", Vector3(-4.6, 0, -6.6), 90)
	inst(props, "res://scenes/props/Bookshelf.tscn", "ShelfC", Vector3(-1.2, 0, -11.72), 0)
	inst(props, "res://scenes/props/Sofa.tscn", "SofaC", Vector3(-2.3, 0, -5.55), 0)
	inst(props, "res://scenes/props/Window.tscn", "WindowC", Vector3(-4.9, 1.5, -8.5), 90)
	# Щитовая
	inst(props, "res://scenes/props/Workbench.tscn", "BenchTech", Vector3(3.8, 0, -11.55), 0)
	inst(props, "res://scenes/props/WaterTank.tscn", "TankTech", Vector3(5.6, 0, -11.4), 0)
	inst(props, "res://scenes/props/Crate.tscn", "CrateTech1", Vector3(5.7, 0, -6.0), 10)
	inst(props, "res://scenes/props/Crate.tscn", "CrateTech2", Vector3(5.65, 0.5, -6.05), -20)
	vcyl(props, "TechRiser", Vector3(5.95, H / 2, -5.3), 0.06, 0.06, H, "metal_rust")
	vcyl(props, "TechPipeH", Vector3(4.2, 2.55, -5.3), 0.05, 0.05, 3.9, "metal_rust", Vector3(0, 0, PI / 2))
	vcyl(props, "TechPipeH2", Vector3(6.0, 2.45, -8.6), 0.04, 0.04, 6.6, "metal_painted", Vector3(PI / 2, 0, 0))
	# Лестница
	inst(props, "res://scenes/props/Mailboxes.tscn", "Mailboxes", Vector3(-2.88, 0, -16.2), 90)
	inst(props, "res://scenes/props/Window.tscn", "WindowLanding", Vector3(-2.9, 3.0, -16), 90)
	# Коридор
	inst(props, "res://scenes/props/Radiator.tscn", "RadiatorCorr", Vector3(2.07, 0, 4.5), -90)
	# Кв. 13
	inst(props, "res://scenes/props/Bed.tscn", "Bed13", Vector3(-2.45, 1.4, -23.3), 0)
	inst(props, "res://scenes/props/Chair.tscn", "Chair13", Vector3(-0.3, 1.4, -23.25), 0)
	inst(props, "res://scenes/props/Wardrobe.tscn", "Wardrobe13", Vector3(0.95, 1.4, -21.3), -90)
	inst(props, "res://scenes/props/SmallTable.tscn", "Nightstand13", Vector3(-2.65, 1.4, -21.85), 0)
	inst(props, "res://scenes/props/Window.tscn", "Window13", Vector3(-0.75, 2.95, -24.3), 0)

	# ---- Свет
	lamp("Corr1", "CeilingLamp", Vector3(1.1, 2.62, 3.5), "corridor", 1.1, 6.0)
	lamp("Corr2", "CeilingLamp", Vector3(1.1, 2.62, -1.5), "corridor", 1.0, 6.0)
	lamp("Corr3", "CeilingLamp", Vector3(1.1, 2.62, -6.5), "corridor", 0.9, 5.5, true, true, "light_buzz")
	lamp("Corr4", "CeilingLamp", Vector3(1.1, 2.62, -11.0), "corridor", 0.8, 5.5)
	lamp("Lamp10", "TableLamp", Vector3(-2.35, 1.12, 4.75), "room_10", 0.9, 4.5)
	lamp("LampA", "CeilingLamp", Vector3(-2.6, 2.6, -2.0), "apt_a", 0.9, 5.5)
	lamp("LampB", "CeilingLamp", Vector3(4.7, 2.6, -2.0), "apt_b", 0.85, 5.5)
	lamp("LampC", "CeilingLamp", Vector3(-2.5, 2.6, -8.5), "apt_c", 0.95, 6.0)
	lamp("LampTech", "BareBulb", Vector3(4.2, 2.4, -8.5), "tech", 0.8, 5.0)
	lamp("LampLanding1", "BareBulb", Vector3(0.0, 3.8, -16.0), "landing", 1.1, 7.0)
	lamp("LampLanding2", "BareBulb", Vector3(1.5, 3.8, -19.3), "landing", 0.9, 6.0)
	lamp("Lamp13", "TableLamp", Vector3(-2.75, 2.5, -21.95), "apt_13", 0.55, 3.5)

	# ---- Интерактивные объекты
	var it := L.get_node("Interact")
	inst(it, "res://scenes/interactables/Intercom.tscn", "Intercom", Vector3(-0.12, 1.5, 4.35), -90)
	inst(it, "res://scenes/interactables/Note.tscn", "IntercomRules", Vector3(-0.11, 1.5, 4.7), -90,
		{"document_id": "doc_intercom_rules", "rotation_degrees": Vector3(90, -90, 0)})
	inst(it, "res://scenes/interactables/Note.tscn", "NoteShift", Vector3(-1.75, 0.765, 4.6), 170, {"document_id": "doc_shift"})
	inst(it, "res://scenes/interactables/ExitDoor.tscn", "Exit", Vector3(1.1, 0, 5.87), 180)
	# A
	inst(it, "res://scenes/interactables/Notebook.tscn", "DiaryA", Vector3(-2.35, 0.775, -2.15), 20, {"document_id": "doc_diary"})
	inst(it, "res://scenes/interactables/Radio.tscn", "Radio", Vector3(-4.68, 0.905, -0.35), 90)
	inst(it, "res://scenes/interactables/Photo.tscn", "PhotoA", Vector3(-2.3, 1.6, 0.885), 180,
		{"inspect_id": "photo_yard", "changed_flag": "a_changed", "changed_inspect_id": "photo_yard_changed",
		"changed_texture": load(TEX + "photo_yard_changed.png")})
	inst(it, "res://scenes/interactables/PipeRiser.tscn", "PipeA", Vector3(-4.82, 0, -4.82), 0, {"event_id": "pipe_a"})
	inst(it, "res://scenes/interactables/LightSwitch.tscn", "SwitchA", Vector3(-0.11, 1.25, -1.8), -90, {"zone": "apt_a", "flag": "light_a"})
	# B
	inst(it, "res://scenes/interactables/Phone.tscn", "PhoneB", Vector3(2.62, 0.715, -3.72), 90, {"event_id": "phone_b"})
	inst(it, "res://scenes/interactables/Note.tscn", "CallLogB", Vector3(2.6, 0.716, -3.45), 80, {"document_id": "doc_calllog"})
	inst(it, "res://scenes/interactables/Note.tscn", "ComplaintB", Vector3(5.2, 0.77, -1.5), -10, {"document_id": "doc_complaint"})
	inst(it, "res://scenes/interactables/KeyPickup.tscn", "Key14", Vector3(7.06, 1.45, -3.2), -90, {"item_id": "key_14"})
	vbox(props, "KeyHookB", Vector3(7.08, 1.52, -3.2), Vector3(0.03, 0.03, 0.25), "wood_varnish")
	inst(it, "res://scenes/interactables/LightSwitch.tscn", "SwitchB", Vector3(2.31, 1.25, -1.8), 90, {"zone": "apt_b", "flag": "light_b"})
	# C
	inst(it, "res://scenes/interactables/Note.tscn", "ActC", Vector3(-3.3, 0.765, -11.65), 5, {"document_id": "doc_act"})
	inst(it, "res://scenes/interactables/Note.tscn", "StatementC", Vector3(-2.75, 0.765, -11.6), -12, {"document_id": "doc_statement"})
	inst(it, "res://scenes/interactables/Notebook.tscn", "ExpertC", Vector3(-4.6, 1.305, -6.6), 90, {"document_id": "doc_expert"})
	inst(it, "res://scenes/interactables/LightSwitch.tscn", "SwitchC", Vector3(-0.11, 1.25, -7.2), -90,
		{"zone": "apt_c", "flag": "light_c", "start_on": false})
	# Щитовая
	inst(it, "res://scenes/interactables/Breaker.tscn", "Breaker", Vector3(6.02, 1.4, -8.4), -90,
		{"zone": "landing", "flag": "power_landing"})
	inst(it, "res://scenes/interactables/KeyPickup.tscn", "KeyGrate", Vector3(6.06, 1.45, -9.15), -90, {"item_id": "key_grate"})
	vbox(props, "KeyHookTech", Vector3(6.08, 1.52, -9.15), Vector3(0.03, 0.03, 0.2), "steel")
	inst(it, "res://scenes/interactables/Note.tscn", "PlumberLog", Vector3(3.5, 0.875, -11.55), 8, {"document_id": "doc_plumber"})
	# Лестница / кв. 13
	inst(it, "res://scenes/interactables/Note.tscn", "Note13", Vector3(-0.28, 2.85, -20.285), 0,
		{"document_id": "doc_note_13", "rotation_degrees": Vector3(90, 0, 0)})
	inst(it, "res://scenes/interactables/WritingDesk.tscn", "Desk13", Vector3(-0.3, 1.4, -23.95), 0)
	inst(it, "res://scenes/interactables/Calendar.tscn", "Calendar13", Vector3(1.385, 2.95, -22.6), -90)
	inst(it, "res://scenes/interactables/PhotoStand.tscn", "Portrait13", Vector3(-2.52, 2.118, -21.75), 60, {"inspect_id": "photo_portrait"})
	inst(it, "res://scenes/interactables/HangingReceiver.tscn", "Receiver13", Vector3(1.39, 3.0, -23.6), -90)

	# ---- Фигура
	inst(L, "res://scenes/characters/Figure.tscn", "Figure", Vector3(3.3, 1.4, -19.7), 0)

	# ---- Точки звука
	var spots := L.get_node("Spots")
	marker(spots, "KnockA", Vector3(-4.82, 1.4, -4.82))
	marker(spots, "TechPipe", Vector3(5.95, 1.5, -5.3))
	marker(spots, "LandingTop", Vector3(1.5, 2.6, -19.5))
	marker(spots, "Door13", Vector3(-1.0, 2.4, -20.8))

	# ---- Фоновые источники
	var au := L.get_node("Audio")
	for e: Array in [["FridgeHum", "amb_fridge", Vector3(2.65, 1.0, 0.6), -14.0, 6.0],
			["Pipes", "amb_pipes", Vector3(5.95, 2.0, -5.3), -12.0, 9.0],
			["StairWind", "amb_stairwell", Vector3(-2.5, 3.0, -16.0), -14.0, 12.0],
			["PipesA", "amb_pipes", Vector3(-4.82, 2.0, -4.82), -24.0, 5.0]]:
		var em := node3d(au, e[0], e[2])
		_script(em, "res://scripts/audio/ambient_emitter.gd")
		em.set("slot", e[1])
		em.set("volume_db", e[3])
		em.set("max_distance", e[4])

	# ---- Триггеры помещений
	trigger("Corridor", "corridor", "corridor", Vector3(1.1, 1.4, -4.0), Vector3(2.0, 2.8, 19.8))
	trigger("Room10", "room_10", "room_10", Vector3(-2.0, 1.4, 3.0), Vector3(3.8, 2.8, 3.8))
	trigger("RoomA", "room_a", "apt_a", Vector3(-2.5, 1.4, -2.0), Vector3(4.8, 2.8, 5.8))
	trigger("RoomB", "room_b", "apt_b", Vector3(4.7, 1.4, -2.0), Vector3(4.8, 2.8, 5.8))
	trigger("RoomC", "room_c", "apt_c", Vector3(-2.5, 1.4, -8.5), Vector3(4.8, 2.8, 6.8))
	trigger("RoomTech", "room_tech", "tech", Vector3(4.2, 1.4, -8.5), Vector3(3.8, 2.8, 6.8), true)
	trigger("Landing", "landing", "landing", Vector3(0.6, 1.5, -16.1), Vector3(7.0, 3.0, 4.1), true)
	trigger("Stairs", "stairs", "", Vector3(3.2, 1.6, -17.0), Vector3(1.9, 3.2, 3.6), true)
	trigger("Platform", "platform", "", Vector3(0.6, 2.8, -19.3), Vector3(7.0, 2.6, 2.1), true)
	trigger("Door13Front", "door13_front", "", Vector3(-1.0, 2.6, -19.8), Vector3(2.0, 2.2, 1.1), true)
	trigger("Room13", "room_13", "apt_13", Vector3(-0.75, 2.8, -22.4), Vector3(4.3, 2.6, 3.8))

	# ---- Контрольные точки (направление взгляда — -Z маркера)
	var cps := L.get_node("Checkpoints")
	marker(cps, "cp_start", Vector3(-2.3, 0.05, 2.6), -90)
	marker(cps, "cp_corridor", Vector3(1.1, 0.05, 2.0), 0)
	marker(cps, "cp_landing", Vector3(2.8, 0.05, -14.4), 0)
	marker(cps, "cp_hidden", Vector3(-0.9, 1.45, -21.3), 0)

	save_scene(L, "res://scenes/levels/HouseLevel.tscn")


# =====================================================================
# Фон главного меню: статичный уголок комнаты ночью
# =====================================================================

func _build_menu_backdrop() -> void:
	L = node3d(null, "MenuBackdrop")
	G = node3d(L, "Geometry")
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.01, 0.01, 0.015)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.35, 0.4, 0.5)
	env.ambient_light_energy = 0.12
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.04, 0.045, 0.06)
	env.fog_density = 0.05
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.8
	we.environment = env
	L.add_child(we)
	floor_ceiling("Room", -3, 3, -3, 2, 0, H, "parquet")
	wall(Vector2(-3, -3), Vector2(3, -3), 0, H, [win_op(0.8, 0.9, 2.1)], "whitewash", "wallpaper_a", false, true)
	wall(Vector2(-3, -3), Vector2(-3, 2), 0, H, [], "whitewash", "wallpaper_a", false, true)
	wall(Vector2(3, -3), Vector2(3, 2), 0, H, [door_op(0.5)], "wallpaper_a", "whitewash", true, false)
	inst(L, "res://scenes/props/Window.tscn", "Window", Vector3(0.8, 1.5, -2.9), 0)
	inst(L, "res://scenes/props/Table.tscn", "Table", Vector3(-1.4, 0, -1.6), 0)
	inst(L, "res://scenes/props/Chair.tscn", "Chair", Vector3(-0.5, 0, -0.9), -120)
	inst(L, "res://scenes/props/Radiator.tscn", "Radiator", Vector3(0.8, 0, -2.83), 0)
	inst(L, "res://scenes/interactables/Radio.tscn", "Radio", Vector3(-1.7, 0.77, -1.8), 20)
	inst(L, "res://scenes/interactables/Photo.tscn", "Photo", Vector3(-2.88, 1.6, -1.2), 90, {"inspect_id": "photo_yard"})
	inst(L, "res://scenes/interactables/DoorGreen.tscn", "Door", Vector3(3, 0, 0.5), -90, {"door_id": ""})
	var lamp_node := inst(L, "res://scenes/props/TableLamp.tscn", "Lamp", Vector3(-1.1, 1.13, -1.75), 0)
	lamp_node.set("light_energy", 0.8)
	lamp_node.set("zone", "menu")
	var cam := Camera3D.new()
	cam.name = "Camera"
	cam.position = Vector3(1.9, 1.45, 1.4)
	cam.rotation_degrees = Vector3(-8, 38, 0)
	cam.fov = 60
	cam.current = true
	L.add_child(cam)
	save_scene(L, "res://scenes/menus/MenuBackdrop.tscn")
