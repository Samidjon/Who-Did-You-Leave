class_name FlickerLight
extends Light3D
## Управляемая лампа. Мерцание не случайно-постоянное: либо лампа «больная»
## (mode = FAULTY, редкие провалы только у конкретной лампы),
## либо мерцает по команде сюжета (flicker()).
## Вместе со светом гаснет светящийся материал плафона (emissive_mesh).

enum Mode { STEADY, FAULTY }

@export var zone: String = "default"
@export var mode: Mode = Mode.STEADY
@export var powered: bool = true
@export var emissive_mesh: NodePath
@export var buzz_slot: String = ""

var base_energy: float = 1.0
var _emissive_mat: StandardMaterial3D
var _base_emission: float = 1.0
var _flicker_left: float = 0.0
var _fault_timer: float = 0.0
var _buzz: Node = null


func _ready() -> void:
	add_to_group("flicker_lights")
	base_energy = light_energy
	var mi := get_node_or_null(emissive_mesh) as MeshInstance3D
	if mi:
		var mat := mi.get_active_material(0)
		if mat is StandardMaterial3D:
			_emissive_mat = (mat as StandardMaterial3D).duplicate()
			mi.set_surface_override_material(0, _emissive_mat)
			_base_emission = _emissive_mat.emission_energy_multiplier
	_fault_timer = randf_range(4.0, 9.0)
	_apply_level(1.0 if powered else 0.0)
	if not buzz_slot.is_empty() and powered:
		_start_buzz.call_deferred()


func _start_buzz() -> void:
	if is_inside_tree() and _buzz == null:
		_buzz = AudioManager.play_at(buzz_slot, global_position, "Ambience", -18.0, self, 8.0)


func set_powered(on: bool) -> void:
	powered = on
	_apply_level(1.0 if on else 0.0)
	if on and not buzz_slot.is_empty():
		_start_buzz()
	elif not on and is_instance_valid(_buzz):
		_buzz.queue_free()
		_buzz = null


## Сюжетное мерцание на duration секунд.
func flicker(duration: float = 1.5) -> void:
	_flicker_left = maxf(_flicker_left, duration)


func _process(delta: float) -> void:
	if not powered:
		return
	if _flicker_left > 0.0:
		_flicker_left -= delta
		var level := 1.0 if randf() > 0.45 else randf_range(0.0, 0.3)
		_apply_level(level if _flicker_left > 0.0 else 1.0)
		return
	if mode == Mode.FAULTY:
		_fault_timer -= delta
		if _fault_timer <= 0.0:
			_fault_timer = randf_range(5.0, 12.0)
			_flicker_left = randf_range(0.25, 0.7)


func _apply_level(level: float) -> void:
	light_energy = base_energy * level
	if _emissive_mat:
		_emissive_mat.emission_energy_multiplier = _base_emission * level
