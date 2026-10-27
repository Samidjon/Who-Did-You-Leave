class_name Inspectable
extends Interactable
## Предмет для осмотра с приближением. Копия узла `visual_path` показывается
## в отдельном окне, её можно вращать мышью. Тексты — data/story/inspect.<lang>.json.
## Опционально: если выставлен флаг `changed_flag`, используется альтернативная
## запись `changed_inspect_id` и текстура `changed_texture` (сюжетные изменения).

@export var inspect_id: String = ""
@export var visual_path: NodePath = ^"Visual"
@export var changed_flag: String = ""
@export var changed_inspect_id: String = ""
## Материал поверхности, у которой меняется текстура (индекс поверхности на mesh)
@export var texture_mesh_path: NodePath = ^""
@export var changed_texture: Texture2D


func _interactable_ready() -> void:
	if not changed_flag.is_empty():
		GameState.flag_changed.connect(_on_flag_changed)
		_apply_changed()


func current_id() -> String:
	if not changed_flag.is_empty() and GameState.has_flag(changed_flag) and not changed_inspect_id.is_empty():
		return changed_inspect_id
	return inspect_id


func _on_flag_changed(flag: String, _v: Variant) -> void:
	if flag == changed_flag:
		_apply_changed()


func _apply_changed() -> void:
	if changed_texture == null or texture_mesh_path.is_empty() or not GameState.has_flag(changed_flag):
		return
	var mi := get_node_or_null(texture_mesh_path) as MeshInstance3D
	if mi == null:
		push_warning("Inspectable %s: не найден mesh для смены текстуры" % name)
		return
	var mat := mi.get_active_material(0)
	if mat is StandardMaterial3D:
		var m2 := (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
		m2.albedo_texture = changed_texture
		mi.set_surface_override_material(0, m2)


func _on_interact(_by: Node) -> void:
	var id := current_id()
	var data: Dictionary = Loc.data("story/inspect").get(id, {})
	var visual := get_node_or_null(visual_path) as Node3D
	var desc := str(data.get("text", ""))
	var back := str(data.get("back", ""))
	if not back.is_empty():
		desc += "\n\n[color=#a89f8a]" + Loc.t("viewer.back_side") + "[/color]\n[i]" + back + "[/i]"
	Events.request_inspect.emit(visual, str(data.get("title", "")), desc)
	var ev := str(data.get("evidence", ""))
	if not ev.is_empty() and GameState.add_evidence(ev):
		pass
	if data.get("reveals_name", false):
		GameState.set_flag("knows_name")
	GameState.mark_document_read("inspect:" + id)
	Events.emit_story("inspected", {"inspect_id": id})
