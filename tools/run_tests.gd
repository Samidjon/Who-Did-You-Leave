extends SceneTree
## Запуск автотестов: godot --headless --path . --script res://tools/run_tests.gd
## Сам тест (tools/test_runner.gd) загружается после регистрации автозагрузок.


func _initialize() -> void:
	var runner: Node = load("res://tools/test_runner.gd").new()
	runner.name = "TestRunner"
	root.add_child.call_deferred(runner)
