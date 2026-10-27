extends Control
## Меню настроек (используется и в главном меню, и в паузе).
## Строки создаются кодом, значения сразу применяются и сохраняются.

signal back_requested

@onready var rows: VBoxContainer = $Box/Margin/VBox/Scroll/Rows
@onready var title_label: Label = $Box/Margin/VBox/Title
@onready var back_button: Button = $Box/Margin/VBox/Back


func _ready() -> void:
	visible = false
	title_label.text = Loc.t("settings.title")
	back_button.text = Loc.t("settings.back")
	back_button.pressed.connect(_on_back)
	_build()


func open() -> void:
	_build()
	visible = true
	back_button.grab_focus.call_deferred()


func _on_back() -> void:
	Settings.save_settings()
	back_requested.emit()


func _build() -> void:
	for c in rows.get_children():
		c.queue_free()
	for bus_name: String in Settings.BUSES:
		_slider(Loc.t("settings." + bus_name.to_lower()), Settings.volumes.get(bus_name, 1.0), 0.0, 1.0, 0.05,
			func(v: float) -> void: Settings.set_volume(bus_name, v))
	_slider(Loc.t("settings.sensitivity"), Settings.mouse_sensitivity, 0.2, 3.0, 0.05,
		func(v: float) -> void: Settings.mouse_sensitivity = v)
	_check(Loc.t("settings.invert_y"), Settings.invert_y, func(b: bool) -> void: Settings.invert_y = b)
	_check(Loc.t("settings.subtitles"), Settings.subtitles, func(b: bool) -> void: Settings.subtitles = b)
	var note := Label.new()
	note.text = "    " + Loc.t("settings.subtitles_note")
	note.add_theme_font_size_override("font_size", 14)
	note.modulate = Color(1, 1, 1, 0.55)
	rows.add_child(note)
	_check(Loc.t("settings.head_bob"), Settings.head_bob, func(b: bool) -> void: Settings.head_bob = b)
	_option(Loc.t("settings.vhs"), [Loc.t("settings.vhs_0"), Loc.t("settings.vhs_1"), Loc.t("settings.vhs_2")],
		Settings.vhs_intensity, func(i: int) -> void:
			Settings.vhs_intensity = i
			Settings.changed.emit())
	_check(Loc.t("settings.fullscreen"), Settings.fullscreen, func(b: bool) -> void:
		Settings.fullscreen = b
		Settings.apply())


func _row(label_text: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	var l := Label.new()
	l.text = label_text
	l.custom_minimum_size = Vector2(300, 0)
	h.add_child(l)
	rows.add_child(h)
	return h


func _slider(label_text: String, value: float, mn: float, mx: float, step: float, cb: Callable) -> void:
	var h := _row(label_text)
	var s := HSlider.new()
	s.min_value = mn
	s.max_value = mx
	s.step = step
	s.value = value
	s.custom_minimum_size = Vector2(260, 24)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var val := Label.new()
	val.custom_minimum_size = Vector2(56, 0)
	val.text = "%d%%" % roundi(value / mx * 100.0) if mx <= 1.0 else "%.2f" % value
	s.value_changed.connect(func(v: float) -> void:
		cb.call(v)
		val.text = "%d%%" % roundi(v * 100.0) if mx <= 1.0 else "%.2f" % v)
	h.add_child(s)
	h.add_child(val)


func _check(label_text: String, value: bool, cb: Callable) -> void:
	var h := _row(label_text)
	var c := CheckBox.new()
	c.button_pressed = value
	c.toggled.connect(func(b: bool) -> void: cb.call(b))
	h.add_child(c)


func _option(label_text: String, items: Array, selected: int, cb: Callable) -> void:
	var h := _row(label_text)
	var o := OptionButton.new()
	for it: String in items:
		o.add_item(it)
	o.select(selected)
	o.item_selected.connect(func(i: int) -> void: cb.call(i))
	h.add_child(o)
