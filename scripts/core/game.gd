extends Node3D
## Игровая сцена: связывает уровень, игрока и интерфейс.
## Сюжетная логика — в режиссёре уровня (HouseDirector), здесь только связка.

@onready var player: Player = $Player
@onready var ui: CanvasLayer = $GameUI
@onready var level: Node3D = $HouseLevel

var director: Node


func _ready() -> void:
	GameState.running = true
	ui.hud.bind_player(player)
	spawn_at_checkpoint(GameState.checkpoint)
	director = level.get_node_or_null("Director")
	if director and director.has_method("setup"):
		director.setup(self)
	else:
		push_error("Game: у уровня нет режиссёра (узел Director)")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	AudioManager.stop_music(1.0)
	AudioManager.play_ambience("amb_building", 3.0)
	if GameState.checkpoint == GameState.DEFAULT_CHECKPOINT and GameState.play_time < 1.0:
		ui.hud.show_controls_hint()


func get_checkpoint_marker(id: String) -> Marker3D:
	var cps := level.get_node_or_null("Checkpoints")
	if cps == null:
		return null
	return cps.get_node_or_null(id) as Marker3D


func spawn_at_checkpoint(id: String) -> void:
	var m := get_checkpoint_marker(id)
	if m == null:
		push_warning("Game: нет контрольной точки '%s', используется стартовая" % id)
		m = get_checkpoint_marker(GameState.DEFAULT_CHECKPOINT)
	if m:
		player.teleport(m.global_transform)


## Контрольная точка + автосохранение.
func reach_checkpoint(id: String) -> void:
	if get_checkpoint_marker(id) == null:
		push_warning("Game: неизвестная контрольная точка " + id)
		return
	GameState.checkpoint = id
	if SaveManager.save_game():
		Events.notify.emit(Loc.t("notify.saved"))


func vhs_glitch(strength: float = 1.0, duration: float = 0.6) -> void:
	ui.vhs.glitch(strength, duration)
