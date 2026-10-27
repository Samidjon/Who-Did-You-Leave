class_name HouseDirector
extends Node
## Режиссёр уровня «Дом». Вся сценарная логика вертикального прототипа:
## домофон → коридор → квартиры A/B/C → щитовая → лестница → фигура →
## кв. 13 → финальное решение. Каждое событие помечается в GameState,
## поэтому повторный вход в помещение и загрузка сохранения не запускают
## уже отыгранные сцены заново.

const EVIDENCE_CORE := ["ev_diary", "ev_calllog", "ev_act", "ev_expert", "ev_plumber"]

var game: Node = null
var level: Node3D = null
var lighting: LightingController = null
var _intercom_buzzing := false
var _phone_ringing := false
var _intercom_busy := false
var _desk_busy := false


func setup(g: Node) -> void:
	game = g
	level = get_parent() as Node3D
	lighting = level.get_node_or_null("Lighting") as LightingController
	Events.story_event.connect(_on_story_event)
	GameState.document_read.connect(_on_document_read)
	_restore_state()
	if not GameState.is_event_done("intro"):
		GameState.mark_event("intro")
		_intro()
	elif not GameState.has_flag("intercom_heard"):
		_start_intercom_buzz()


# ---------------------------------------------------------------- утилиты

func _n(path: String) -> Node:
	var n := level.get_node_or_null(path)
	if n == null:
		push_warning("HouseDirector: не найден узел " + path)
	return n


func _spot(name_: String) -> Vector3:
	var m := level.get_node_or_null("Spots/" + name_) as Node3D
	return m.global_position if m else Vector3.ZERO


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, false).timeout


## Проиграть сообщение и дождаться его окончания.
func _say(id: String, source: Node3D = null) -> void:
	if not DialogueManager.has_message(id):
		push_warning("HouseDirector: нет сообщения " + id)
		return
	DialogueManager.play_message(id, source)
	while true:
		var finished: String = await DialogueManager.message_finished
		if finished == id:
			break


func _set_prompt(path: String, key: String, enabled: bool = true) -> void:
	var it := level.get_node_or_null(path) as EventInteractable
	if it:
		it.set_prompt(key)
		it.enabled = enabled


func _choice(choice_key: String, option_ids: Array) -> String:
	var data: Dictionary = Loc.data("endings/endings").get("choices", {}).get(choice_key, {})
	var opts: Array = []
	for id: String in option_ids:
		opts.append({"id": id, "text": str(data.get("options", {}).get(id, id))})
	var holder := {"id": ""}
	var done := [false]
	Events.request_choice.emit(str(data.get("prompt", "")), opts, func(id: String) -> void:
		holder["id"] = id
		done[0] = true)
	while not done[0]:
		await get_tree().process_frame
	return holder["id"]


# ---------------------------------------------------------------- восстановление

func _restore_state() -> void:
	_apply_room_a_change()
	if GameState.is_event_done("knock_1") and GameState.get_reaction("knock_1").is_empty():
		_set_prompt("Interact/PipeA", "prompt.knock_back")
	else:
		_set_prompt("Interact/PipeA", "prompt.listen")
	if GameState.get_reaction("phone").is_empty():
		_set_prompt("Interact/PhoneB", "prompt.phone")
	elif GameState.get_reaction("phone") == "ignored" and not GameState.is_message_seen("phone_machine"):
		_set_prompt("Interact/PhoneB", "prompt.phone_machine")
	else:
		_set_prompt("Interact/PhoneB", "prompt.phone")
	_set_prompt("Interact/Exit", "prompt.leave", GameState.has_flag("intercom_heard"))


func _apply_room_a_change() -> void:
	var changed := GameState.has_flag("a_changed")
	var normal := level.get_node_or_null("Props/ChairA_Normal") as Node3D
	var moved := level.get_node_or_null("Props/ChairA_Moved") as Node3D
	if normal and moved:
		_set_prop_active(normal, not changed)
		_set_prop_active(moved, changed)


func _set_prop_active(n: Node3D, on: bool) -> void:
	n.visible = on
	for c in n.find_children("*", "CollisionShape3D", true, false):
		(c as CollisionShape3D).set_deferred("disabled", not on)


# ---------------------------------------------------------------- маршрутизация

func _on_story_event(id: String, data: Dictionary) -> void:
	match id:
		"intercom": _on_intercom(data)
		"radio": _on_radio(data)
		"pipe_a": _on_pipe_a()
		"phone_b": _on_phone_b(data)
		"receiver": _on_receiver(data)
		"desk": _on_desk()
		"exit": _on_exit()
		"switch_toggled": _on_switch(data)
		"door_opened": _on_door_opened(data)
		"door_locked_try": pass
		"item_picked": _on_item_picked(data)
		"enter:corridor": _on_enter_corridor()
		"enter:room_a": _on_enter_room_a()
		"exit:room_a": _on_exit_room_a()
		"enter:room_b": _on_enter_room_b()
		"enter:room_c": _maybe_change_room_a()
		"enter:room_tech": _on_enter_tech()
		"enter:stairs": _on_enter_stairs()
		"enter:door13_front": _on_door13_front()
		"enter:room_13": _on_enter_13()


func _on_document_read(doc_id: String) -> void:
	match doc_id:
		"doc_diary": _knock_event()
		"doc_statement": _after_statement()


# ---------------------------------------------------------------- пролог

func _intro() -> void:
	await _wait(1.2)
	await _say("wake")
	_start_intercom_buzz()


func _start_intercom_buzz() -> void:
	if _intercom_buzzing:
		return
	_intercom_buzzing = true
	var intercom := _n("Interact/Intercom") as Node3D
	while _intercom_buzzing and not GameState.has_flag("intercom_heard") and is_inside_tree():
		if intercom and not DialogueManager.is_playing():
			AudioManager.play_at("intercom_buzz", intercom.global_position, "SFX", -4.0)
		await _wait(4.0)


func _on_intercom(data: Dictionary) -> void:
	var src := data.get("source") as Node3D
	if GameState.has_flag("intercom_heard"):
		Events.notify.emit(Loc.t("notify.intercom_silent"))
		return
	if DialogueManager.current_message().begins_with("intercom") or _intercom_busy:
		return
	_intercom_busy = true
	_intercom_buzzing = false
	DialogueManager.stop_all()
	await _say("intercom_01", src)
	var answer := await _choice("intercom", ["who", "gone", "silent"])
	GameState.set_choice("intercom", answer)
	GameState.set_reaction("intercom", "silent" if answer == "silent" else "answered")
	await _say("intercom_reply_" + answer, src)
	GameState.set_flag("intercom_heard")
	_intercom_busy = false
	var d10 := _n("Doors/Door10") as Door
	if d10:
		d10.unlock()
	_set_prompt("Interact/Exit", "prompt.leave", true)


func _on_enter_corridor() -> void:
	if not GameState.has_flag("intercom_heard"):
		return
	if GameState.mark_event("corridor_first"):
		game.reach_checkpoint("cp_corridor")
		await _wait(0.8)
		await _say("corridor_first")
	_maybe_change_room_a()


# ---------------------------------------------------------------- квартира A

func _on_enter_room_a() -> void:
	if GameState.has_flag("a_changed") and GameState.mark_event("a_changed_seen"):
		await _wait(1.0)
		lighting.flicker_zone("apt_a", 0.8)
		await _say("a_changed")


## Стук за стеной — запускается, когда игрок прочитал дневник соседки.
func _knock_event() -> void:
	if not GameState.mark_event("knock_1"):
		return
	await _wait(3.0)
	AudioManager.play_at("knock_three", _spot("KnockA"), "SFX", 0.0)
	if lighting:
		lighting.flicker_zone("apt_a", 1.0)
	_set_prompt("Interact/PipeA", "prompt.knock_back")
	await _say("knock_first")


func _on_pipe_a() -> void:
	if not GameState.is_event_done("knock_1"):
		await _say("knock_listen_after")
		return
	if GameState.get_reaction("knock_1").is_empty():
		GameState.set_reaction("knock_1", "responded")
		GameState.set_flag("responded_knock")
		_set_prompt("Interact/PipeA", "prompt.listen")
		AudioManager.play_at("knock_player", _spot("KnockA"), "SFX", -2.0)
		await _wait(4.5)
		AudioManager.play_at("knock_three_far", _spot("KnockA"), "SFX", -4.0)
		await _say("knock_respond")
	else:
		await _say("knock_listen_after")


func _on_exit_room_a() -> void:
	if GameState.is_event_done("knock_1") and GameState.get_reaction("knock_1").is_empty():
		GameState.set_reaction("knock_1", "ignored")
		GameState.set_flag("ignored_knock")
		_set_prompt("Interact/PipeA", "prompt.listen")


## Комната A меняется, пока игрок отсутствует: стул развёрнут к трубе,
## на фотографии появляется новая деталь.
func _maybe_change_room_a() -> void:
	if not GameState.is_event_done("knock_1") or GameState.has_flag("a_changed"):
		return
	var trig := level.get_node_or_null("Triggers/RoomA") as StoryTrigger
	if trig and trig.player_inside:
		return
	GameState.set_flag("a_changed")
	_apply_room_a_change()


func _on_radio(data: Dictionary) -> void:
	if DialogueManager.current_message().begins_with("radio"):
		return
	var src := data.get("source") as Node3D
	if GameState.has_flag("knows_name") and not GameState.is_message_seen("radio_name"):
		GameState.set_flag("radio_said_name")
		game.vhs_glitch(0.5, 0.8)
		await _say("radio_name", src)
	elif not GameState.is_message_seen("radio_weather"):
		await _say("radio_weather", src)
	else:
		await _say("radio_dead", src)


# ---------------------------------------------------------------- квартира B

func _on_enter_room_b() -> void:
	_maybe_change_room_a()
	if not GameState.mark_event("phone_ring"):
		return
	await _wait(1.5)
	_phone_ringing = true
	var phone := _n("Interact/PhoneB") as Node3D
	for i in 4:
		if not _phone_ringing:
			return
		AudioManager.play_at("phone_ring", phone.global_position, "SFX", -2.0)
		await _wait(4.0)
	if _phone_ringing:
		_phone_ringing = false
		GameState.set_reaction("phone", "ignored")
		GameState.set_flag("ignored_phone")
		_set_prompt("Interact/PhoneB", "prompt.phone_machine")
		await _say("phone_ignored")


func _on_phone_b(data: Dictionary) -> void:
	var src := data.get("source") as Node3D
	if DialogueManager.current_message().begins_with("phone"):
		return
	AudioManager.play_at("phone_pickup", src.global_position, "SFX")
	if _phone_ringing:
		_phone_ringing = false
		GameState.set_reaction("phone", "responded")
		GameState.set_flag("answered_phone")
		await _say("phone_live", src)
	elif GameState.get_reaction("phone") == "ignored" and not GameState.is_message_seen("phone_machine"):
		await _say("phone_machine", src)
		_set_prompt("Interact/PhoneB", "prompt.phone")
	else:
		Events.notify.emit(Loc.t("notify.short_beeps"))


# ---------------------------------------------------------------- щитовая, свет, двери

func _on_enter_tech() -> void:
	_maybe_change_room_a()
	if not GameState.mark_event("tech_pipe"):
		return
	await _wait(1.8)
	AudioManager.play_at("pipe_bang", _spot("TechPipe"), "SFX", 0.0)
	await _say("tech_pipe")


func _on_switch(data: Dictionary) -> void:
	if data.get("flag") == "power_landing" and data.get("on", false):
		if GameState.mark_event("power_on"):
			await _say("power_on")


func _on_item_picked(data: Dictionary) -> void:
	if data.get("item_id") == "key_14" and GameState.mark_event("steps_upstairs"):
		await _wait(2.0)
		AudioManager.play_at("distant_steps", _spot("LandingTop"), "SFX", -2.0)


func _on_door_opened(data: Dictionary) -> void:
	if data.get("door_id") == "grate" and GameState.mark_event("grate_open"):
		game.reach_checkpoint("cp_landing")


## Прочитано объяснение с зачёркнутой строкой — дом «замечает» это.
func _after_statement() -> void:
	if not GameState.mark_event("after_statement"):
		return
	await _wait(1.5)
	if lighting:
		lighting.flicker_zone("corridor", 1.4)
	game.vhs_glitch(0.6, 0.7)
	AudioManager.play_at("knock_three_far", _spot("LandingTop"), "SFX", 0.0)


# ---------------------------------------------------------------- лестница и фигура

## Фигура на верхней площадке: появляется, когда игрок ступает на лестницу
## после открытия решётки. Исчезает от фонаря, при приближении или от долгого взгляда.
func _on_enter_stairs() -> void:
	if GameState.is_event_done("figure_1"):
		return
	var grate := _n("Doors/Grate") as Door
	if grate == null or grate.is_locked():
		return
	GameState.mark_event("figure_1")
	var fig := _n("Figure") as MysteryFigure
	if fig == null:
		GameState.set_flag("figure_seen")
		return
	fig.appear()
	DialogueManager.play_message("landing_steps")
	AudioManager.play_at("distant_steps", fig.global_position + Vector3.UP, "SFX", -6.0)
	await fig.vanished
	GameState.set_flag("figure_seen")
	if lighting:
		lighting.flicker_zone("landing", 1.2)
	game.vhs_glitch(1.0, 0.8)
	await _wait(0.8)
	await _say("figure_gone")


func _on_door13_front() -> void:
	if not GameState.mark_event("door13_voice"):
		return
	var src := _n("Spots/Door13") as Node3D
	if GameState.is_document_read("doc_diary"):
		await _say("door13_diary", src)
	elif GameState.is_document_read("doc_calllog"):
		await _say("door13_calllog", src)
	else:
		AudioManager.play_at("knock_three", src.global_position, "SFX", -2.0)
		await _say("door13_none")


# ---------------------------------------------------------------- кв. 13 и финал

func _on_enter_13() -> void:
	if not GameState.mark_event("enter_13"):
		return
	game.reach_checkpoint("cp_hidden")
	await _wait(1.0)
	await _say("enter_13")


func _on_receiver(data: Dictionary) -> void:
	var src := data.get("source") as Node3D
	if DialogueManager.current_message().begins_with("receiver"):
		return
	if GameState.mark_event("receiver"):
		var id := "receiver_responded" if GameState.has_flag("responded_knock") else "receiver_ignored"
		await _say(id, src)
	else:
		Events.notify.emit(Loc.t("notify.short_beeps"))


func can_confess() -> bool:
	return GameState.has_evidence("ev_statement") and GameState.count_evidence(EVIDENCE_CORE) >= 2


func _on_desk() -> void:
	if _desk_busy:
		return
	_desk_busy = true
	if GameState.mark_event("desk_intro"):
		await _say("desk_intro")
	var opts := ["not_known"]
	if can_confess():
		opts.append("was_there")
	opts.append("leave")
	var pick := await _choice("final", opts)
	_desk_busy = false
	match pick:
		"not_known":
			GameState.final_choice = "not_known"
			_end("not_known", "lie" if GameState.has_evidence("ev_statement") else "plain")
		"was_there":
			GameState.final_choice = "was_there"
			_end("was_there", "responded" if GameState.has_flag("responded_knock") else "silent")
		_:
			pass


func _on_exit() -> void:
	if not GameState.has_flag("intercom_heard"):
		return
	if GameState.mark_event("exit_hesitate"):
		await _say("exit_too_early")
	var pick := await _choice("exit", ["no", "yes"])
	if pick == "yes":
		GameState.final_choice = "left"
		_end("your_turn", "late" if GameState.evidence.size() >= 4 else "early")


func _end(ending_id: String, variant: String) -> void:
	GameState.set_flag("ending_" + ending_id)
	DialogueManager.stop_all()
	SceneRouter.to_ending(ending_id, variant)
