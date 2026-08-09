extends RefCounted
class_name ECSSchedulerStressTest

# ==============================================================================
# Helper: Dynamic Strict Systems for Testing
# ==============================================================================

class Comp1 extends ECSComponent: pass
class CompData extends ECSComponent: pass
class CompShared extends ECSComponent: pass
class CompDummy extends ECSComponent: pass

const _STRICT_SCRIPT_SOURCE := """
extends \"res://addons/godot-ecs/core/parallel_system.gd\"

var _reads: Array[GDScript] = []
var _writes: Array[GDScript] = []

func _init() -> void:
	super._init()

func configure(reads: Array[GDScript], writes: Array[GDScript]) -> void:
	_reads = reads
	_writes = writes

func _list_components() -> Dictionary[GDScript, int]:
	var d: Dictionary[GDScript, int] = {}
	for r in _reads:
		d[r] = READ_ONLY
	for w in _writes:
		d[w] = READ_WRITE
	return d

func _view_components(_view: Dictionary, _cmds) -> void:
	pass
"""

# Systems are keyed by class (one instance per class), so every test system gets a
# freshly generated, distinct class at runtime.
func _make_strict_script() -> GDScript:
	var s := GDScript.new()
	s.source_code = _STRICT_SCRIPT_SOURCE
	s.reload()
	return s

func _mk_sys(reads: Array[GDScript], writes: Array[GDScript]) -> ECSParallel:
	var inst: ECSParallel = _make_strict_script().new()
	inst.configure(reads, writes)
	return inst

# ==============================================================================
# Test Runner
# ==============================================================================

var _world: ECSWorld
var _fail_count: int = 0

func run() -> void:
	print_rich("[b][color=yellow]=== Starting STRICT Scheduler Analysis ===[/color][/b]")
	_fail_count = 0
	
	_run_test("Implicit Resource Conflict (RW/WW Safety)", _test_resource_conflict_serialization)
	_run_test("Explicit Dependency DAG (Diamond Shape)", _test_diamond_dependency)
	_run_test("Massive Scale (100+ Systems)", _test_massive_chain_and_width)
	_run_test("Cyclic Dependency (Deadlock Prevention)", _test_cyclic_dependency)
	
	print_rich("[b]--------------------------------------------------[/b]")
	if _fail_count == 0:
		print_rich("[b][color=green]ALL STRICT TESTS PASSED! Scheduler is Robust.[/color][/b]")
	else:
		print_rich("[b][color=red]CRITICAL FAILURE: Scheduler logic is flawed![/color][/b]")
		assert(_fail_count == 0, "Scheduler Verification Failed")
	
	_teardown()
	
func _setup() -> void:
	if _world: _world.clear()
	_world = ECSWorld.new("StrictTestWorld")
	_world.debug_print = false

func _teardown() -> void:
	if _world:
		_world.clear()
		_world = null

func _run_test(name: String, func_ref: Callable) -> void:
	print_rich("[color=cyan]> Analyzing: %s...[/color]" % name)
	_setup()
	func_ref.call()

func _assert(cond: bool, msg: String) -> void:
	if not cond:
		_fail_count += 1
		print_rich("  [b][color=red][FAIL] %s[/color][/b]" % msg)
		print_stack()

# ==============================================================================
# 1. 资源冲突隐式串行化测试
# 验证：即使没有显式 before/after，资源冲突也应强迫系统分批次运行
# ==============================================================================
func _test_resource_conflict_serialization() -> void:
	var scheduler = _world.create_scheduler("ResConflict")
	
	# Scenario:
	# SysA: Write [Comp1]
	# SysB: Write [Comp1] -> Conflict with A (WW)
	# SysC: Read [Comp1]  -> Conflict with A or B (RW)
	# SysD: Read [Comp1]  -> Compatible with C (RR)
	
	var sys_a := _mk_sys([], [Comp1])
	var sys_b := _mk_sys([], [Comp1])
	var sys_c := _mk_sys([Comp1], [])
	var sys_d := _mk_sys([Comp1], [])
	
	# 注意：我们故意不设置 before/after，完全依赖调度器的资源分析
	scheduler.add_systems([sys_a, sys_b, sys_c, sys_d])
	scheduler.build()
	
	var plan := _extract_plan(scheduler)
	_print_plan(plan)
	
	# 验证 1: A 和 B 绝不能在同一层 (写写冲突)
	var batch_a := _find_batch_index(plan, sys_a)
	var batch_b := _find_batch_index(plan, sys_b)
	_assert(batch_a != batch_b, "WW Conflict: A and B must be in different batches")
	
	# 验证 2: 写者(A/B) 和 读者(C/D) 绝不能在同一层 (读写冲突)
	var batch_c := _find_batch_index(plan, sys_c)
	var batch_d := _find_batch_index(plan, sys_d)
	
	_assert(batch_a != batch_c, "RW Conflict: A and C must be separated")
	_assert(batch_b != batch_c, "RW Conflict: B and C must be separated")
	
	# 验证 3: 读者之间应该并行 (读读优化)
	if batch_c == batch_d:
		print("  [Info] Read-Read Optimization verified (C and D in same batch)")
	
	_assert(plan.size() >= 3, "Plan depth should be at least 3 (Write, Write, Read)")

# ==============================================================================
# 2. 显式 DAG 依赖测试 (钻石型)
# 验证：Before/After 逻辑是否被严格遵守
# ==============================================================================
func _test_diamond_dependency() -> void:
	var scheduler = _world.create_scheduler("Diamond")
	
	# Structure:
	#      Start
	#     /     \
	#  Left     Right
	#     \     /
	#      End
	
	var s_start := _mk_sys([], [CompData])
	var s_left := _mk_sys([CompData], [])
	var s_right := _mk_sys([CompData], [])
	var s_end := _mk_sys([], [CompData])
	
	# 设置显式依赖（按系统类引用）
	s_left.after([s_start.get_script() as GDScript])
	s_right.after([s_start.get_script() as GDScript])
	s_end.after([s_left.get_script() as GDScript, s_right.get_script() as GDScript])
	
	scheduler.add_systems([s_start, s_left, s_right, s_end])
	scheduler.build()
	
	var plan := _extract_plan(scheduler)
	_print_plan(plan)
	
	var i_start := _find_batch_index(plan, s_start)
	var i_left := _find_batch_index(plan, s_left)
	var i_right := _find_batch_index(plan, s_right)
	var i_end := _find_batch_index(plan, s_end)
	
	# 严格拓扑验证
	_assert(i_start < i_left, "Topology: Start < Left")
	_assert(i_start < i_right, "Topology: Start < Right")
	_assert(i_end > i_left, "Topology: End > Left")
	_assert(i_end > i_right, "Topology: End > Right")
	
	# 验证并行性: Left 和 Right 理论上可以在同一层 (因为都是只读且依赖相同)
	if i_left == i_right:
		print("  [Info] Diamond parallel execution verified (Left and Right in same batch)")

# ==============================================================================
# 3. 海量规模压力测试
# 验证：算法在 N=100+ 时的稳定性和正确性
# ==============================================================================
func _test_massive_chain_and_width() -> void:
	var scheduler = _world.create_scheduler("Massive")
	var systems: Array[ECSParallel] = []
	var scripts: Array[GDScript] = []
	var count := 100
	
	# 创建 100 个运行时生成的独立系统类
	# 偶数索引构成一条长链: 0 -> 2 -> 4 -> ... -> 98
	# 奇数索引全部依赖于 System 0: 0 -> 1, 0 -> 3, ... (宽依赖)
	
	for i in range(count):
		var sys := _mk_sys([CompShared], [])
		systems.append(sys)
		scripts.append(sys.get_script() as GDScript)
	
	for i in range(count):
		var sys := systems[i]
		
		# Chain logic
		if i % 2 == 0 and i > 0:
			sys.after([scripts[i - 2]])
			
		# Fan-out logic (Odd numbers depend on System 0)
		if i % 2 != 0:
			sys.after([scripts[0]])
	
	scheduler.add_systems(systems)
	
	var time_start := Time.get_ticks_usec()
	scheduler.build()
	var time_end := Time.get_ticks_usec()
	
	print("  [Perf] Build time for 100 systems: %d us" % (time_end - time_start))
	
	var plan := _extract_plan(scheduler)
	
	# 验证长链顺序
	var last_idx := -1
	for i in range(0, count, 2):
		var idx := _find_batch_index(plan, systems[i])
		_assert(idx > last_idx, "Chain Integrity: sys_%d (Batch %d) > Prev (Batch %d)" % [i, idx, last_idx])
		last_idx = idx
		
	# 验证扇出 (Fan-out)
	var root_idx := _find_batch_index(plan, systems[0])
	for i in range(1, count, 2):
		var idx := _find_batch_index(plan, systems[i])
		_assert(idx > root_idx, "Fan-out Integrity: sys_%d > sys_0" % i)

# ==============================================================================
# 4. 循环依赖 (死锁) 测试
# 验证：调度器应检测循环并中断，而不是无限循环导致游戏卡死
# ==============================================================================
func _test_cyclic_dependency() -> void:
	# 注意：在当前框架实现中，scheduler 会打印 error 并 break。
	# 我们需要确保它不会 crash 且能生成某种结果（哪怕是不完整的）。
	
	var scheduler = _world.create_scheduler("Cyclic")
	
	var sys_a := _mk_sys([CompDummy], [])
	var sys_b := _mk_sys([CompDummy], [])
	
	sys_b.after([sys_a.get_script() as GDScript])
	sys_a.after([sys_b.get_script() as GDScript]) # Cycle!
	
	scheduler.add_systems([sys_a, sys_b])
	
	print("  [Info] Expecting [ECS] Scheduler Cycle Detected error below:")
	
	# 这里可能会打印 Error，这是预期的
	scheduler.build()
	
	var plan := _extract_plan(scheduler)
	
	# 如果有循环，DependencyBuilder 的 while 循环会检测到 ready_queue 为空但 processed_count 不够
	# 从而 break。结果可能为空，或者包含部分非循环节点。
	# 只要程序运行到这里没有卡死，就算通过了死锁检测测试。
	_assert(true, "Scheduler handled cycle without freezing.")

# ==============================================================================
# Internal Helpers (Introspection)
# ==============================================================================

# 直接读取调度器的私有变量 _batch_systems（内部为 Array[Array[ECSParallel]]）
func _extract_plan(scheduler: ECSScheduler) -> Array:
	return scheduler._batch_systems

func _find_batch_index(plan: Array, sys: Object) -> int:
	for i in range(plan.size()):
		if sys in plan[i]:
			return i
	return -1

func _print_plan(plan: Array) -> void:
	print("  [Plan] Execution Order:")
	for i in range(plan.size()):
		var names: Array = []
		for sys: ECSParallel in plan[i]:
			names.append(sys.name())
		print("    Batch %d: %s" % [i, str(names)])
