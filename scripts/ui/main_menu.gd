extends Node
## Главное меню: статичный интерьер, тихий эмбиент, медленно «дышащий» свет.

@onready var title_label: Label = $UI/Root/Left/Title
@onready var subtitle_label: Label = $UI/Root/Left/Subtitle
@onready var b_continue: Button = $UI/Root/Left/Buttons/Continue
@onready var b_new: Button = $UI/Root/Left/Buttons/NewGame
@onready var b_settings: Button = $UI/Root/Left/Buttons/Settings
@onready var b_quit: Button = $UI/Root/Left/Buttons/Quit
@onready var message_label: Label = $UI/Root/Left/Message
@onready var hint_label: Label = $UI/Root/Hint
@onready var version_label: Label = $UI/Root/Version
@onready var settings_menu: Control = $UI/SettingsMenu
@onready var confirm: Control = $UI/Confirm
@onready var confirm_label: Label = $UI/Confirm/Box/Margin/VBox/Text
@onready var b_yes: Button = $UI/Confirm/Box/Margin/VBox/Buttons/Yes
@onready var b_no: Button = $UI/Confirm/Box/Margin/VBox/Buttons/No
@onready var lamp: Light3D = $Backdrop/Lamp


func _ready() -> void:
	get_tree().paused = false
	GameState.running = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	title_label.text = Loc.t("game.title")
	subtitle_label.text = Loc.t("game.subtitle")
	b_continue.text = Loc.t("menu.continue")
	b_new.text = Loc.t("menu.new_game")
	b_settings.text = Loc.t("menu.settings")
	b_quit.text = Loc.t("menu.quit")
	hint_label.text = Loc.t("menu.hint")
	version_label.text = "v" + str(ProjectSettings.get_setting("application/config/version", ""))
	confirm_label.text = Loc.t("menu.confirm_new")
	b_yes.text = Loc.t("menu.yes")
	b_no.text = Loc.t("menu.no")
	confirm.visible = false
	settings_menu.visible = false

	var has := SaveManager.has_save()
	b_continue.visible = has
	message_label.text = ""
	if SaveManager.last_error == "corrupt":
		message_label.text = Loc.t("menu.save_corrupt")
	elif SaveManager.last_error == "version":
		message_label.text = Loc.t("menu.save_version")

	b_continue.pressed.connect(_on_continue)
	b_new.pressed.connect(_on_new)
	b_settings.pressed.connect(func() -> void:
		_click()
		settings_menu.open())
	settings_menu.back_requested.connect(func() -> void:
		settings_menu.visible = false
		b_settings.grab_focus())
	b_quit.pressed.connect(func() -> void: get_tree().quit())
	b_yes.pressed.connect(func() -> void:
		_click()
		confirm.visible = false
		SceneRouter.new_game())
	b_no.pressed.connect(func() -> void:
		confirm.visible = false
		b_new.grab_focus())
	(b_continue if has else b_new).grab_focus.call_deferred()

	AudioManager.stop_ambience(1.0)
	AudioManager.play_music("music_menu", 3.0)
	_breathe()


func _click() -> void:
	AudioManager.play("ui_click", "SFX")


func _on_continue() -> void:
	_click()
	if not SceneRouter.continue_game():
		b_continue.visible = false
		message_label.text = Loc.t("menu.save_corrupt") if SaveManager.last_error == "corrupt" else Loc.t("menu.save_version")


func _on_new() -> void:
	_click()
	if SaveManager.has_save():
		confirm.visible = true
		b_no.grab_focus()
	else:
		SceneRouter.new_game()


## Ненавязчивое изменение освещения — медленное «дыхание» лампы.
func _breathe() -> void:
	if lamp == null:
		return
	var base := lamp.light_energy
	var tw := create_tween().set_loops()
	tw.tween_property(lamp, "light_energy", base * 0.78, 4.5).set_trans(Tween.TRANS_SINE)
	tw.tween_property(lamp, "light_energy", base, 5.5).set_trans(Tween.TRANS_SINE)


func _exit_tree() -> void:
	AudioManager.stop_music(1.0)
