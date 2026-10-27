extends Node
## Сохранение прогресса в JSON (user://save_01.json).
## Запись атомарная: сначала во временный файл, затем переименование.
## Отсутствующий файл, повреждённый JSON и неизвестная версия обрабатываются
## без падения игры — меню просто не предлагает «Продолжить».

signal saved
signal save_failed(reason: String)

const SAVE_PATH := "user://save_01.json"
const TMP_PATH := "user://save_01.tmp"
const SAVE_VERSION := 1

var last_error: String = ""


func has_save() -> bool:
	return not _read_valid().is_empty()


func save_game() -> bool:
	var payload := {
		"format": "who_did_you_leave_save",
		"version": SAVE_VERSION,
		"saved_at": Time.get_datetime_string_from_system(),
		"game_version": str(ProjectSettings.get_setting("application/config/version", "0")),
		"state": GameState.to_dict(),
		"settings": Settings.to_dict(),
	}
	var f := FileAccess.open(TMP_PATH, FileAccess.WRITE)
	if f == null:
		return _fail("не удалось открыть файл: " + error_string(FileAccess.get_open_error()))
	f.store_string(JSON.stringify(payload, "\t"))
	f.close()
	var dir := DirAccess.open("user://")
	if dir == null:
		return _fail("нет доступа к user://")
	if dir.file_exists(SAVE_PATH.get_file()):
		dir.remove(SAVE_PATH.get_file())
	var err := dir.rename(TMP_PATH.get_file(), SAVE_PATH.get_file())
	if err != OK:
		return _fail("не удалось переименовать временный файл: " + error_string(err))
	last_error = ""
	saved.emit()
	return true


## Загружает сохранение в GameState. Возвращает true при успехе.
func load_game() -> bool:
	var payload := _read_valid()
	if payload.is_empty():
		return false
	GameState.from_dict(payload["state"])
	return true


func delete_save() -> void:
	var dir := DirAccess.open("user://")
	if dir and dir.file_exists(SAVE_PATH.get_file()):
		dir.remove(SAVE_PATH.get_file())


## Читает и проверяет файл. Пустой словарь — сохранения нет или оно непригодно.
func _read_valid() -> Dictionary:
	last_error = ""
	if not FileAccess.file_exists(SAVE_PATH):
		last_error = "missing"
		return {}
	var text := FileAccess.get_file_as_string(SAVE_PATH)
	var json := JSON.new()
	if json.parse(text) != OK or not (json.data is Dictionary):
		last_error = "corrupt"
		_backup_broken()
		push_warning("SaveManager: файл сохранения повреждён (строка %d: %s), создана резервная копия" % [json.get_error_line(), json.get_error_message()])
		return {}
	var payload: Dictionary = json.data
	if payload.get("format") != "who_did_you_leave_save" or not (payload.get("state") is Dictionary):
		last_error = "corrupt"
		_backup_broken()
		push_warning("SaveManager: неверная структура сохранения")
		return {}
	var version := int(payload.get("version", -1))
	if version > SAVE_VERSION or version < 1:
		last_error = "version"
		push_warning("SaveManager: неизвестная версия сохранения %d (поддерживается %d)" % [version, SAVE_VERSION])
		return {}
	payload = _migrate(payload, version)
	return payload


## Место для будущих миграций формата (v1 -> v2 и т.д.).
func _migrate(payload: Dictionary, _from_version: int) -> Dictionary:
	return payload


func _backup_broken() -> void:
	var dir := DirAccess.open("user://")
	if dir == null:
		return
	var backup := "save_01.corrupt_%d.json" % int(Time.get_unix_time_from_system())
	dir.copy(SAVE_PATH, "user://" + backup)
	dir.remove(SAVE_PATH.get_file())


func _fail(reason: String) -> bool:
	last_error = reason
	push_error("SaveManager: " + reason)
	save_failed.emit(reason)
	return false
