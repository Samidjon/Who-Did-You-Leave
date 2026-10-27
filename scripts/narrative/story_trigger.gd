class_name StoryTrigger
extends Area3D
## Зона-триггер. Когда игрок входит/выходит, отправляет событие в Events.
## room_id — отметка «помещение исследовано» и отслеживание присутствия игрока.
## Повторный вход не перезапускает сюжет: «одноразовость» решает режиссёр
## через GameState.mark_event(), а триггер лишь сообщает факт входа.

@export var trigger_id: String = ""
@export var room_id: String = ""
## Твёрдый пол (бетон): шаги игрока звучат иначе
@export var hard_floor: bool = false

const LAYER_TRIGGERS := 1 << 3
const LAYER_PLAYER := 1 << 1

var player_inside: bool = false


func _ready() -> void:
	collision_layer = LAYER_TRIGGERS
	collision_mask = LAYER_PLAYER
	monitoring = true
	monitorable = false
	add_to_group("story_triggers")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	player_inside = true
	if hard_floor and body.has_method("enter_hard_floor"):
		body.enter_hard_floor()
	if not room_id.is_empty() and GameState.visit_room(room_id):
		Events.emit_story("room_first_visit", {"room_id": room_id})
	Events.emit_story("enter:" + trigger_id, {"trigger": self})


func _on_body_exited(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	player_inside = false
	if hard_floor and body.has_method("exit_hard_floor"):
		body.exit_hard_floor()
	Events.emit_story("exit:" + trigger_id, {"trigger": self})
