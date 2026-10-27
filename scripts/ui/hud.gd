extends Control
## Минималистичный HUD: точка прицела, подсказка взаимодействия,
## субтитры, короткие уведомления и подсказка управления в начале.

@onready var crosshair: ColorRect = $Crosshair
@onready var prompt_label: Label = $Prompt
@onready var subtitle_panel: PanelContainer = $SubtitlePanel
@onready var subtitle_label: RichTextLabel = $SubtitlePanel/Subtitle
@onready var notify_label: Label = $Notify
@onready var controls_hint: Label = $ControlsHint

var _player: Player
var _notify_tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt_label.text = ""
	subtitle_panel.visible = false
	notify_label.modulate.a = 0.0
	DialogueManager.line_started.connect(_on_line_started)
	DialogueManager.line_cleared.connect(_on_line_cleared)
	Events.notify.connect(show_notification)


func bind_player(p: Player) -> void:
	_player = p


func show_controls_hint() -> void:
	controls_hint.text = Loc.t("hud.controls")
	controls_hint.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(controls_hint, "modulate:a", 0.85, 1.5).set_delay(2.0)
	tw.tween_interval(9.0)
	tw.tween_property(controls_hint, "modulate:a", 0.0, 2.0)


func _process(_delta: float) -> void:
	var t: Interactable = _player.current_target if _player and _player.input_enabled else null
	if t and t.can_interact():
		prompt_label.text = t.get_prompt()
		crosshair.modulate.a = 0.9
	else:
		prompt_label.text = ""
		crosshair.modulate.a = 0.28
	crosshair.visible = _player != null and _player.input_enabled


func _on_line_started(speaker: String, text: String, forced: bool) -> void:
	if not Settings.subtitles and not forced:
		return
	var s := ""
	if not speaker.is_empty():
		s = "[color=#c9b98f]%s:[/color] " % speaker
	subtitle_label.text = "[center]" + s + text + "[/center]"
	subtitle_panel.visible = true


func _on_line_cleared() -> void:
	subtitle_panel.visible = false


func show_notification(text: String) -> void:
	if text.is_empty():
		return
	notify_label.text = text
	if _notify_tween and _notify_tween.is_valid():
		_notify_tween.kill()
	_notify_tween = create_tween()
	notify_label.modulate.a = 0.0
	_notify_tween.tween_property(notify_label, "modulate:a", 1.0, 0.25)
	_notify_tween.tween_interval(2.6)
	_notify_tween.tween_property(notify_label, "modulate:a", 0.0, 1.0)
