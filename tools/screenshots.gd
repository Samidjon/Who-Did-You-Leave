extends SceneTree
## Снимки экрана: godot --path . --script res://tools/screenshots.gd -- <папка>

func _initialize() -> void:
	var runner: Node = load("res://tools/shot_runner.gd").new()
	root.add_child.call_deferred(runner)
