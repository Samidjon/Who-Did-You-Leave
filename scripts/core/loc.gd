extends Node
## Локализация. Все строки интерфейса лежат в data/locale/<lang>.json,
## сюжетные данные — в data/<group>/<name>.<lang>.json.
## Если строки нет в выбранном языке, берётся русский вариант (базовый).

signal language_changed(lang: String)

const BASE_LANG := "ru"
const UI_PATH := "res://data/locale/%s.json"

var lang: String = BASE_LANG
var _ui: Dictionary = {}
var _ui_base: Dictionary = {}
var _data_cache: Dictionary = {}


func _ready() -> void:
	_ui_base = _read_json(UI_PATH % BASE_LANG)
	_ui = _ui_base


func set_language(new_lang: String) -> void:
	lang = new_lang
	_ui = _read_json(UI_PATH % lang) if lang != BASE_LANG else _ui_base
	_data_cache.clear()
	language_changed.emit(lang)


## Строка интерфейса по ключу. args подставляются в {name}.
func t(key: String, args: Dictionary = {}) -> String:
	var s: String = str(_ui.get(key, _ui_base.get(key, key)))
	return s.format(args) if not args.is_empty() else s


## Сюжетные данные: data("story/documents") -> содержимое documents.<lang>.json
func data(rel: String) -> Dictionary:
	var cache_key := lang + ":" + rel
	if _data_cache.has(cache_key):
		return _data_cache[cache_key]
	var path := "res://data/%s.%s.json" % [rel, lang]
	if not FileAccess.file_exists(path):
		path = "res://data/%s.%s.json" % [rel, BASE_LANG]
	var d := _read_json(path)
	_data_cache[cache_key] = d
	return d


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("Loc: файл не найден: " + path)
		return {}
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	push_error("Loc: повреждённый JSON: " + path)
	return {}
