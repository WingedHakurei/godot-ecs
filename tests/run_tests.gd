extends SceneTree

## godot-ecs headless test runner.
## Usage: godot --headless --path <project> --script res://tests/run_tests.gd

func _init() -> void:
	var suite := ECSTestSuite.new()
	suite.run()
	var stress := ECSSchedulerStressTest.new()
	stress.run()
	var failed: bool = suite._fail_count > 0 or stress._fail_count > 0
	quit(1 if failed else 0)
