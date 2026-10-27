class_name LightingController
extends Node
## Управление светом уровня по зонам (коридор, лестница, квартиры).
## Лампы (FlickerLight) регистрируются по полю zone.

func _ready() -> void:
	add_to_group("lighting_controller")


func _lights(zone: String) -> Array:
	var out: Array = []
	for l in get_tree().get_nodes_in_group("flicker_lights"):
		if (l as FlickerLight).zone == zone:
			out.append(l)
	return out


func set_zone_power(zone: String, on: bool) -> void:
	for l: FlickerLight in _lights(zone):
		l.set_powered(on)


func flicker_zone(zone: String, duration: float = 1.5) -> void:
	for l: FlickerLight in _lights(zone):
		l.flicker(duration)


func is_zone_powered(zone: String) -> bool:
	for l: FlickerLight in _lights(zone):
		if l.powered:
			return true
	return false
