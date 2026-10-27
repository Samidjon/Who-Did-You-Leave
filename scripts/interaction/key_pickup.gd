class_name KeyPickup
extends Interactable
## Подбираемый предмет (ключ). Пишет предмет в GameState.items и исчезает.
## После загрузки сохранения уже подобранный предмет не появляется снова.

@export var item_id: String = ""


func _interactable_ready() -> void:
	if prompt_key == "prompt.inspect":
		prompt_key = "prompt.take"
	if persistent_id.is_empty():
		persistent_id = "pickup_" + item_id
	if GameState.is_picked(persistent_id) or GameState.has_item(item_id):
		remove_from_world()


func _on_interact(_by: Node) -> void:
	GameState.add_item(item_id)
	GameState.mark_picked(persistent_id)
	AudioManager.play_at("key_pickup", global_position, "SFX")
	Events.notify.emit(Loc.t("notify.picked", {"item": Loc.t("item." + item_id)}))
	Events.emit_story("item_picked", {"item_id": item_id})
	remove_from_world()
