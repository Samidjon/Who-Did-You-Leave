extends Node
## Шина событий: связывает интерактивные объекты, режиссёра уровня и интерфейс
## без прямых ссылок друг на друга.

## Сюжетное событие (взаимодействие, триггер, прочитанный документ и т.п.)
signal story_event(event_id: String, data: Dictionary)

## Запросы к интерфейсу
signal request_document(document_id: String)
signal request_inspect(visual: Node3D, title: String, description: String)
signal request_choice(prompt: String, options: Array, callback: Callable)
signal notify(text: String)

## Интерфейс открыт/закрыт (для захвата мыши и блокировки игрока)
signal ui_mode_changed(is_ui_open: bool)


func emit_story(event_id: String, data: Dictionary = {}) -> void:
	story_event.emit(event_id, data)
