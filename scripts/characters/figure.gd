class_name MysteryFigure
extends Node3D
## Загадочная фигура. Никакого ИИ: режиссёр ставит её в точку и вызывает appear().
## Она исчезает, когда игрок наводит на неё включённый фонарь, подходит
## слишком близко или просто долго смотрит — это постановочное событие.

signal vanished

@export var vanish_distance: float = 3.2
@export var flashlight_dot: float = 0.965
@export var stare_time: float = 4.5
@export var max_time: float = 25.0

var active: bool = false
var _stare: float = 0.0
var _alive: float = 0.0

@onready var slot: ModelSlot = $ModelSlot


func _ready() -> void:
	visible = false
	set_process(false)


func appear() -> void:
	visible = true
	active = true
	_stare = 0.0
	_alive = 0.0
	set_process(true)
	slot.play("idle")


func vanish() -> void:
	if not active:
		return
	active = false
	set_process(false)
	AudioManager.play_at("figure_presence", global_position + Vector3.UP * 1.5, "SFX", -2.0)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3(0.96, 1.04, 0.96), 0.08)
	tw.tween_callback(_hide_now)
	vanished.emit()


func _hide_now() -> void:
	visible = false
	scale = Vector3.ONE


func _process(delta: float) -> void:
	if not active:
		return
	_alive += delta
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null:
		return
	var cam := player.camera
	var head_pos := global_position + Vector3.UP * 1.5
	var to_fig := head_pos - cam.global_position
	var dist := to_fig.length()
	var facing := (-cam.global_transform.basis.z).dot(to_fig.normalized())
	if dist < vanish_distance:
		vanish()
	elif player.flashlight_on and facing > flashlight_dot and dist < 14.0:
		vanish()
	else:
		if facing > 0.9:
			_stare += delta
		if _stare > stare_time or _alive > max_time:
			vanish()
