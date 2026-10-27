extends Node
## Проигрывание сообщений (домофон, радио, телефон, голоса за дверью)
## и выдача субтитров. Тексты — data/dialogue/messages.<lang>.json.
## У каждой реплики может быть слот озвучки; если файла нет — показываем
## субтитры даже при выключенных субтитрах, иначе игрок не получит информацию.

signal line_started(speaker: String, text: String, forced: bool)
signal line_cleared
signal message_finished(message_id: String)

var _queue: Array = []            # [{id, source}]
var _playing_id: String = ""
var _bed: Node = null
var _voice: Node = null
var _skip: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE


func is_playing() -> bool:
	return not _playing_id.is_empty()


func current_message() -> String:
	return _playing_id


func has_message(id: String) -> bool:
	return Loc.data("dialogue/messages").has(id)


## source — Node3D, от которого звучит сообщение (может быть null).
func play_message(id: String, source: Node3D = null) -> void:
	if not has_message(id):
		push_warning("DialogueManager: нет сообщения '%s'" % id)
		message_finished.emit.call_deferred(id)
		return
	_queue.append({"id": id, "source": source})
	if _playing_id.is_empty():
		_next()


func stop_all() -> void:
	_queue.clear()
	_skip = true
	_cleanup()


## Последовательно проигрывает очередь. Реализовано через await,
## таймеры учитывают паузу игры.
func _next() -> void:
	if _queue.is_empty():
		_playing_id = ""
		return
	var item: Dictionary = _queue.pop_front()
	var id: String = item["id"]
	var source: Node3D = item["source"] if is_instance_valid(item["source"]) else null
	var msg: Dictionary = Loc.data("dialogue/messages")[id]
	_playing_id = id
	_skip = false
	GameState.mark_message_seen(id)

	var bed_slot: String = str(msg.get("bed", ""))
	if not bed_slot.is_empty():
		_bed = _play_slot(bed_slot, source, "Dialogue", float(msg.get("bed_db", -14.0)))

	var lines: Array = msg.get("lines", [])
	for line: Variant in lines:
		if _skip or not (line is Dictionary):
			break
		var speaker := str(line.get("speaker", msg.get("speaker", "")))
		var text := str(line.get("text", ""))
		var dur := float(line.get("dur", clampf(text.length() * 0.065, 2.0, 7.0)))
		var voice_path := str(line.get("voice", ""))
		var has_voice := not voice_path.is_empty() and ResourceLoader.exists(voice_path)
		if has_voice:
			_voice = _play_path(voice_path, source)
			var s: AudioStream = (_voice as Node).get("stream")
			if s:
				dur = maxf(dur, s.get_length() + 0.3)
		line_started.emit(speaker, text, not has_voice)
		await get_tree().create_timer(dur, false).timeout
		if is_instance_valid(_voice):
			_voice.queue_free()
		_voice = null
		line_cleared.emit()
		await get_tree().create_timer(0.25, false).timeout

	_cleanup()
	var finished_id := id
	_playing_id = ""
	message_finished.emit(finished_id)
	_next()


func _cleanup() -> void:
	if is_instance_valid(_bed):
		_bed.queue_free()
	_bed = null
	if is_instance_valid(_voice):
		_voice.queue_free()
	_voice = null
	line_cleared.emit()


func _play_slot(slot: String, source: Node3D, bus: String, vol: float) -> Node:
	if source and source.is_inside_tree():
		return AudioManager.play_at(slot, source.global_position, bus, vol, source)
	return AudioManager.play(slot, bus, vol)


func _play_path(path: String, source: Node3D) -> Node:
	var s := AudioManager.get_stream_by_path(path)
	if s == null:
		return null
	var p: Node
	if source and source.is_inside_tree():
		var p3 := AudioStreamPlayer3D.new()
		p3.stream = s
		p3.bus = "Dialogue"
		source.add_child(p3)
		p3.play()
		p = p3
	else:
		var p2 := AudioStreamPlayer.new()
		p2.stream = s
		p2.bus = "Dialogue"
		add_child(p2)
		p2.play()
		p = p2
	return p
