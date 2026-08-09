extends Node2D

var _world := ECSWorld.new("AsyncDemo")
var _scheduler: ECSScheduler
var _step_count: int = 0

@onready var _label: Label = $StatusLabel

class DummyComp extends ECSComponent:
	var value: int = 0

class LightWorkSystem extends ECSParallel:
	func _parallel() -> bool:
		return false
	func _list_components() -> Dictionary[GDScript, int]:
		return { DummyComp: READ_ONLY }
	func _view_components(_view: Dictionary, _commands: Commands) -> void:
		pass

class HeavyWorkSystem extends ECSParallel:
	func _parallel() -> bool:
		return true
	func _list_components() -> Dictionary[GDScript, int]:
		return { DummyComp: READ_WRITE }
	func _view_components(view: Dictionary, _commands: Commands) -> void:
		(view[DummyComp] as DummyComp).value += 1

func _ready() -> void:
	_setup_world()
	_update_label()

func _setup_world() -> void:
	for i in 100:
		var e := _world.create_entity()
		e.add(DummyComp.new())
	_scheduler = _world.get_scheduler("demo")
	if _scheduler == null:
		_scheduler = _world.create_scheduler("demo").add_systems([
			LightWorkSystem.new().before([HeavyWorkSystem]),
			HeavyWorkSystem.new(),
		]).build()

func _step() -> void:
	_scheduler.run(0.016)
	_step_count += 1
	_update_label()

func _update_label() -> void:
	var comps: Array[ECSComponent] = _world.view(DummyComp)
	var total: int = 0
	for c in comps:
		total += (c as DummyComp).value
	_label.text = "Async Demo (Parallel Scheduler)\nEntities: %d\nTotal Value: %d\nSteps: %d\n(HeavyWorkSystem runs on WorkerThreadPool)" % [comps.size(), total, _step_count]
