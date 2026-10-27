class_name LightSwitch
extends Interactable
## Выключатель. Управляет зоной света через LightingController (группа
## "lighting_controller"). Если задан `flag`, состояние хранится в GameState
## и восстанавливается после загрузки.

@export var zone: String = ""
@export var flag: String = ""
@export var start_on: bool = true
@export var sound: String = "switch"
## Если true — выключатель срабатывает один раз (рубильник).
@export var latch: bool = false

var is_on: bool = true


func _interactable_ready() -> void:
	if prompt_key == "prompt.inspect":
		prompt_key = "prompt.switch"
	is_on = start_on
	if not flag.is_empty() and GameState.flags.has(flag):
		is_on = GameState.has_flag(flag)
	if latch and is_on and not start_on:
		enabled = false
	_apply.call_deferred()


func _on_interact(_by: Node) -> void:
	is_on = not is_on
	AudioManager.play_at(sound, global_position, "SFX")
	if not flag.is_empty():
		GameState.set_flag(flag, is_on)
	_apply()
	Events.emit_story("switch_toggled", {"zone": zone, "on": is_on, "flag": flag})
	if latch:
		enabled = false


func _apply() -> void:
	var lc := get_tree().get_first_node_in_group("lighting_controller")
	if lc and not zone.is_empty():
		lc.set_zone_power(zone, is_on)
