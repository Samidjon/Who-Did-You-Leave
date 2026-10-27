extends Control
## Осмотр предмета с приближением: копия визуальной части объекта
## помещается в отдельный SubViewport со своим миром и светом.
## Мышь вращает предмет, колесо — приближение.

@onready var viewport: SubViewport = $ViewportContainer/Viewport
@onready var pivot: Node3D = $ViewportContainer/Viewport/Pivot
@onready var cam: Camera3D = $ViewportContainer/Viewport/Camera
@onready var title_label: Label = $Info/Margin/VBox/Title
@onready var desc: RichTextLabel = $Info/Margin/VBox/Desc
@onready var hint: Label = $Hint

var _rot := Vector2.ZERO
var _dist: float = 0.8


func _ready() -> void:
	visible = false
	hint.text = Loc.t("viewer.rotate")


func show_item(visual: Node3D, title: String, description: String) -> void:
	for c in pivot.get_children():
		c.queue_free()
	_rot = Vector2(0.15, 0.0)
	if visual:
		var copy := visual.duplicate() as Node3D
		copy.transform = Transform3D.IDENTITY
		copy.visible = true
		pivot.add_child(copy)
		var aabb := _calc_aabb(copy)
		copy.position = -aabb.get_center()
		var size := maxf(aabb.size.length(), 0.05)
		_dist = clampf(size * 1.25, 0.25, 4.0)
	title_label.text = title
	desc.text = description
	_apply()


func _calc_aabb(n: Node3D) -> AABB:
	var result := AABB()
	var first := true
	for mi in n.find_children("*", "VisualInstance3D", true, false):
		var vi := mi as VisualInstance3D
		var box := n.global_transform.affine_inverse() * vi.global_transform * vi.get_aabb() if n.is_inside_tree() else vi.transform * vi.get_aabb()
		if first:
			result = box
			first = false
		else:
			result = result.merge(box)
	if n is VisualInstance3D:
		result = (n as VisualInstance3D).get_aabb() if first else result.merge((n as VisualInstance3D).get_aabb())
	return result


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseMotion:
		var m := event as InputEventMouseMotion
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			_rot.y += m.relative.x * 0.008
			_rot.x = clampf(_rot.x + m.relative.y * 0.008, -1.4, 1.4)
			_apply()
	elif event is InputEventMouseButton and event.pressed:
		var b := event as InputEventMouseButton
		if b.button_index == MOUSE_BUTTON_WHEEL_UP:
			_dist = maxf(_dist * 0.9, 0.15)
			_apply()
		elif b.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_dist = minf(_dist * 1.1, 5.0)
			_apply()


func _apply() -> void:
	pivot.rotation = Vector3(_rot.x, _rot.y, 0)
	cam.position = Vector3(0, 0, _dist)
