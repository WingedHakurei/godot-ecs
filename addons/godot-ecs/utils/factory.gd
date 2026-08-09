extends RefCounted
class_name ObjectFactory

## Factory for creating object instances with optional initialization parameters.
## Supports both global classes and inner classes with UID-based type resolution.

var _inner_type: Dictionary[int, Resource]
var _inner_creater: Dictionary[int, Callable]

# ==============================================================================
# Public API - Registration
# ==============================================================================

## Registers a class type with optional initialization parameters.
## @param class_type: The Resource (script) to register.
## @param init_params: Optional array of parameters for the constructor.
func register(class_type: Resource, init_params := []) -> void:
	_register(class_type, init_params)

# ==============================================================================
# Public API - UID Conversion
# ==============================================================================

## Converts an object instance to its type UID.
## @param object: The object instance to get UID for.
## @return: The integer UID identifying the object's type.
func object_to_uid(object: Object) -> int:
	return _object_to_uid(object)

## Retrieves an object instance from its type UID.
## @param uid: The integer UID of the type to create.
## @return: A new instance of the type identified by the UID.
func uid_to_object(uid: int) -> Object:
	return _uid_to_object(uid)

# ==============================================================================
# Private Methods - Registration
# ==============================================================================

## Internal: Registers a class with factory.
## @param class_type: The Resource to register.
## @param init_params: Parameters for the constructor.
func _register(class_type: Resource, init_params: Array) -> void:
	var uid := _get_class_uid(class_type)
	_inner_type[uid] = class_type
	_inner_creater[uid] = _get_class_creater(uid, init_params)

# ==============================================================================
# Private Methods - UID Conversion
# ==============================================================================

## Internal: Converts object to type UID.
## @param object: The object instance.
## @return: The type UID.
func _object_to_uid(object: Object) -> int:
	return _resolve_script_uid(object.get_script())

## Internal: Creates instance from type UID.
## @param uid: The type UID.
## @return: A new instance, or null if the UID cannot be resolved.
func _uid_to_object(uid: int) -> Object:
	var creater := _inner_creater[uid] if _inner_creater.has(uid) else null
	if creater == null:
		var path := ResourceUID.id_to_text(uid)
		if not path.is_empty() and ResourceLoader.exists(path):
			return load(path).new()
		var res_path := _find_path_by_uid(uid)
		if not res_path.is_empty():
			return load(res_path).new()
		push_error("[ECS] ObjectFactory: cannot resolve uid<%s>!" % path)
		return null
	return creater.call()

## Internal: Gets a stable type UID for a class type.
## Uses the script's real resource UID when it has a path; otherwise falls back
## to its instance id (stable within a run, used for inner/path-less classes).
## @param type: The Resource to get UID for.
## @return: The type UID.
func _get_class_uid(type: Resource) -> int:
	return _resolve_script_uid(type)

## Internal: Resolves a stable UID for a script.
## Priority: resource UID cache → the script's `.uid` file (when the cache is
## stale or the project was never imported) → instance id (within-run stable).
## @param script: The script resource to resolve.
## @return: The resolved type UID.
func _resolve_script_uid(script: Resource) -> int:
	var path: String = script.resource_path
	if path.is_empty():
		return script.get_instance_id()
	var uid := ResourceLoader.get_resource_uid(path)
	if uid != -1:
		return uid
	var uid_path := path + ".uid"
	if FileAccess.file_exists(uid_path):
		var f := FileAccess.open(uid_path, FileAccess.READ)
		if f:
			var text := f.get_as_text().strip_edges()
			f.close()
			var id := ResourceUID.text_to_id(text)
			if id != -1:
				return id
	return script.get_instance_id()

## Internal: Finds a res path whose `.uid` file matches the given UID.
## Used as a fallback when the resource UID cache is stale or unavailable.
## @param uid: The type UID to look up.
## @return: The matching res path (without the `.uid` suffix), or empty string.
func _find_path_by_uid(uid: int) -> String:
	var target: String = ResourceUID.id_to_text(uid)
	if target.is_empty():
		return ""
	var dirs: Array[String] = ["res://"]
	while not dirs.is_empty():
		var d: String = dirs.pop_back()
		var dir := DirAccess.open(d)
		if dir == null:
			continue
		dir.list_dir_begin()
		var f: String = dir.get_next()
		while not f.is_empty():
			if dir.current_is_dir():
				if f != "." and f != ".." and f != ".godot":
					dirs.append(d + f + "/")
			elif f.ends_with(".uid"):
				var fh := FileAccess.open(d + f, FileAccess.READ)
				if fh:
					var text := fh.get_as_text().strip_edges()
					fh.close()
					if text == target:
						return (d + f).trim_suffix(".uid")
			f = dir.get_next()
		dir.list_dir_end()
	return ""

## Internal: Creates a callable constructor with parameters.
## @param uid: The type UID.
## @param init_params: Constructor parameters.
## @return: Callable that creates a new instance.
func _get_class_creater(uid: int, init_params: Array) -> Callable:
	match init_params.size():
		0:
			return (func(inner_type: Dictionary[int, Resource], uid: int) -> Object:
				return inner_type[uid].new()
			).bind(_inner_type, uid)
		1:
			return (func(inner_type: Dictionary[int, Resource], uid: int, v1: Variant) -> Object:
				return inner_type[uid].new(v1)
			).bind(_inner_type, uid, init_params[0])
		2:
			return (func(inner_type: Dictionary[int, Resource], uid: int, v1: Variant, v2: Variant) -> Object:
				return inner_type[uid].new(v1, v2)
			).bind(_inner_type, uid, init_params[0], init_params[1])
		3:
			return (func(inner_type: Dictionary[int, Resource], uid: int, v1: Variant, v2: Variant, v3: Variant) -> Object:
				return inner_type[uid].new(v1, v2, v3)
			).bind(_inner_type, uid, init_params[0], init_params[1], init_params[2])
		4:
			return (func(inner_type: Dictionary[int, Resource], uid: int, v1: Variant, v2: Variant, v3: Variant, v4: Variant) -> Object:
				return inner_type[uid].new(v1, v2, v3, v4)
			).bind(_inner_type, uid, init_params[0], init_params[1], init_params[2], init_params[3])
		5:
			return (func(inner_type: Dictionary[int, Resource], uid: int, v1: Variant, v2: Variant, v3: Variant, v4: Variant, v5: Variant) -> Object:
				return inner_type[uid].new(v1, v2, v3, v4, v5)
			).bind(_inner_type, uid, init_params[0], init_params[1], init_params[2], init_params[3], init_params[4])
	return Callable()
