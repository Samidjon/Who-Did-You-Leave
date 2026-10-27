extends Control
## Журнал: список прочитанных документов и осмотренных предметов.
## Позволяет перечитать найденное. Не показывает «прогресс» и условия концовок.

@onready var title_label: Label = $Box/Margin/HBox/Left/Title
@onready var list: ItemList = $Box/Margin/HBox/Left/List
@onready var body: RichTextLabel = $Box/Margin/HBox/Body
@onready var close_button: Button = $Box/Margin/HBox/Left/Close

signal close_requested

var _ids: Array = []


func _ready() -> void:
	visible = false
	title_label.text = Loc.t("journal.title")
	close_button.text = Loc.t("journal.close")
	close_button.pressed.connect(func() -> void: close_requested.emit())
	list.item_selected.connect(_on_selected)


func refresh() -> void:
	list.clear()
	_ids.clear()
	var docs := Loc.data("story/documents")
	var insp := Loc.data("story/inspect")
	for id: String in GameState.documents_read:
		var title := ""
		if id.begins_with("inspect:"):
			var k := id.substr(8)
			if insp.has(k):
				title = str(insp[k].get("title", k))
		elif docs.has(id):
			title = str(docs[id].get("title", id))
		if title.is_empty():
			continue
		list.add_item(title)
		_ids.append(id)
	if _ids.is_empty():
		body.text = "[i]" + Loc.t("journal.empty") + "[/i]"
	else:
		list.select(_ids.size() - 1)
		_on_selected(_ids.size() - 1)
	list.grab_focus.call_deferred()


func _on_selected(index: int) -> void:
	var id: String = _ids[index]
	if id.begins_with("inspect:"):
		var d: Dictionary = Loc.data("story/inspect").get(id.substr(8), {})
		var t := str(d.get("text", ""))
		if not str(d.get("back", "")).is_empty():
			t += "\n\n[color=#a89f8a]" + Loc.t("viewer.back_side") + "[/color]\n[i]" + str(d["back"]) + "[/i]"
		body.text = "[b]" + str(d.get("title", "")) + "[/b]\n\n" + t
	else:
		var d: Dictionary = Loc.data("story/documents").get(id, {})
		body.text = "[b]" + str(d.get("title", "")) + "[/b]\n\n" + str(d.get("text", ""))
