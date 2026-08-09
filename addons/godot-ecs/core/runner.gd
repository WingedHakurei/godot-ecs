extends RefCounted
class_name ECSRunner

## A sequential system executor for single-threaded system updates.
## Provides system grouping and management similar to ECSScheduler but without parallel execution.
## Systems are keyed by their class (GDScript); only one instance per class is allowed.

var _world: ECSWorld
var _system_pool: Dictionary[GDScript, ECSSystem]

## Emitted each frame during run, used to trigger system execution.
## @param delta: The time elapsed since the last frame in seconds.
signal on_update(delta: float)

# ==============================================================================
# Public API - System Management
# ==============================================================================

## Adds a system to this runner, keyed by its class. Replaces any existing instance of the same class.
## @param system: The ECSSystem instance to add.
## @return: This runner instance for method chaining.
func add_system(system: ECSSystem) -> ECSRunner:
	var key := system.get_script() as GDScript
	remove_system(key)
	_system_pool[key] = system
	set_system_update(key, true)
	system._set_world(_world)
	system._set_runner(self)
	system.on_enter(_world)
	return self

## Adds multiple systems at once.
## @param systems: Array of ECSSystem instances to add.
## @return: This runner instance for method chaining.
func add_systems(systems: Array[ECSSystem]) -> ECSRunner:
	for system in systems:
		add_system(system)
	return self

## Removes a system by its class from this runner.
## @param key: The system class (GDScript) to remove.
## @return: True if the system was found and removed.
func remove_system(key: GDScript) -> bool:
	if not _system_pool.has(key):
		return false
	var system := _system_pool[key]
	if on_update.is_connected(system._on_update):
		on_update.disconnect(system._on_update)
	system.on_exit(_world)
	return _system_pool.erase(key)

## Clears all systems from this runner.
func clear() -> void:
	for key: GDScript in _system_pool.keys():
		remove_system(key)

## Retrieves a system by its class.
## @param key: The system class (GDScript) to get.
## @return: The ECSSystem instance, or null if not found.
func get_system(key: GDScript) -> ECSSystem:
	return _system_pool.get(key)

## Returns all systems in this runner.
## @return: Array of ECSSystem instances.
func get_systems() -> Array[ECSSystem]:
	var result: Array[ECSSystem] = []
	result.assign(_system_pool.values())
	return result

# ==============================================================================
# Public API - Update Control
# ==============================================================================

## Runs one frame of system execution for all enabled systems.
## Emits on_update signal to trigger all connected systems.
## @param delta: Time elapsed since last frame in seconds.
func run(delta: float) -> void:
	on_update.emit(delta)

## Enables or disables a system's update callback.
## Connects or disconnects system from the on_update signal.
## @param key: The system class (GDScript) to configure.
## @param enable: True to enable updates, false to disable.
func set_system_update(key: GDScript, enable: bool) -> void:
	var system := get_system(key)
	if system == null:
		return
	if enable:
		if not on_update.is_connected(system._on_update):
			on_update.connect(system._on_update)
	else:
		if on_update.is_connected(system._on_update):
			on_update.disconnect(system._on_update)

## Enables or disables all systems' update callbacks.
## @param enable: True to enable all updates, false to disable all.
func set_systems_update(enable: bool) -> void:
	for key: GDScript in _system_pool.keys():
		set_system_update(key, enable)

## Checks if a system's update callback is enabled.
## @param key: The system class (GDScript) to check.
## @return: True if the system's update callback is connected.
func is_system_updating(key: GDScript) -> bool:
	var system := get_system(key)
	if system == null:
		return false
	return on_update.is_connected(system._on_update)

# ==============================================================================
# Private Methods
# ==============================================================================

## Creates a new runner for the given world.
## @param world: The ECSWorld this runner belongs to.
func _init(world: ECSWorld) -> void:
	_world = world

## Returns a string representation of this runner.
## @return: String in the format "runner:<world_name>".
func _to_string() -> String:
	return "runner:%s" % _world.name()
