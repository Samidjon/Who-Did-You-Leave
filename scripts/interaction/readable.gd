class_name Readable
extends Interactable
## Записка/документ. Текст берётся из data/story/documents.<lang>.json по document_id
## и показывается в окне просмотра. Документ-доказательство попадает в журнал.


@export var document_id: String = ""


func _interactable_ready() -> void:
	if prompt_key == "prompt.inspect":
		prompt_key = "prompt.read"


func _on_interact(_by: Node) -> void:
	AudioManager.play_at("paper", global_position, "SFX", -4.0)
	Events.request_document.emit(document_id)
