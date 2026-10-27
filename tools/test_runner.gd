extends Node
## Автоматическая проверка прототипа в headless-режиме.
## Запуск: godot --headless --path . --script res://tools/run_tests.gd
## (run_tests.gd — тонкий запускатель, логика здесь, в test_runner.gd)
## Проходит игру по сюжету «руками» (вызывая те же взаимодействия, что и игрок),
## проверяет физику, двери, триггеры, сохранения и концовку.

var passed := 0
var failed := 0
var game: Node3D
var player: Player
var ui: CanvasLayer
var level: Node3D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run()


func ok(cond: bool, what: String) -> void:
	if cond:
		passed += 1
		print("  [OK]   ", what)
	else:
		failed += 1
		print("  [FAIL] ", what)
		push_error("TEST FAIL: " + what)


func wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func until(cond: Callable, timeout: float, step := 0.1) -> bool:
	var t := 0.0
	while t < timeout:
		if cond.call():
			return true
		await get_tree().create_timer(step).timeout
		t += step
	return cond.call()


func node(path: String) -> Node:
	return level.get_node_or_null(path)


func tp(pos: Vector3, yaw_deg := 0.0) -> void:
	var b := Basis(Vector3.UP, deg_to_rad(yaw_deg))
	player.teleport(Transform3D(b, pos))
	await frames(3)


func use(path: String) -> void:
	var it := node(path) as Interactable
	if it == null:
		ok(false, "есть объект " + path)
		return
	it._last_time = -100.0
	it.interact(player)
	await frames(2)


func close_ui() -> void:
	while ui.is_any_open():
		ui.close_panel(ui.top_panel())
	await frames(1)


func pick_choice(option_id: String) -> bool:
	var got := await until(func() -> bool: return ui.choice_panel.visible, 30.0)
	if not got:
		return false
	await get_tree().create_timer(0.5, true, false, true).timeout  # реальное время: защита от случайного нажатия
	ui.choice_panel._pick(option_id)
	await frames(2)
	return true


func _run() -> void:
	print("\n===== WHO DID YOU LEAVE — автотесты =====")
	await get_tree().process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveManager.SAVE_PATH))
	_test_static()
	await _test_menu()
	await _test_game()
	await _test_save_robustness()
	print("\n===== Итог: %d OK, %d FAIL =====" % [passed, failed])
	get_tree().quit(0 if failed == 0 else 1)


# ------------------------------------------------------------------ статика

func _test_static() -> void:
	print("\n-- Ресурсы и данные")
	var scenes: Array = []
	_collect("res://scenes", scenes)
	var bad := 0
	for p: String in scenes:
		var ps := load(p) as PackedScene
		if ps == null or not ps.can_instantiate():
			bad += 1
			print("     не загружается: ", p)
	ok(bad == 0, "все %d сцен загружаются" % scenes.size())

	var missing := 0
	for slot: String in AudioManager.SLOTS:
		var e: Variant = AudioManager.SLOTS[slot]
		for path: String in (e if e is Array else [e]):
			if not ResourceLoader.exists(path):
				missing += 1
				print("     нет звука: ", path)
	ok(missing == 0, "все %d звуковых слотов имеют файлы" % AudioManager.SLOTS.size())

	var lvl := (load("res://scenes/levels/HouseLevel.tscn") as PackedScene).instantiate()
	var docs := Loc.data("story/documents")
	var insp := Loc.data("story/inspect")
	var bad_docs := 0
	for n in lvl.find_children("*", "Area3D", true, false):
		if n is Readable and not docs.has((n as Readable).document_id):
			bad_docs += 1
			print("     нет документа: ", (n as Readable).document_id)
		if n is Inspectable and not insp.has((n as Inspectable).inspect_id):
			bad_docs += 1
			print("     нет описания осмотра: ", (n as Inspectable).inspect_id)
	ok(bad_docs == 0, "все записки и предметы уровня ссылаются на существующие тексты")
	for cp: String in ["cp_start", "cp_corridor", "cp_landing", "cp_hidden"]:
		ok(lvl.get_node_or_null("Checkpoints/" + cp) != null, "контрольная точка " + cp)
	lvl.free()

	var src := FileAccess.get_file_as_string("res://scripts/narrative/house_director.gd")
	var re := RegEx.new()
	re.compile("_say\\(\"([a-z0-9_]+)\"[,)]|play_message\\(\"([a-z0-9_]+)\"[,)]")
	var msgs := Loc.data("dialogue/messages")
	var bad_msg := 0
	for m in re.search_all(src):
		var id := m.get_string(1) if m.get_string(1) != "" else m.get_string(2)
		if not msgs.has(id):
			bad_msg += 1
			print("     нет сообщения: ", id)
	for id: String in ["intercom_reply_who", "intercom_reply_gone", "intercom_reply_silent", "receiver_responded", "receiver_ignored"]:
		if not msgs.has(id):
			bad_msg += 1
	ok(bad_msg == 0, "все сообщения режиссёра есть в messages.ru.json")
	var endings: Dictionary = Loc.data("endings/endings").get("endings", {})
	ok(endings.has("not_known") and endings.has("was_there") and endings.has("your_turn"), "три концовки описаны")


func _collect(dir: String, out: Array) -> void:
	var d := DirAccess.open(dir)
	for f in d.get_files():
		if f.ends_with(".tscn"):
			out.append(dir + "/" + f)
	for sub in d.get_directories():
		_collect(dir + "/" + sub, out)


# ------------------------------------------------------------------ меню

func _test_menu() -> void:
	print("\n-- Главное меню")
	get_tree().change_scene_to_file("res://scenes/menus/MainMenu.tscn")
	await wait(0.5)
	var mm := get_tree().current_scene
	ok(mm != null and mm.name == "MainMenu", "главное меню открывается")
	ok(not (mm.get_node("UI/Root/Left/Buttons/Continue") as Button).visible, "без сохранения кнопка «Продолжить» скрыта")
	(mm.get_node("UI/Root/Left/Buttons/Settings") as Button).pressed.emit()
	await frames(2)
	ok((mm.get_node("UI/SettingsMenu") as Control).visible, "настройки открываются из меню")
	var rows := mm.get_node("UI/SettingsMenu/Box/Margin/VBox/Scroll/Rows")
	ok(rows.get_child_count() >= 10, "в настройках есть строки громкости/мыши/эффектов (%d)" % rows.get_child_count())
	Settings.set_volume("Music", 0.3)
	ok(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))), 0.3), "громкость шины Music применяется")
	Settings.set_volume("Music", 0.6)
	(mm.get_node("UI/SettingsMenu/Box/Margin/VBox/Back") as Button).pressed.emit()
	await frames(2)


# ------------------------------------------------------------------ прохождение

func _test_game() -> void:
	print("\n-- Новая игра")
	SceneRouter.new_game()
	await until(func() -> bool: return get_tree().current_scene != null and get_tree().current_scene.name == "Game", 10.0)
	game = get_tree().current_scene as Node3D
	ok(game != null and game.name == "Game", "игровая сцена загружена")
	player = game.get_node("Player")
	ui = game.get_node("GameUI")
	level = game.get_node("HouseLevel")
	await wait(1.0)

	print("\n-- Физика игрока")
	var y0 := player.global_position.y
	await frames(90)
	ok(player.is_on_floor(), "игрок стоит на полу")
	ok(absf(player.global_position.y - y0) < 0.2, "игрок не проваливается (y=%.3f)" % player.global_position.y)

	# Ходьба: пробуем идти сквозь закрытую дверь 10 (на x=0) — должна остановить
	await tp(Vector3(-1.2, 0.05, 3.0), -90)
	Input.action_press("move_forward")
	await wait(2.0)
	Input.action_release("move_forward")
	ok(player.global_position.x < -0.2, "закрытая дверь не пропускает игрока (x=%.2f)" % player.global_position.x)
	var moved := player.global_position.x > -1.15
	ok(moved, "игрок двигается вперёд от ввода")
	# Стена
	await tp(Vector3(-2.0, 0.05, 3.0), 90)
	Input.action_press("move_forward")
	await wait(2.0)
	Input.action_release("move_forward")
	ok(player.global_position.x > -3.9 + 0.25, "стена не пропускает игрока (x=%.2f)" % player.global_position.x)
	await wait(0.5)
	ok(Vector2(player.velocity.x, player.velocity.z).length() < 0.05, "после отпускания клавиш нет скольжения")
	# Присед
	player.crouching = true
	await wait(0.6)
	ok(player._current_height < 1.2, "присед уменьшает рост")
	player.crouching = false
	await wait(0.6)
	ok(player._current_height > 1.7, "игрок встаёт")
	player.toggle_flashlight()
	ok(player.flashlight.visible, "фонарик включается")
	player.toggle_flashlight()
	ok(not player.flashlight.visible, "фонарик выключается")

	print("\n-- Пролог: домофон")
	await tp(Vector3(-0.8, 0.05, 3.0), -90)
	await use("Doors/Door10")
	ok(not (node("Doors/Door10") as Door).is_open(), "дверь 10 заперта до ответа домофону")
	Engine.time_scale = 6.0
	await wait(1.0)
	await tp(Vector3(-0.8, 0.05, 4.3), -90)
	await use("Interact/Intercom")
	var chose := await pick_choice("gone")
	ok(chose, "после сообщения домофона появляется выбор ответа")
	await until(func() -> bool: return GameState.has_flag("intercom_heard"), 30.0)
	ok(GameState.has_flag("intercom_heard"), "домофон прослушан")
	ok(GameState.choices.get("intercom") == "gone", "ответ домофону записан")
	Engine.time_scale = 1.0
	await tp(Vector3(-0.8, 0.05, 3.0), -90)
	await use("Doors/Door10")
	await wait(1.2)
	ok((node("Doors/Door10") as Door).is_open(), "дверь 10 открывается после домофона")
	var hinge := (node("Doors/Door10") as Door).hinge
	ok(absf(hinge.rotation.y) > deg_to_rad(80), "полотно повернулось вокруг петли (%.0f°)" % rad_to_deg(hinge.rotation.y))
	await use("Doors/Door10")
	await wait(1.2)
	ok(not (node("Doors/Door10") as Door).is_open(), "дверь закрывается обратно")
	await use("Doors/Door10")
	await wait(1.2)
	# Сквозь ОТКРЫТУЮ дверь игрок должен проходить
	await tp(Vector3(-1.0, 0.05, 3.0), -90)
	Input.action_press("move_forward")
	await wait(1.6)
	Input.action_release("move_forward")
	ok(player.global_position.x > 0.6, "через открытую дверь можно пройти (x=%.2f)" % player.global_position.x)

	# Луч взаимодействия: игрок у двери, смотрит на неё — должна появиться цель
	await tp(Vector3(-0.6, 0.05, 4.35), -90)
	player.head.rotation.x = deg_to_rad(-8)
	await frames(4)
	ok(player.current_target != null and player.current_target.name == "Intercom", "луч находит домофон и даёт подсказку «%s»" % (player.current_target.get_prompt() if player.current_target else "-"))
	player.head.rotation.x = 0

	print("\n-- Коридор и квартира A")
	await tp(Vector3(1.1, 0.05, 2.0), 0)
	await wait(0.5)
	ok(GameState.is_event_done("corridor_first"), "первый вход в коридор отмечен")
	ok(GameState.checkpoint == "cp_corridor" and SaveManager.has_save(), "контрольная точка коридора и автосохранение")
	await use("Doors/Door11")
	await wait(1.0)
	await tp(Vector3(-2.4, 0.05, -1.0), 180)
	await wait(0.3)
	ok(GameState.has_visited("apt_a"), "квартира A исследована")
	await use("Interact/Radio")
	await close_ui()
	Engine.time_scale = 6.0
	await until(func() -> bool: return not DialogueManager.is_playing(), 20.0)
	ok(GameState.is_message_seen("radio_weather"), "радио до знакомства с именем — прогноз погоды")
	await use("Interact/DiaryA")
	ok(ui.document_viewer.visible, "дневник открывается в окне чтения")
	ok(player.input_enabled == false, "при чтении игрок заморожен")
	await close_ui()
	ok(player.input_enabled, "после закрытия управление возвращается")
	ok(GameState.has_evidence("ev_diary"), "дневник стал доказательством")
	await until(func() -> bool: return GameState.is_event_done("knock_1"), 10.0)
	await wait(4.0)
	ok(GameState.is_event_done("knock_1"), "стук за стеной произошёл после дневника")
	ok((node("Interact/PipeA") as EventInteractable).prompt_key == "prompt.knock_back", "у трубы появилась подсказка «Постучать в ответ»")
	await use("Interact/PipeA")
	await until(func() -> bool: return not DialogueManager.is_playing(), 30.0)
	ok(GameState.get_reaction("knock_1") == "responded", "реакция на стук записана: ответил")
	await use("Interact/Radio")
	await until(func() -> bool: return not DialogueManager.is_playing(), 30.0)
	ok(GameState.is_message_seen("radio_name"), "радио называет имя, найденное в документах")
	await use("Interact/PhotoA")
	ok(ui.inspect_viewer.visible, "фотография открывается для осмотра")
	ok(ui.inspect_viewer.pivot.get_child_count() == 1, "в окне осмотра есть копия предмета")
	await close_ui()
	Engine.time_scale = 1.0
	var events_before := GameState.events_done.size()
	await tp(Vector3(1.1, 0.05, -1.0), 0)
	await tp(Vector3(-2.4, 0.05, -1.0), 180)
	await wait(0.3)
	await tp(Vector3(1.1, 0.05, -1.0), 0)
	await wait(0.3)
	ok(GameState.events_done.size() == events_before, "повторный вход в A не перезапускает события")

	print("\n-- Квартира B")
	await use("Doors/Door12")
	await wait(1.0)
	await tp(Vector3(1.1, 0.05, -1.0), -90)
	Input.action_press("move_forward")
	await wait(1.6)
	Input.action_release("move_forward")
	ok(player.global_position.x > 2.8, "через открытую дверь 12 можно пройти (x=%.2f)" % player.global_position.x)
	await tp(Vector3(4.0, 0.05, -2.5), 90)
	await wait(2.5)
	ok(GameState.is_event_done("phone_ring"), "в квартире B звонит телефон")
	ok(GameState.has_flag("a_changed"), "квартира A изменилась, пока игрока не было")
	ok(not (node("Props/ChairA_Normal") as Node3D).visible and (node("Props/ChairA_Moved") as Node3D).visible, "стул в A переставлен")
	ok((node("Interact/PhotoA") as Inspectable).current_id() == "photo_yard_changed", "на фото появилась новая деталь")
	await use("Interact/PhoneB")
	Engine.time_scale = 6.0
	await until(func() -> bool: return not DialogueManager.is_playing(), 30.0)
	ok(GameState.get_reaction("phone") == "responded", "реакция на звонок записана: ответил")
	await use("Interact/CallLogB")
	await close_ui()
	ok(GameState.has_evidence("ev_calllog"), "листок звонков — доказательство")
	await use("Interact/Key14")
	ok(GameState.has_item("key_14"), "ключ от кв. 14 подобран")
	ok(not (node("Interact/Key14") as Node3D).visible, "ключ исчез со сцены")
	Engine.time_scale = 1.0

	print("\n-- Квартира C")
	await tp(Vector3(1.1, 0.05, -8.0), 0)
	await use("Doors/Door14")
	await wait(1.0)
	ok((node("Doors/Door14") as Door).is_open(), "дверь 14 открыта ключом")
	await tp(Vector3(-2.8, 0.05, -10.4), 0)
	for d: String in ["Interact/ActC", "Interact/StatementC", "Interact/ExpertC"]:
		await use(d)
		await close_ui()
	ok(GameState.count_evidence(["ev_act", "ev_statement", "ev_expert"]) == 3, "документы кв. 14 собраны")
	await use("Interact/SwitchC")
	ok(GameState.has_flag("light_c"), "выключатель включает свет в кв. 14")
	ok((level.get_node("Lighting") as LightingController).is_zone_powered("apt_c"), "лампы зоны apt_c запитаны")

	print("\n-- Щитовая и решётка")
	await tp(Vector3(1.1, 0.05, -12.5), 180)
	await use("Doors/Grate")
	ok((node("Doors/Grate") as Door).is_locked(), "решётка без ключа заперта")
	await tp(Vector3(1.1, 0.05, -9.0), 0)
	await use("Doors/DoorTech")
	await wait(1.0)
	await tp(Vector3(4.5, 0.05, -8.8), 90)
	Engine.time_scale = 6.0
	await wait(2.0)
	ok(GameState.is_event_done("tech_pipe"), "в щитовой бьёт труба (обычный источник звука)")
	ok(not (level.get_node("Lighting") as LightingController).is_zone_powered("landing"), "свет на лестнице сначала выключен")
	await use("Interact/Breaker")
	ok(GameState.has_flag("power_landing"), "рубильник включён")
	ok((level.get_node("Lighting") as LightingController).is_zone_powered("landing"), "на лестнице загорелся свет")
	await use("Interact/KeyGrate")
	await use("Interact/PlumberLog")
	await close_ui()
	Engine.time_scale = 1.0
	await tp(Vector3(3.6, 0.05, -14.4), 0)
	await use("Doors/Grate")
	await wait(1.2)
	ok((node("Doors/Grate") as Door).is_open(), "решётка открыта ключом")
	ok(GameState.checkpoint == "cp_landing", "контрольная точка у лестницы")

	print("\n-- Лестница и фигура")
	await tp(Vector3(3.6, 0.05, -15.3), 0)
	await wait(0.5)
	var fig := node("Figure") as MysteryFigure
	ok(fig.visible and fig.active, "на площадке появилась фигура")
	player.toggle_flashlight()
	var to_fig := fig.global_position + Vector3.UP * 1.5 - player.camera.global_position
	player.rotation.y = atan2(-to_fig.x, -to_fig.z)
	player.head.rotation.x = atan2(to_fig.y, Vector2(to_fig.x, to_fig.z).length())
	await wait(0.4)
	ok(not fig.active, "фигура исчезает в луче фонаря")
	ok(GameState.has_flag("figure_seen"), "встреча с фигурой отмечена")
	player.toggle_flashlight()
	player.head.rotation.x = 0
	# Подъём по лестнице
	await tp(Vector3(3.6, 0.05, -15.4), 0)
	Input.action_press("move_forward")
	await wait(3.0)
	Input.action_release("move_forward")
	ok(player.global_position.y > 1.3 and player.global_position.z < -18.2, "игрок поднялся по лестнице (y=%.2f, z=%.2f)" % [player.global_position.y, player.global_position.z])
	ok(player.is_on_floor(), "на площадке игрок стоит на полу")

	print("\n-- Квартира 13 и финал")
	Engine.time_scale = 6.0
	await tp(Vector3(-1.0, 1.45, -19.6), 0)
	await wait(2.0)
	ok(GameState.is_event_done("door13_voice"), "за дверью 13 повторяют знакомую фразу")
	await use("Interact/Note13")
	await close_ui()
	await use("Doors/Door13")
	await wait(1.0)
	ok((node("Doors/Door13") as Door).is_open(), "дверь 13 открылась после встречи с фигурой")
	await tp(Vector3(-0.9, 1.45, -21.6), 0)
	await wait(1.0)
	ok(GameState.checkpoint == "cp_hidden", "контрольная точка в кв. 13")
	await use("Interact/Receiver13")
	await until(func() -> bool: return not DialogueManager.is_playing(), 30.0)
	ok(GameState.is_message_seen("receiver_responded"), "трубка помнит, что игрок ответил на стук")
	await use("Interact/Calendar13")
	await close_ui()
	ok(level.get_node("Director").can_confess(), "собрано достаточно, чтобы признаться")

	# Проверяем сохранение/загрузку посреди игры
	var snapshot := GameState.to_dict()
	ok(SaveManager.save_game(), "сохранение записано")
	GameState.reset()
	ok(SaveManager.load_game(), "сохранение загружено")
	ok(GameState.evidence.size() == (snapshot["evidence"] as Array).size() and GameState.checkpoint == "cp_hidden", "состояние восстановлено из сохранения")
	ok(GameState.get_door_state("door_14").get("open", false), "состояние дверей сохранено")

	await use("Interact/Desk13")
	var got := await until(func() -> bool: return ui.choice_panel.visible, 20.0)
	ok(got, "за столом появляется выбор")
	var labels: Array = []
	await get_tree().process_frame
	for b in ui.choice_panel.list.get_children():
		if not b.is_queued_for_deletion():
			labels.append((b as Button).text)
	ok(labels.size() == 3, "три варианта объяснения: %s" % str(labels))
	await get_tree().create_timer(0.5, true, false, true).timeout
	ui.choice_panel._pick("was_there")
	Engine.time_scale = 1.0
	await until(func() -> bool: return get_tree().current_scene != null and get_tree().current_scene.name == "EndingScreen", 10.0)
	ok(get_tree().current_scene != null and get_tree().current_scene.name == "EndingScreen", "открылся экран концовки")
	await wait(0.2)
	var title := (get_tree().current_scene.get_node("Center/VBox/Title") as Label).text
	ok(title == "Я БЫЛ ТАМ", "концовка «Я был там» (%s)" % title)

	print("\n-- Продолжить после концовки")
	SceneRouter.to_main_menu()
	await until(func() -> bool: return get_tree().current_scene != null and get_tree().current_scene.name == "MainMenu", 10.0)
	await wait(0.3)
	ok((get_tree().current_scene.get_node("UI/Root/Left/Buttons/Continue") as Button).visible, "в меню доступно «Продолжить»")
	ok(SceneRouter.continue_game(), "загрузка продолжения")
	await until(func() -> bool: return get_tree().current_scene != null and get_tree().current_scene.name == "Game", 10.0)
	game = get_tree().current_scene as Node3D
	player = game.get_node("Player")
	level = game.get_node("HouseLevel")
	ui = game.get_node("GameUI")
	await wait(0.5)
	ok(player.global_position.distance_to(Vector3(-0.9, 1.45, -21.3)) < 0.6, "игрок появился на контрольной точке кв. 13")
	ok((level.get_node("Doors/Door14") as Door).is_open(), "открытая дверь 14 восстановлена")
	ok(not (level.get_node("Interact/Key14") as Node3D).visible, "подобранный ключ не вернулся")
	ok((level.get_node("Props/ChairA_Moved") as Node3D).visible, "изменения в кв. A восстановлены")
	ok(not (level.get_node("Figure") as MysteryFigure).visible, "фигура не появляется повторно")
	# Пауза
	var ev := InputEventAction.new()
	ev.action = "pause"
	ev.pressed = true
	Input.parse_input_event(ev)
	await get_tree().process_frame
	await get_tree().process_frame
	ok(ui.pause_menu.visible and get_tree().paused, "Esc открывает паузу и останавливает игру")
	ui.close_panel(ui.pause_menu)
	await get_tree().process_frame
	ok(not get_tree().paused, "из паузы можно вернуться")
	# Концовка 3: уход из дома
	Engine.time_scale = 6.0
	await use("Interact/Exit")
	var c := await pick_choice("yes")
	ok(c, "у выхода спрашивают подтверждение")
	Engine.time_scale = 1.0
	await until(func() -> bool: return get_tree().current_scene != null and get_tree().current_scene.name == "EndingScreen", 10.0)
	await wait(0.2)
	ok((get_tree().current_scene.get_node("Center/VBox/Title") as Label).text == "ТЕПЕРЬ ТВОЯ ОЧЕРЕДЬ", "концовка «Теперь твоя очередь»")


# ------------------------------------------------------------------ сохранения: ошибки

func _test_save_robustness() -> void:
	print("\n-- Повреждённые сохранения")
	var f := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	f.store_string("{ это не json")
	f.close()
	ok(not SaveManager.has_save(), "битый JSON не считается сохранением")
	ok(SaveManager.last_error == "corrupt", "ошибка распознана как повреждение")
	ok(not SaveManager.load_game(), "загрузка битого файла не падает")
	f = FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify({"format": "who_did_you_leave_save", "version": 99, "state": {}}))
	f.close()
	ok(not SaveManager.has_save() and SaveManager.last_error == "version", "неизвестная версия сохранения отклоняется")
	f = FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify({"format": "who_did_you_leave_save", "version": 1, "state": {"evidence": "строка вместо массива", "door_states": [1, 2], "checkpoint": "cp_nowhere"}}))
	f.close()
	ok(SaveManager.load_game(), "сохранение с мусорными полями загружается")
	ok(GameState.evidence.is_empty() and GameState.door_states.is_empty(), "мусорные поля отброшены")
	SaveManager.delete_save()
	ok(not SaveManager.has_save(), "сохранение удаляется")
