extends Node
## Переходы между главным меню, игрой и экраном концовки.

const MAIN_MENU := "res://scenes/menus/MainMenu.tscn"
const GAME := "res://scenes/levels/Game.tscn"
const ENDING := "res://scenes/menus/EndingScreen.tscn"

## Данные для экрана концовки
var pending_ending: Dictionary = {}

var _fade_layer: CanvasLayer
var _fade: ColorRect
var _busy := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fade_layer = CanvasLayer.new()
	_fade_layer.layer = 100
	add_child(_fade_layer)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_layer.add_child(_fade)


func new_game() -> void:
	GameState.reset()
	SaveManager.delete_save()
	_go(GAME)


func continue_game() -> bool:
	if not SaveManager.load_game():
		return false
	_go(GAME)
	return true


func to_main_menu() -> void:
	_go(MAIN_MENU)


func to_ending(ending_id: String, variant: String) -> void:
	pending_ending = {"id": ending_id, "variant": variant}
	_go(ENDING, 2.5)


func _go(path: String, fade_time: float = 0.8) -> void:
	if _busy:
		return
	_busy = true
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, fade_time)
	await tw.finished
	get_tree().paused = false
	DialogueManager.stop_all()
	GameState.running = path == GAME
	var err := get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("SceneRouter: не удалось открыть сцену %s: %s" % [path, error_string(err)])
	await get_tree().process_frame
	await get_tree().process_frame
	var tw2 := create_tween()
	tw2.tween_property(_fade, "color:a", 0.0, 0.9)
	_busy = false
