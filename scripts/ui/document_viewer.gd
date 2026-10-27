extends Control
## Окно чтения документа. Отмечает документ прочитанным, добавляет
## доказательство (если документ — доказательство) и сообщает, что игрок
## узнал имя (флаг knows_name — радио начнёт называть его).

signal closed

const FONTS := {
	"hand": preload("res://assets/fonts/DejaVuSerif.ttf"),
	"print": preload("res://assets/fonts/DejaVuSansMono.ttf"),
	"form": preload("res://assets/fonts/DejaVuSansMono.ttf"),
}

@onready var title_label: Label = $Paper/Margin/VBox/Title
@onready var body: RichTextLabel = $Paper/Margin/VBox/Body
@onready var hint: Label = $Hint

var document_id: String = ""


func _ready() -> void:
	visible = false
	hint.text = Loc.t("viewer.close")


func show_document(id: String) -> void:
	var docs := Loc.data("story/documents")
	if not docs.has(id):
		push_warning("DocumentViewer: нет документа '%s'" % id)
		return
	var d: Dictionary = docs[id]
	document_id = id
	title_label.text = str(d.get("title", ""))
	var style := str(d.get("style", "hand"))
	var font: Font = FONTS.get(style, FONTS["hand"])
	body.add_theme_font_override("normal_font", font)
	body.add_theme_font_size_override("normal_font_size", 21 if style == "hand" else 19)
	body.text = str(d.get("text", ""))
	body.scroll_to_line(0)
	var ev := str(d.get("evidence", ""))
	if not ev.is_empty() and GameState.add_evidence(ev):
		Events.notify.emit(Loc.t("notify.evidence"))
	if d.get("reveals_name", false):
		GameState.set_flag("knows_name")
	# mark_document_read — после выдачи доказательства, чтобы режиссёр видел и то, и другое
	GameState.mark_document_read(id)
