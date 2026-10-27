extends Control
## Экран концовки. Текст и варианты — data/endings/endings.<lang>.json.

@onready var title_label: Label = $Center/VBox/Title
@onready var body: RichTextLabel = $Center/VBox/Body
@onready var back_button: Button = $Center/VBox/Back


func _ready() -> void:
	get_tree().paused = false
	GameState.running = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	AudioManager.stop_ambience(2.0)
	back_button.text = Loc.t("ending.back")
	back_button.pressed.connect(func() -> void: SceneRouter.to_main_menu())
	var info: Dictionary = SceneRouter.pending_ending
	var all: Dictionary = Loc.data("endings/endings").get("endings", {})
	var e: Dictionary = all.get(str(info.get("id", "")), {})
	if e.is_empty():
		push_warning("EndingScreen: неизвестная концовка %s" % str(info))
		title_label.text = "…"
		body.text = ""
	else:
		title_label.text = str(e.get("title", ""))
		var text := str(e.get("text", ""))
		var variant := str(e.get("variants", {}).get(str(info.get("variant", "")), ""))
		if not variant.is_empty():
			text += "\n\n[i]" + variant + "[/i]"
		body.text = "[center]" + text + "[/center]"
	title_label.modulate.a = 0.0
	body.modulate.a = 0.0
	back_button.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(title_label, "modulate:a", 1.0, 2.0).set_delay(0.8)
	tw.tween_property(body, "modulate:a", 1.0, 3.0)
	tw.tween_property(back_button, "modulate:a", 1.0, 1.0).set_delay(1.5)
	tw.tween_callback(back_button.grab_focus)
	AudioManager.play("sting_low", "Music", -8.0)
