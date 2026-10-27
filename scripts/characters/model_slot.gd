class_name ModelSlot
extends Node3D
## Слот для модели из Blender (GLB/glTF). Если файл по model_path существует —
## он загружается и заменяет временную заглушку (дочерний узел "Placeholder").
## Если файла нет, остаётся заглушка, а в лог пишется ожидаемый путь — одно сообщение.
## Анимации ищутся в AnimationPlayer внутри модели по именам из animation_names.

@export_file("*.glb", "*.gltf", "*.tscn") var model_path: String = ""
@export var animation_names: PackedStringArray = ["idle", "walk", "turn", "reach", "startled", "talk"]
@export var default_animation: String = "idle"

var model: Node3D = null
var anim: AnimationPlayer = null


func _ready() -> void:
	if model_path.is_empty() or not ResourceLoader.exists(model_path):
		if not model_path.is_empty():
			print_verbose("ModelSlot: модель пока отсутствует, используется заглушка: ", model_path)
		return
	var scene := load(model_path) as PackedScene
	if scene == null:
		push_warning("ModelSlot: не удалось загрузить " + model_path)
		return
	model = scene.instantiate() as Node3D
	add_child(model)
	var ph := get_node_or_null("Placeholder")
	if ph:
		ph.visible = false
	anim = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	play(default_animation)


func play(anim_name: String) -> void:
	if anim and anim.has_animation(anim_name):
		anim.play(anim_name)


func has_model() -> bool:
	return model != null
