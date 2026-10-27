extends ColorRect
## Аналоговая постобработка поверх 3D (под интерфейсом).
## Интенсивность берётся из настроек: 0 — эффект выключен полностью.

const LEVELS := [0.0, 0.55, 1.0]

var _mat: ShaderMaterial
var _glitch: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = material as ShaderMaterial
	Settings.changed.connect(_apply)
	_apply()


func _apply() -> void:
	var lvl: float = LEVELS[clampi(Settings.vhs_intensity, 0, 2)]
	visible = lvl > 0.0
	if _mat:
		_mat.set_shader_parameter("intensity", lvl)


## Короткий сбой изображения (сюжетные моменты).
func glitch(strength: float = 1.0, duration: float = 0.6) -> void:
	if not visible or _mat == null:
		return
	_glitch = strength
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void: _mat.set_shader_parameter("glitch", v), strength, 0.0, duration)
