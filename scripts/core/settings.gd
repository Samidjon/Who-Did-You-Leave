extends Node
## Пользовательские настройки. Хранятся отдельно от сюжетного сохранения
## (user://settings.cfg), чтобы «Новая игра» их не сбрасывала.

signal changed

const PATH := "user://settings.cfg"
const BUSES := ["Master", "Ambience", "SFX", "Dialogue", "Music"]

## Значения по умолчанию
var mouse_sensitivity: float = 1.0      # множитель, 0.2 .. 3.0
var invert_y: bool = false
var subtitles: bool = true
var head_bob: bool = true
var vhs_intensity: int = 1              # 0 — выкл, 1 — умеренно, 2 — сильно
var fullscreen: bool = false
var volumes: Dictionary = {"Master": 0.9, "Ambience": 0.8, "SFX": 0.9, "Dialogue": 1.0, "Music": 0.6}


func _ready() -> void:
	_ensure_buses()
	load_settings()
	apply()


func _ensure_buses() -> void:
	# Резерв на случай, если default_bus_layout.tres не загрузился.
	for bus_name: String in BUSES:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")
			push_warning("Settings: создана недостающая аудиошина " + bus_name)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(PATH)
	if err != OK:
		if err != ERR_FILE_NOT_FOUND:
			push_warning("Settings: не удалось прочитать настройки (%s), используются значения по умолчанию" % error_string(err))
		return
	from_dict({
		"mouse_sensitivity": cfg.get_value("controls", "mouse_sensitivity", mouse_sensitivity),
		"invert_y": cfg.get_value("controls", "invert_y", invert_y),
		"subtitles": cfg.get_value("interface", "subtitles", subtitles),
		"head_bob": cfg.get_value("video", "head_bob", head_bob),
		"vhs_intensity": cfg.get_value("video", "vhs_intensity", vhs_intensity),
		"fullscreen": cfg.get_value("video", "fullscreen", fullscreen),
		"volumes": cfg.get_value("audio", "volumes", volumes),
	})


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("controls", "mouse_sensitivity", mouse_sensitivity)
	cfg.set_value("controls", "invert_y", invert_y)
	cfg.set_value("interface", "subtitles", subtitles)
	cfg.set_value("video", "head_bob", head_bob)
	cfg.set_value("video", "vhs_intensity", vhs_intensity)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.set_value("audio", "volumes", volumes)
	var err := cfg.save(PATH)
	if err != OK:
		push_error("Settings: не удалось сохранить настройки: " + error_string(err))


func to_dict() -> Dictionary:
	return {
		"mouse_sensitivity": mouse_sensitivity, "invert_y": invert_y, "subtitles": subtitles,
		"head_bob": head_bob, "vhs_intensity": vhs_intensity, "fullscreen": fullscreen,
		"volumes": volumes.duplicate(),
	}


func from_dict(d: Dictionary) -> void:
	mouse_sensitivity = clampf(float(d.get("mouse_sensitivity", mouse_sensitivity)), 0.2, 3.0)
	invert_y = bool(d.get("invert_y", invert_y))
	subtitles = bool(d.get("subtitles", subtitles))
	head_bob = bool(d.get("head_bob", head_bob))
	vhs_intensity = clampi(int(d.get("vhs_intensity", vhs_intensity)), 0, 2)
	fullscreen = bool(d.get("fullscreen", fullscreen))
	var v: Variant = d.get("volumes", {})
	if v is Dictionary:
		for bus_name: String in BUSES:
			if v.has(bus_name):
				volumes[bus_name] = clampf(float(v[bus_name]), 0.0, 1.0)


func set_volume(bus_name: String, linear: float) -> void:
	volumes[bus_name] = clampf(linear, 0.0, 1.0)
	_apply_volume(bus_name)
	changed.emit()


func apply() -> void:
	for bus_name: String in BUSES:
		_apply_volume(bus_name)
	if DisplayServer.get_name() != "headless":
		var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != mode:
			DisplayServer.window_set_mode(mode)
	changed.emit()


func _apply_volume(bus_name: String) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	var lin: float = volumes.get(bus_name, 1.0)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(lin, 0.0001)))
	AudioServer.set_bus_mute(idx, lin <= 0.001)
