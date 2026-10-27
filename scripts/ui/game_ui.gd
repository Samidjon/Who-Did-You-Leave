extends CanvasLayer
## Корневой интерфейс игровой сцены. Управляет стеком открытых окон,
## захватом/освобождением мыши и паузой. Пока открыто любое окно,
## игрок не двигается и камера не вращается (Events.ui_mode_changed).

@onready var vhs: ColorRect = $VHS
@onready var hud: Control = $HUD
@onready var document_viewer: Control = $DocumentViewer
@onready var inspect_viewer: Control = $InspectViewer
@onready var choice_panel: Control = $ChoicePanel
@onready var journal: Control = $Journal
@onready var pause_menu: Control = $PauseMenu
@onready var settings_menu: Control = $SettingsMenu

## Окна, при которых игра ставится на паузу
@onready var _pausing: Array = [pause_menu, journal, settings_menu]

var _stack: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Events.request_document.connect(open_document)
	Events.request_inspect.connect(open_inspect)
	Events.request_choice.connect(open_choice)
	pause_menu.resume_requested.connect(func() -> void: close_panel(pause_menu))
	pause_menu.journal_requested.connect(func() -> void: open_panel(journal))
	pause_menu.settings_requested.connect(func() -> void: open_panel(settings_menu))
	pause_menu.to_menu_requested.connect(_save_and_menu)
	pause_menu.quit_requested.connect(_save_and_quit)
	journal.close_requested.connect(func() -> void: close_panel(journal))
	settings_menu.back_requested.connect(func() -> void: close_panel(settings_menu))
	_update_mode()


func is_any_open() -> bool:
	return not _stack.is_empty()


func top_panel() -> Control:
	return _stack.back() if not _stack.is_empty() else null


func open_panel(p: Control) -> void:
	if _stack.has(p):
		return
	_stack.append(p)
	p.visible = true
	if p == journal:
		journal.refresh()
	elif p == settings_menu:
		settings_menu.open()
	elif p == pause_menu:
		pause_menu.focus_first()
	_update_mode()


func close_panel(p: Control) -> void:
	if not _stack.has(p):
		return
	_stack.erase(p)
	p.visible = false
	if p == pause_menu:
		# Закрывая паузу, закрываем и вложенные окна
		for extra: Control in [journal, settings_menu]:
			if _stack.has(extra):
				_stack.erase(extra)
				extra.visible = false
	_update_mode()


func open_document(id: String) -> void:
	document_viewer.show_document(id)
	open_panel(document_viewer)


func open_inspect(visual: Node3D, title: String, desc: String) -> void:
	inspect_viewer.show_item(visual, title, desc)
	open_panel(inspect_viewer)


func open_choice(prompt: String, options: Array, callback: Callable) -> void:
	choice_panel.show_choice(prompt, options, func(id: String) -> void:
		close_panel(choice_panel)
		callback.call(id))
	open_panel(choice_panel)


func _update_mode() -> void:
	var open := not _stack.is_empty()
	var pause := false
	for p: Control in _stack:
		if _pausing.has(p):
			pause = true
	get_tree().paused = pause
	var top := top_panel()
	if not open or top == inspect_viewer:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Events.ui_mode_changed.emit(open)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		var top := top_panel()
		if top == null:
			open_panel(pause_menu)
		elif top == choice_panel:
			pass  # выбор нужно сделать
		elif top == settings_menu:
			Settings.save_settings()
			close_panel(settings_menu)
		else:
			close_panel(top)
	elif event.is_action_pressed("journal"):
		get_viewport().set_input_as_handled()
		var top := top_panel()
		if top == null:
			open_panel(journal)
		elif top == journal:
			close_panel(journal)
	elif event.is_action_pressed("interact"):
		var top := top_panel()
		# В окне осмотра мышь вращает предмет — там закрываем только клавишей E
		if top == document_viewer or (top == inspect_viewer and event is InputEventKey):
			get_viewport().set_input_as_handled()
			close_panel(top)


func _notification(what: int) -> void:
	# Потеря фокуса окна — ставим на паузу, чтобы мышь не «уезжала».
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and not is_any_open() and GameState.running:
		open_panel(pause_menu)


func _save_and_menu() -> void:
	SaveManager.save_game()
	SceneRouter.to_main_menu()


func _save_and_quit() -> void:
	SaveManager.save_game()
	get_tree().quit()
