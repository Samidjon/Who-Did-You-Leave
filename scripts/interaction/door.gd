class_name Door
extends Interactable
## Дверь с тремя состояниями: закрыта, открыта, заперта.
## Корень — Area3D в проёме (зона взаимодействия). Полотно поворачивается
## вокруг узла Hinge, который стоит на краю проёма — то есть на петле,
## а не в центре полотна. Дверь открывается от игрока, чтобы не толкать его.
## Состояние сохраняется в GameState по door_id.

signal opened
signal closed
signal unlocked

enum State { CLOSED, OPEN, LOCKED }

@export var door_id: String = ""
@export var start_locked: bool = false
## id предмета-ключа (GameState.items). Пусто — ключ не нужен.
@export var key_item: String = ""
## Сюжетный флаг, без которого дверь не открывается.
@export var required_flag: String = ""
@export var locked_message_key: String = "door.locked"
@export var open_angle_deg: float = 95.0
## 0 — от игрока; 1 — всегда в сторону +Z (локально); -1 — в сторону -Z.
@export_range(-1, 1) var swing: int = 0
@export var open_time: float = 0.9
@export var sound_open: String = "door_open"
@export var sound_close: String = "door_close"
## Если false — игрок не может закрыть дверь обратно (например, решётка).
@export var can_close: bool = true

@onready var hinge: Node3D = $Hinge

var state: State = State.CLOSED
var _tween: Tween
var _open_sign: float = 1.0


func _interactable_ready() -> void:
	add_to_group("doors")
	state = State.LOCKED if (start_locked or not required_flag.is_empty()) else State.CLOSED
	var saved := GameState.get_door_state(door_id)
	if not saved.is_empty():
		if saved.get("locked", false):
			state = State.LOCKED
		elif saved.get("open", false):
			state = State.OPEN
		else:
			state = State.CLOSED
		if state == State.OPEN:
			_open_sign = float(saved.get("sign", 1.0)) if saved.has("sign") else 1.0
			hinge.rotation.y = deg_to_rad(open_angle_deg) * _open_sign


func get_prompt() -> String:
	var key := "prompt.close" if state == State.OPEN else "prompt.open"
	return Loc.t("prompt.fmt", {"action": Loc.t(key)})


func can_interact() -> bool:
	if state == State.OPEN and not can_close:
		return false
	return super.can_interact()


func is_open() -> bool:
	return state == State.OPEN


func is_locked() -> bool:
	return state == State.LOCKED


func _on_interact(by: Node) -> void:
	match state:
		State.LOCKED:
			if _try_unlock():
				open_door(by)
			else:
				AudioManager.play_at("door_locked", global_position + Vector3.UP, "SFX", -2.0)
				Events.notify.emit(Loc.t(locked_message_key))
				Events.emit_story("door_locked_try", {"door_id": door_id})
		State.CLOSED:
			open_door(by)
		State.OPEN:
			close_door()


func _try_unlock() -> bool:
	if not required_flag.is_empty() and not GameState.has_flag(required_flag):
		return false
	if not key_item.is_empty():
		if not GameState.has_item(key_item):
			return false
		AudioManager.play_at("door_unlock", global_position + Vector3.UP, "SFX")
		Events.notify.emit(Loc.t("door.unlocked_with", {"item": Loc.t("item." + key_item)}))
	state = State.CLOSED
	unlocked.emit()
	_store()
	return true


## Принудительно отпереть (сюжет).
func unlock() -> void:
	if state == State.LOCKED:
		state = State.CLOSED
		unlocked.emit()
		_store()


func lock() -> void:
	if state == State.OPEN:
		_animate_to(0.0)
	state = State.LOCKED
	_store()


func open_door(by: Node = null) -> void:
	if state == State.OPEN:
		return
	_open_sign = _choose_sign(by)
	state = State.OPEN
	_animate_to(deg_to_rad(open_angle_deg) * _open_sign)
	AudioManager.play_at(sound_open, global_position + Vector3.UP * 1.2, "SFX", -3.0)
	_store()
	opened.emit()
	Events.emit_story("door_opened", {"door_id": door_id})


func close_door() -> void:
	if state != State.OPEN:
		return
	state = State.CLOSED
	_animate_to(0.0)
	var tw := _tween
	if tw:
		tw.tween_callback(func() -> void:
			AudioManager.play_at(sound_close, global_position + Vector3.UP * 1.2, "SFX", -4.0))
	_store()
	closed.emit()


## Положительный поворот Hinge вокруг Y уводит полотно в сторону -Z (локально).
func _choose_sign(by: Node) -> float:
	if swing != 0:
		return -1.0 if swing > 0 else 1.0
	if by is Node3D:
		var local := to_local((by as Node3D).global_position)
		return 1.0 if local.z >= 0.0 else -1.0
	return 1.0


func _animate_to(angle: float) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(hinge, "rotation:y", angle, open_time)


func _store() -> void:
	if door_id.is_empty():
		return
	GameState.set_door_state(door_id, state == State.OPEN, state == State.LOCKED)
	GameState.door_states[door_id]["sign"] = _open_sign
