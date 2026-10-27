class_name AmbientEmitter
extends Node3D
## Точечный фоновый звук в конкретном помещении (холодильник, трубы, ветер на лестнице).
## Звучит из своей позиции в 3D, зациклен; слот берётся из AudioManager.

@export var slot: String = ""
@export var volume_db: float = -10.0
@export var max_distance: float = 12.0
@export var autoplay: bool = true

var _player: AudioStreamPlayer3D


func _ready() -> void:
	if autoplay:
		start.call_deferred()


func start() -> void:
	if is_instance_valid(_player):
		return
	_player = AudioManager.play_at(slot, global_position, "Ambience", volume_db, self, max_distance)


func stop() -> void:
	if is_instance_valid(_player):
		_player.queue_free()
	_player = null
