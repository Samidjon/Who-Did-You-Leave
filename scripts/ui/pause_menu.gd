extends Control
## Экран паузы. Игровое дерево ставится на паузу (UI работает в режиме ALWAYS).

signal resume_requested
signal journal_requested
signal settings_requested
signal to_menu_requested
signal quit_requested

@onready var title_label: Label = $Center/VBox/Title
@onready var b_resume: Button = $Center/VBox/Resume
@onready var b_journal: Button = $Center/VBox/Journal
@onready var b_settings: Button = $Center/VBox/Settings
@onready var b_menu: Button = $Center/VBox/ToMenu
@onready var b_quit: Button = $Center/VBox/Quit


func _ready() -> void:
	visible = false
	title_label.text = Loc.t("pause.title")
	b_resume.text = Loc.t("pause.resume")
	b_journal.text = Loc.t("pause.journal")
	b_settings.text = Loc.t("pause.settings")
	b_menu.text = Loc.t("pause.to_menu")
	b_quit.text = Loc.t("pause.quit")
	b_resume.pressed.connect(func() -> void: resume_requested.emit())
	b_journal.pressed.connect(func() -> void: journal_requested.emit())
	b_settings.pressed.connect(func() -> void: settings_requested.emit())
	b_menu.pressed.connect(func() -> void: to_menu_requested.emit())
	b_quit.pressed.connect(func() -> void: quit_requested.emit())


func focus_first() -> void:
	b_resume.grab_focus.call_deferred()
