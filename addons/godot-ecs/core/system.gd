extends Node
class_name ECSSystem

## A system class for processing component data on the main thread.
## Inherits from Node to utilize RPC functionality, which is essential for online games
## as it greatly simplifies the implementation of network synchronization.
## Systems can be added to the world and will receive update callbacks each frame.

var _name: StringName
var _world: ECSWorld
var _runner: ECSRunner

# ==============================================================================
# Public API - Identity & World
# ==============================================================================

## Returns the name identifier of this system.
## @return: The StringName identifier for this system.
func name() -> StringName:
	return _name

## Returns a reference to the ECSWorld this system belongs to.
## @return: The ECSWorld instance, or null if not attached to a world.
func world() -> ECSWorld:
	return _world

# ==============================================================================
# Public API - Query System
# ==============================================================================

## Queries entities with a specific component type.
## Emits on_system_viewed signal for tracking system access patterns.
## @param key: The component class (GDScript) to query.
## @return: Array of ECSComponent instances.
func view(key: GDScript) -> Array[ECSComponent]:
	_world.on_system_viewed.emit(self.name(), [key])
	return _world.view(key)

## Queries entities with multiple specified component types (AND logic).
## Emits on_system_viewed signal for tracking system access patterns.
## @param keys: Array of component classes (GDScript) to query.
## @return: Array of Dictionary views keyed by component class.
func multi_view(keys: Array[GDScript]) -> Array[Dictionary]:
	_world.on_system_viewed.emit(self.name(), keys)
	return _world.multi_view(keys)

## Gets or creates a cached query for multi-component queries.
## @param keys: Array of component classes (GDScript) to query.
## @return: QueryCache instance for the component combination.
func multi_view_cache(keys: Array[GDScript]) -> ECSWorld.QueryCache:
	return _world.multi_view_cache(keys)

## Creates a Querier for building complex entity queries with filters.
## @return: A new Querier instance configured with this system's world.
func query() -> ECSWorld.Querier:
	return _world.query()

# ==============================================================================
# Public API - Lifecycle Callbacks
# ==============================================================================

## Called when the system is added to the world.
## Triggers _on_enter override for system initialization.
## @param w: The ECSWorld this system is being added to.
func on_enter(w: ECSWorld) -> void:
	if w.debug_print:
		print("system <%s:%s> on_enter." % [world().name(), _name])
	_on_enter(w)

## Called when the system is removed from the world.
## Triggers _on_exit override for system cleanup and queues node for deletion.
## @param w: The ECSWorld this system is being removed from.
func on_exit(w: ECSWorld) -> void:
	if w.debug_print:
		print("system <%s:%s> on_exit." % [world().name(), _name])
	_on_exit(w)
	queue_free()

# ==============================================================================
# Public API - Event System
# ==============================================================================

## Sends a notification event to the world.
## @param event_name: The StringName identifier for the event.
## @param value: Optional value data to send with the event.
func notify(event_name: StringName, value: Variant = null) -> void:
	world().notify(event_name, value)

## Sends a GameEvent to the world.
## @param e: The GameEvent instance to dispatch.
func send(e: GameEvent) -> void:
	world().send(e)

# ==============================================================================
# Public API - Update Control
# ==============================================================================

## Enables or disables this system's update callback.
## Requires the system to be attached to a runner.
## @param enable: True to enable updates, false to disable.
func set_update(enable: bool) -> void:
	if _runner != null:
		_runner.set_system_update(get_script() as GDScript, enable)

## Checks if this system is currently connected to the update cycle.
## @return: True if the system's update callback is connected.
func is_updating() -> bool:
	if _runner == null:
		return false
	return _runner.is_system_updating(get_script() as GDScript)

# ==============================================================================
# Override Methods
# ==============================================================================

## Override: Called when the system is added to the world.
## Use for initializing system state and resources.
## @param w: The ECSWorld this system is being added to.
func _on_enter(w: ECSWorld) -> void:
	pass

## Override: Called when the system is removed from the world.
## Use for cleaning up resources and releasing references.
## @param w: The ECSWorld this system is being removed from.
func _on_exit(w: ECSWorld) -> void:
	pass

## Override: Called each frame when update cycle runs.
## Use for per-frame processing logic.
## @param _delta: The time elapsed since the last frame in seconds.
func _on_update(_delta: float) -> void:
	pass

# ==============================================================================
# Private Methods
# ==============================================================================

## Creates the system and optionally adds it as a child of a parent node.
## The display name is derived from the system class.
## @param parent: Optional parent Node to attach this system to.
func _init(parent: Node = null) -> void:
	if parent:
		parent.add_child(self)
	_name = _derive_name()
	set_name(_name)

## Internal: Derives a display name from the system class.
## @return: The derived StringName identifier.
func _derive_name() -> StringName:
	var script: GDScript = get_script() as GDScript
	if script == null:
		return &"System"
	var n: StringName = script.get_global_name()
	if not n.is_empty():
		return n
	var path: String = script.resource_path
	if not path.is_empty():
		return path.get_file().get_basename()
	return StringName("System_%d" % script.get_instance_id())

## Sets the world reference for this system.
## @param w: The ECSWorld instance to attach.
func _set_world(w: ECSWorld) -> void:
	_world = w

func _set_runner(runner: ECSRunner) -> void:
	_runner = runner

## Returns a string representation of this system.
## @return: String in the format "system:<name>".
func _to_string() -> String:
	return "system:%s" % _name
