class_name Interactable
extends Area3D
## Базовый класс всех объектов, с которыми можно взаимодействовать.
## Игрок находит его лучом (RayCast3D) по слою физики «interact» (3)
## и вызывает interact(). Наследники переопределяют _on_interact()
## и при необходимости get_prompt().

signal interacted(by: Node)

const LAYER_INTERACT := 1 << 2

## Ключ строки подсказки в data/locale (prompt.*)
@export var prompt_key: String = "prompt.inspect"
@export var enabled: bool = true
## Уникальный id для сохранения (подобранные предметы и т.п.). Пусто — не сохраняется.
@export var persistent_id: String = ""
## Если true — после первого взаимодействия объект становится неактивным.
@export var one_shot: bool = false
## Минимальная пауза между взаимодействиями, чтобы удержание клавиши
## или двойное нажатие не срабатывало дважды.
@export var cooldown: float = 0.35

var _last_time: float = -100.0


func _ready() -> void:
	collision_layer = LAYER_INTERACT
	collision_mask = 0
	monitoring = false
	monitorable = true
	add_to_group("interactable")
	_interactable_ready()


## Для наследников вместо _ready().
func _interactable_ready() -> void:
	pass


func can_interact() -> bool:
	return enabled and is_visible_in_tree()


func get_prompt() -> String:
	return Loc.t("prompt.fmt", {"action": Loc.t(prompt_key)})


func interact(by: Node) -> void:
	if not can_interact():
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_time < cooldown:
		return
	_last_time = now
	_on_interact(by)
	interacted.emit(by)
	if one_shot:
		enabled = false


func _on_interact(_by: Node) -> void:
	pass


## Скрыть объект и его столкновения (подобран и т.п.)
func remove_from_world() -> void:
	enabled = false
	var target: Node = get_parent() if get_meta("remove_parent", false) else self
	if target is Node3D:
		(target as Node3D).visible = false
	set_deferred("monitorable", false)
	for c in find_children("*", "CollisionShape3D", true, false):
		(c as CollisionShape3D).set_deferred("disabled", true)
