class_name Player
extends CharacterBody3D
## Контроллер от первого лица: ходьба/бег/присед, обзор мышью,
## покачивание камеры, шаги, фонарик и поиск интерактивных объектов лучом.
## Когда открыт интерфейс (пауза, документ, журнал) — input_enabled = false:
## камера и движение заморожены.

signal target_changed(target: Interactable)
signal flashlight_toggled(on: bool)

@export_group("Движение")
@export var walk_speed: float = 2.3
@export var run_speed: float = 3.9
@export var crouch_speed: float = 1.15
@export var acceleration: float = 11.0
@export var deceleration: float = 15.0
@export_group("Рост")
@export var stand_height: float = 1.75
@export var crouch_height: float = 1.1
@export var eye_offset: float = 0.12        # глаза ниже макушки
@export_group("Обзор")
@export var base_sensitivity: float = 0.0022 # рад/пиксель при множителе 1.0
@export var pitch_limit_deg: float = 85.0
@export var bob_amount: float = 0.028
@export var bob_frequency: float = 1.85     # шагов в секунду при ходьбе
@export_group("Взаимодействие")
@export var interact_distance: float = 2.1

@onready var collider: CollisionShape3D = $Collider
@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera
@onready var ray: RayCast3D = $Head/Camera/InteractRay
@onready var flashlight: SpotLight3D = $Head/Camera/Flashlight
@onready var ceiling_check: ShapeCast3D = $CeilingCheck

var input_enabled: bool = true
var crouching: bool = false
var running: bool = false
var flashlight_on: bool = false
var current_target: Interactable = null
var on_stairs: bool = false
var _hard_floor_count: int = 0

var _pitch: float = 0.0
var _bob_time: float = 0.0
var _step_distance: float = 0.0
var _capsule: CapsuleShape3D
var _current_height: float
var _gravity: float = 9.8
var _flash_sway := Vector2.ZERO


func _ready() -> void:
	add_to_group("player")
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	_capsule = (collider.shape as CapsuleShape3D).duplicate()
	collider.shape = _capsule
	_current_height = stand_height
	_set_height(stand_height)
	ray.target_position = Vector3(0, 0, -interact_distance)
	ray.add_exception(self)
	ceiling_check.add_exception(self)
	flashlight.visible = false
	floor_snap_length = 0.35
	floor_max_angle = deg_to_rad(46.0)
	floor_constant_speed = true
	floor_stop_on_slope = true
	Events.ui_mode_changed.connect(_on_ui_mode_changed)


func _on_ui_mode_changed(ui_open: bool) -> void:
	input_enabled = not ui_open
	if ui_open:
		_set_target(null)


## Мгновенно поставить игрока в точку (контрольная точка, загрузка).
func teleport(xform: Transform3D) -> void:
	global_position = xform.origin
	var fwd := -xform.basis.z
	rotation.y = atan2(-fwd.x, -fwd.z)
	_pitch = 0.0
	head.rotation.x = 0.0
	velocity = Vector3.ZERO


func enter_hard_floor() -> void:
	_hard_floor_count += 1
	on_stairs = true


func exit_hard_floor() -> void:
	_hard_floor_count = maxi(_hard_floor_count - 1, 0)
	on_stairs = _hard_floor_count > 0


func get_look_yaw() -> float:
	return rotation.y


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var m := event as InputEventMouseMotion
		var sens := base_sensitivity * Settings.mouse_sensitivity
		rotate_y(-m.relative.x * sens)
		var dy := m.relative.y * sens * (-1.0 if Settings.invert_y else 1.0)
		_pitch = clampf(_pitch - dy, -deg_to_rad(pitch_limit_deg), deg_to_rad(pitch_limit_deg))
		head.rotation.x = _pitch
		_flash_sway += Vector2(m.relative.x, m.relative.y) * 0.0004
	elif event.is_action_pressed("flashlight"):
		toggle_flashlight()
	elif event.is_action_pressed("crouch"):
		if not crouching:
			crouching = true
		elif _can_stand():
			crouching = false
	elif event.is_action_pressed("interact"):
		if current_target and current_target.can_interact():
			current_target.interact(self)
			get_viewport().set_input_as_handled()


func toggle_flashlight() -> void:
	flashlight_on = not flashlight_on
	flashlight.visible = flashlight_on
	AudioManager.play("flashlight", "SFX", -6.0)
	flashlight_toggled.emit(flashlight_on)


func _physics_process(delta: float) -> void:
	# Гравитация
	if not is_on_floor():
		velocity.y -= _gravity * delta
	# Присед: плавно меняем рост; встаём, только если над головой свободно
	var target_h := crouch_height if crouching else stand_height
	if not crouching and _current_height < stand_height - 0.01 and not _can_stand():
		target_h = _current_height
	if absf(_current_height - target_h) > 0.001:
		_set_height(move_toward(_current_height, target_h, delta * 3.2))

	# Ввод движения
	var input := Vector2.ZERO
	if input_enabled:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	running = input_enabled and Input.is_action_pressed("run") and not crouching and input.y < 0.1 and input.length() > 0.1
	var speed := crouch_speed if crouching else (run_speed if running else walk_speed)
	var wish := (transform.basis * Vector3(input.x, 0, input.y))
	wish.y = 0
	wish = wish.normalized() * speed * minf(input.length(), 1.0)

	var horizontal := Vector3(velocity.x, 0, velocity.z)
	var rate := acceleration if wish.length() > 0.01 else deceleration
	horizontal = horizontal.lerp(wish, 1.0 - exp(-rate * delta))
	if wish.length() < 0.01 and horizontal.length() < 0.05:
		horizontal = Vector3.ZERO
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	move_and_slide()

	_update_bob_and_steps(delta)
	_update_flashlight(delta)
	_update_target()


func _can_stand() -> bool:
	ceiling_check.force_shapecast_update()
	return not ceiling_check.is_colliding()


func _set_height(h: float) -> void:
	_current_height = h
	_capsule.height = h
	_capsule.radius = 0.3
	collider.position.y = h * 0.5
	head.position.y = h - eye_offset


func _update_bob_and_steps(delta: float) -> void:
	var hspeed := Vector2(velocity.x, velocity.z).length()
	var moving := is_on_floor() and hspeed > 0.3
	if moving:
		var freq := bob_frequency * (hspeed / walk_speed)
		_bob_time += delta * freq * TAU * 0.5
		_step_distance += hspeed * delta
		var stride := 0.62 if not running else 0.8
		if crouching:
			stride = 0.5
		if _step_distance >= stride:
			_step_distance = 0.0
			_play_step()
	else:
		_bob_time = lerpf(_bob_time, roundf(_bob_time / PI) * PI, 1.0 - exp(-6.0 * delta))
	var amount := bob_amount if Settings.head_bob else 0.0
	if crouching:
		amount *= 0.5
	var intensity := clampf(hspeed / walk_speed, 0.0, 1.4)
	camera.position.y = absf(sin(_bob_time)) * amount * intensity - amount * 0.5 * intensity
	camera.position.x = sin(_bob_time * 0.5) * amount * 0.5 * intensity
	camera.rotation.z = lerpf(camera.rotation.z, -velocity.dot(transform.basis.x) * 0.004 * (1.0 if Settings.head_bob else 0.0), 1.0 - exp(-8.0 * delta))


func _play_step() -> void:
	var slot := "step_stairs" if on_stairs else "step"
	var vol := -9.0
	if crouching:
		vol = -20.0
	elif running:
		vol = -5.0
	AudioManager.play(slot, "SFX", vol, 0.08)


func _update_flashlight(delta: float) -> void:
	# Фонарь слегка запаздывает за взглядом — живее и без укачивания.
	_flash_sway = _flash_sway.lerp(Vector2.ZERO, 1.0 - exp(-7.0 * delta))
	flashlight.rotation.y = -_flash_sway.x
	flashlight.rotation.x = -_flash_sway.y


func _update_target() -> void:
	if not input_enabled:
		return
	var found: Interactable = null
	if ray.is_colliding():
		var col := ray.get_collider()
		if col is Interactable and (col as Interactable).can_interact():
			found = col
	_set_target(found)


func _set_target(t: Interactable) -> void:
	if t != current_target:
		current_target = t
		target_changed.emit(t)
