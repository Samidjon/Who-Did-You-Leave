extends SceneTree
## Одноразовый инструмент: прописывает карту ввода в project.godot.
## Запуск: godot --headless --path . --script res://tools/setup_input.gd
## Используются физические клавиши, чтобы WASD работали и на русской раскладке.

const KEYS := {
	"move_forward": [KEY_W, KEY_UP],
	"move_back": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"run": [KEY_SHIFT],
	"crouch": [KEY_C, KEY_CTRL],
	"interact": [KEY_E],
	"flashlight": [KEY_F],
	"pause": [KEY_ESCAPE],
	"journal": [KEY_J, KEY_TAB],
}


func _init() -> void:
	for action: String in KEYS:
		var events: Array = []
		for code: int in KEYS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = code
			events.append(ev)
		if action == "interact":
			var mb := InputEventMouseButton.new()
			mb.button_index = MOUSE_BUTTON_LEFT
			events.append(mb)
		ProjectSettings.set_setting("input/" + action, {"deadzone": 0.2, "events": events})
	var err := ProjectSettings.save()
	print("input map saved: ", error_string(err))
	quit(0 if err == OK else 1)
