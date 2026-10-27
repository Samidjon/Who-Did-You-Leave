class_name EventInteractable
extends Interactable
## Сюжетный объект (домофон, радио, телефон, труба, стол, выход).
## Сам ничего не решает: отправляет событие `event_id` в шину Events,
## а режиссёр уровня (HouseDirector) решает, что произойдёт.
## Подсказку режиссёр может менять через set_prompt().

@export var event_id: String = ""


func set_prompt(key: String) -> void:
	prompt_key = key


func _on_interact(by: Node) -> void:
	Events.emit_story(event_id, {"source": self, "by": by})
