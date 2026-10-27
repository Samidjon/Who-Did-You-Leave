extends Node
## Звуковая система. Все звуки адресуются по имени слота, а не по пути к файлу,
## поэтому временные процедурные звуки можно заменить настоящими записями,
## просто положив файл по пути из SLOTS (или поменяв путь здесь).
## Отсутствующий файл не роняет игру: выводится одно предупреждение на слот.

const SLOTS := {
	# Эмбиент (зацикленные)
	"amb_building": "res://assets/audio/ambience/amb_building_hum.wav",
	"amb_pipes": "res://assets/audio/ambience/amb_pipes_water.wav",
	"amb_fridge": "res://assets/audio/ambience/amb_fridge_hum.wav",
	"amb_stairwell": "res://assets/audio/ambience/amb_stairwell_wind.wav",
	"music_menu": "res://assets/audio/music/music_menu_drone.wav",
	# Игрок
	"step": ["res://assets/audio/sfx/step_01.wav", "res://assets/audio/sfx/step_02.wav",
		"res://assets/audio/sfx/step_03.wav", "res://assets/audio/sfx/step_04.wav"],
	"step_stairs": ["res://assets/audio/sfx/step_concrete_01.wav", "res://assets/audio/sfx/step_concrete_02.wav"],
	"flashlight": "res://assets/audio/sfx/flashlight_click.wav",
	# Взаимодействия
	"door_open": "res://assets/audio/sfx/door_open_creak.wav",
	"door_close": "res://assets/audio/sfx/door_close.wav",
	"door_locked": "res://assets/audio/sfx/door_locked_rattle.wav",
	"door_unlock": "res://assets/audio/sfx/door_unlock.wav",
	"grate_open": "res://assets/audio/sfx/grate_open.wav",
	"key_pickup": "res://assets/audio/sfx/key_pickup.wav",
	"paper": "res://assets/audio/sfx/paper_rustle.wav",
	"switch": "res://assets/audio/sfx/switch_click.wav",
	"fuse": "res://assets/audio/sfx/fuse_clunk.wav",
	"ui_click": "res://assets/audio/sfx/ui_click.wav",
	# Устройства
	"intercom_buzz": "res://assets/audio/sfx/intercom_buzz.wav",
	"phone_ring": "res://assets/audio/sfx/phone_ring.wav",
	"phone_pickup": "res://assets/audio/sfx/phone_pickup.wav",
	"radio_static": "res://assets/audio/sfx/radio_static.wav",
	# Сюжетные звуки
	"knock_three": "res://assets/audio/sfx/knock_three.wav",
	"knock_three_far": "res://assets/audio/sfx/knock_three_far.wav",
	"knock_player": "res://assets/audio/sfx/knock_player.wav",
	"pipe_bang": "res://assets/audio/sfx/pipe_bang.wav",
	"distant_steps": "res://assets/audio/sfx/distant_steps.wav",
	"figure_presence": "res://assets/audio/sfx/figure_presence.wav",
	"whisper": "res://assets/audio/sfx/whisper_behind_door.wav",
	"light_buzz": "res://assets/audio/sfx/light_buzz.wav",
	"sting_low": "res://assets/audio/sfx/sting_low.wav",
}

## Слоты, которые всегда проигрываются зацикленно
const LOOPING := ["amb_building", "amb_pipes", "amb_fridge", "amb_stairwell", "music_menu",
	"radio_static", "light_buzz"]

var _cache: Dictionary = {}
var _warned: Dictionary = {}
var _ambience: AudioStreamPlayer
var _music: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ambience = _make_player("Ambience")
	_music = _make_player("Music")


func _make_player(bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	add_child(p)
	return p


func has_slot(slot: String) -> bool:
	return get_stream(slot, true) != null


## Возвращает поток слота (для слотов-вариаций — случайный вариант).
func get_stream(slot: String, quiet: bool = false) -> AudioStream:
	if not SLOTS.has(slot):
		if not quiet:
			_warn_once(slot, "AudioManager: неизвестный слот '%s'" % slot)
		return null
	var entry: Variant = SLOTS[slot]
	var path: String = entry.pick_random() if entry is Array else entry
	return _load(path, slot, quiet)


func get_stream_by_path(path: String) -> AudioStream:
	return _load(path, path, true)


func _load(path: String, slot: String, quiet: bool) -> AudioStream:
	if _cache.has(path):
		return _cache[path]
	if not ResourceLoader.exists(path):
		if not quiet:
			_warn_once(path, "AudioManager: нет файла для слота '%s': %s" % [slot, path])
		_cache[path] = null
		return null
	var s: AudioStream = load(path)
	if s and LOOPING.has(slot):
		_make_loop(s)
	_cache[path] = s
	return s


func _make_loop(s: AudioStream) -> void:
	if s is AudioStreamWAV:
		var w := s as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = int(w.get_length() * w.mix_rate)
	elif s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = true


func _warn_once(key: String, msg: String) -> void:
	if not _warned.has(key):
		_warned[key] = true
		push_warning(msg)


## Неточечный звук (интерфейс, собственные шаги игрока).
func play(slot: String, bus: String = "SFX", volume_db: float = 0.0, pitch_jitter: float = 0.0) -> AudioStreamPlayer:
	var s := get_stream(slot)
	if s == null:
		return null
	var p := AudioStreamPlayer.new()
	p.stream = s
	p.bus = bus
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	add_child(p)
	p.play()
	if not LOOPING.has(slot):
		p.finished.connect(p.queue_free)
	return p


## Звук с позицией в мире. parent — узел сцены, к которому он крепится
## (если null — к текущей сцене); звук удаляется после окончания.
func play_at(slot: String, position: Vector3, bus: String = "SFX", volume_db: float = 0.0,
		parent: Node = null, max_distance: float = 25.0) -> AudioStreamPlayer3D:
	var s := get_stream(slot)
	if s == null:
		return null
	var host: Node = parent if parent else get_tree().current_scene
	if host == null:
		return null
	var p := AudioStreamPlayer3D.new()
	p.stream = s
	p.bus = bus
	p.volume_db = volume_db
	p.max_distance = max_distance
	p.unit_size = 3.0
	p.attenuation_filter_cutoff_hz = 6000.0
	host.add_child(p)
	if p.is_inside_tree():
		p.global_position = position
	p.play()
	if not LOOPING.has(slot):
		p.finished.connect(p.queue_free)
	return p


func play_ambience(slot: String, fade: float = 2.0) -> void:
	_crossfade(_ambience, slot, fade, -4.0)


func stop_ambience(fade: float = 1.5) -> void:
	_fade_out(_ambience, fade)


func play_music(slot: String, fade: float = 2.0) -> void:
	_crossfade(_music, slot, fade, -6.0)


func stop_music(fade: float = 1.5) -> void:
	_fade_out(_music, fade)


func _crossfade(p: AudioStreamPlayer, slot: String, fade: float, target_db: float) -> void:
	var s := get_stream(slot)
	if s == null:
		return
	if p.stream == s and p.playing:
		return
	p.stream = s
	p.volume_db = -40.0
	p.play()
	var tw := create_tween()
	tw.tween_property(p, "volume_db", target_db, fade)


func _fade_out(p: AudioStreamPlayer, fade: float) -> void:
	if not p.playing:
		return
	var tw := create_tween()
	tw.tween_property(p, "volume_db", -40.0, fade)
	tw.tween_callback(p.stop)
