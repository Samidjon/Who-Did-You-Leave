extends Control
## Выбор вариантов (ответ домофону, финальное объяснение, выход из дома).
## Варианты — массив словарей {id, text}. Можно щёлкать мышью или нажимать 1–4.
## Выбор нельзя «проскочить» случайным нажатием E: окно принимает ввод
## только через 0.4 с после открытия.

signal chosen(option_id: String)

@onready var prompt_label: Label = $Box/Margin/VBox/Prompt
@onready var list: VBoxContainer = $Box/Margin/VBox/Options

var _callback: Callable
var _options: Array = []
var _open_time: float = 0.0
var cancellable: bool = false


func _ready() -> void:
	visible = false


func show_choice(prompt: String, options: Array, callback: Callable) -> void:
	_callback = callback
	_options = options
	prompt_label.text = prompt
	prompt_label.visible = not prompt.is_empty()
	for c in list.get_children():
		c.queue_free()
	var i := 1
	for opt: Dictionary in options:
		var b := Button.new()
		b.text = "%d.  %s" % [i, str(opt.get("text", ""))]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_mode = Control.FOCUS_ALL
		b.pressed.connect(_pick.bind(str(opt.get("id", ""))))
		list.add_child(b)
		i += 1
	_open_time = Time.get_ticks_msec() / 1000.0
	if list.get_child_count() > 0:
		(list.get_child(0) as Button).grab_focus.call_deferred()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).physical_keycode
		if k >= KEY_1 and k <= KEY_9:
			var idx := k - KEY_1
			if idx < _options.size():
				_pick(str(_options[idx].get("id", "")))
				get_viewport().set_input_as_handled()


func _pick(id: String) -> void:
	if Time.get_ticks_msec() / 1000.0 - _open_time < 0.4:
		return
	AudioManager.play("ui_click", "SFX")
	var cb := _callback
	_callback = Callable()
	chosen.emit(id)
	if cb.is_valid():
		cb.call(id)
