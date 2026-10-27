extends Node
## Снимки экрана из разных точек уровня (для визуальной проверки).
## Запуск: godot --path . --script res://tools/screenshots.gd -- <папка>

var out_dir := "user://shots"
var args_filter: PackedStringArray = []

const VIEWS := [
	["01_start_room", Vector3(-1.2, 0.05, 2.2), 120.0, -8.0, false],
	["02_corridor", Vector3(1.1, 0.05, 4.8), 0.0, -2.0, false],
	["03_corridor_far", Vector3(1.1, 0.05, -3.0), 0.0, 0.0, false],
	["04_apt_a", Vector3(-0.8, 0.05, -1.2), 110.0, -12.0, false],
	["05_apt_a_pipe", Vector3(-2.5, 0.05, -2.6), 45.0, -5.0, false],
	["06_apt_b", Vector3(2.8, 0.05, -1.0), -110.0, -10.0, false],
	["07_apt_c", Vector3(-0.8, 0.05, -8.0), 115.0, -12.0, false],
	["08_tech", Vector3(2.8, 0.05, -9.0), -110.0, -5.0, true],
	["09_landing", Vector3(1.1, 0.05, -13.5), 10.0, 12.0, true],
	["10_stairs_figure", Vector3(3.6, 0.05, -15.3), 0.0, 14.0, false],
	["11_apt13", Vector3(-1.0, 1.45, -20.9), 180.0 + 180.0, -10.0, true],
]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	if args.size() > 1:
		args_filter = args[1].split(",")
	_run()


func _snap(name_: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(name_ + ".png"))
	print("shot ", name_)


func _run() -> void:
	await get_tree().create_timer(0.5).timeout
	get_tree().change_scene_to_file("res://scenes/menus/MainMenu.tscn")
	await get_tree().create_timer(2.5).timeout
	if args_filter.is_empty() or args_filter.has("00"):
		await _snap("00_menu")
	GameState.reset()
	get_tree().change_scene_to_file("res://scenes/levels/Game.tscn")
	await get_tree().create_timer(1.5).timeout
	var game := get_tree().current_scene
	var player: Player = game.get_node("Player")
	var level := game.get_node("HouseLevel")
	DialogueManager.stop_all()
	# Сразу открываем двери и включаем свет, чтобы было что снимать
	GameState.set_flag("intercom_heard")
	GameState.set_flag("figure_seen")
	for d in level.get_node("Doors").get_children():
		(d as Door).unlock()
		(d as Door).open_door(null)
	level.get_node("Lighting").set_zone_power("landing", true)
	level.get_node("Lighting").set_zone_power("apt_c", true)
	await get_tree().create_timer(1.5).timeout
	var only: Array = Array(args_filter)
	for v: Array in VIEWS:
		if not only.is_empty() and not only.has(str(v[0]).substr(0, 2)):
			continue
		player.teleport(Transform3D(Basis(Vector3.UP, deg_to_rad(v[2])), v[1]))
		player.head.rotation.x = deg_to_rad(v[3])
		if v[4] != player.flashlight_on:
			player.toggle_flashlight()
		if v[0] == "10_stairs_figure":
			(level.get_node("Figure") as MysteryFigure).visible = true
		await get_tree().create_timer(0.6).timeout
		await _snap(v[0])
	# Окно чтения документа
	Events.request_document.emit("doc_statement")
	await get_tree().create_timer(0.5).timeout
	await _snap("12_document")
	get_tree().quit()
