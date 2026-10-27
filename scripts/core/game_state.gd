extends Node
## Централизованное состояние прохождения.
## Хранит только данные (строки, числа, словари) — никаких ссылок на узлы,
## поэтому его можно целиком сериализовать в JSON и восстановить.

signal flag_changed(flag: String, value: Variant)
signal evidence_added(evidence_id: String)
signal item_added(item_id: String)
signal document_read(document_id: String)
signal state_reset

const DEFAULT_CHECKPOINT := "cp_start"

var flags: Dictionary = {}             # произвольные сюжетные флаги
var evidence: Array = []               # найденные доказательства (id)
var items: Array = []                  # ключи и сюжетные предметы
var picked: Array = []                 # persistent_id подобранных объектов сцены
var visited_rooms: Array = []          # исследованные помещения
var events_done: Array = []            # отыгранные сюжетные события
var reactions: Dictionary = {}         # event_id -> "responded" | "ignored"
var messages_seen: Array = []          # просмотренные сообщения/диалоги
var documents_read: Array = []         # прочитанные документы
var door_states: Dictionary = {}       # door_id -> {"open": bool, "locked": bool}
var choices: Dictionary = {}           # choice_id -> option_id
var checkpoint: String = DEFAULT_CHECKPOINT
var final_choice: String = ""
var play_time: float = 0.0
var running: bool = false              # идёт ли сейчас игровая сессия


func _process(delta: float) -> void:
	if running and not get_tree().paused:
		play_time += delta


func reset() -> void:
	flags = {}
	evidence = []
	items = []
	picked = []
	visited_rooms = []
	events_done = []
	reactions = {}
	messages_seen = []
	documents_read = []
	door_states = {}
	choices = {}
	checkpoint = DEFAULT_CHECKPOINT
	final_choice = ""
	play_time = 0.0
	state_reset.emit()


# --- Флаги -----------------------------------------------------------------

func set_flag(flag: String, value: Variant = true) -> void:
	if flags.get(flag) == value:
		return
	flags[flag] = value
	flag_changed.emit(flag, value)


func has_flag(flag: String) -> bool:
	return bool(flags.get(flag, false))


func get_flag(flag: String, default: Variant = null) -> Variant:
	return flags.get(flag, default)


# --- Доказательства и предметы ---------------------------------------------

func add_evidence(id: String) -> bool:
	if id.is_empty() or evidence.has(id):
		return false
	evidence.append(id)
	evidence_added.emit(id)
	return true


func has_evidence(id: String) -> bool:
	return evidence.has(id)


func count_evidence(ids: Array) -> int:
	var n := 0
	for id: String in ids:
		if evidence.has(id):
			n += 1
	return n


func add_item(id: String) -> void:
	if not items.has(id):
		items.append(id)
		item_added.emit(id)


func has_item(id: String) -> bool:
	return items.has(id)


func mark_picked(persistent_id: String) -> void:
	if not persistent_id.is_empty() and not picked.has(persistent_id):
		picked.append(persistent_id)


func is_picked(persistent_id: String) -> bool:
	return picked.has(persistent_id)


# --- События, помещения, реакции -------------------------------------------

func mark_event(id: String) -> bool:
	if events_done.has(id):
		return false
	events_done.append(id)
	return true


func is_event_done(id: String) -> bool:
	return events_done.has(id)


func visit_room(room_id: String) -> bool:
	if visited_rooms.has(room_id):
		return false
	visited_rooms.append(room_id)
	return true


func has_visited(room_id: String) -> bool:
	return visited_rooms.has(room_id)


## Реакцию фиксируем один раз: первое решение игрока не переписывается.
func set_reaction(event_id: String, reaction: String) -> void:
	if not reactions.has(event_id):
		reactions[event_id] = reaction


func get_reaction(event_id: String) -> String:
	return str(reactions.get(event_id, ""))


func mark_message_seen(id: String) -> void:
	if not messages_seen.has(id):
		messages_seen.append(id)


func is_message_seen(id: String) -> bool:
	return messages_seen.has(id)


func mark_document_read(id: String) -> void:
	var first := not documents_read.has(id)
	if first:
		documents_read.append(id)
	if first:
		document_read.emit(id)


func is_document_read(id: String) -> bool:
	return documents_read.has(id)


func set_choice(choice_id: String, option_id: String) -> void:
	choices[choice_id] = option_id


# --- Двери -----------------------------------------------------------------

func set_door_state(door_id: String, is_open: bool, is_locked: bool) -> void:
	if door_id.is_empty():
		return
	door_states[door_id] = {"open": is_open, "locked": is_locked}


func get_door_state(door_id: String) -> Dictionary:
	var v: Variant = door_states.get(door_id, {})
	return v if v is Dictionary else {}


# --- Сериализация ----------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"flags": flags.duplicate(true),
		"evidence": evidence.duplicate(),
		"items": items.duplicate(),
		"picked": picked.duplicate(),
		"visited_rooms": visited_rooms.duplicate(),
		"events_done": events_done.duplicate(),
		"reactions": reactions.duplicate(),
		"messages_seen": messages_seen.duplicate(),
		"documents_read": documents_read.duplicate(),
		"door_states": door_states.duplicate(true),
		"choices": choices.duplicate(),
		"checkpoint": checkpoint,
		"final_choice": final_choice,
		"play_time": play_time,
	}


## Восстановление с проверкой типов: мусор в файле не должен ронять игру.
func from_dict(d: Dictionary) -> void:
	reset()
	flags = _dict(d.get("flags"))
	evidence = _str_array(d.get("evidence"))
	items = _str_array(d.get("items"))
	picked = _str_array(d.get("picked"))
	visited_rooms = _str_array(d.get("visited_rooms"))
	events_done = _str_array(d.get("events_done"))
	reactions = _dict(d.get("reactions"))
	messages_seen = _str_array(d.get("messages_seen"))
	documents_read = _str_array(d.get("documents_read"))
	choices = _dict(d.get("choices"))
	door_states = {}
	for key: Variant in _dict(d.get("door_states")):
		var s: Variant = d["door_states"][key]
		if s is Dictionary:
			door_states[str(key)] = {"open": bool(s.get("open", false)), "locked": bool(s.get("locked", false)),
				"sign": float(s.get("sign", 1.0))}
	checkpoint = str(d.get("checkpoint", DEFAULT_CHECKPOINT))
	final_choice = str(d.get("final_choice", ""))
	play_time = float(d.get("play_time", 0.0))


static func _dict(v: Variant) -> Dictionary:
	return (v as Dictionary).duplicate(true) if v is Dictionary else {}


static func _str_array(v: Variant) -> Array:
	var out: Array = []
	if v is Array:
		for e: Variant in v:
			out.append(str(e))
	return out
