extends RefCounted

const Querier = preload("querier.gd")

# ==============================================================================
# public

func with(keys: Array[GDScript]) -> Querier:
	_with_keys.clear()
	for key in keys:
		if _is_valid(key):
			_with_keys.append(key)
	return self

func without(keys: Array[GDScript]) -> Querier:
	_without_keys.clear()
	for key in keys:
		if _is_valid(key):
			_without_keys.append(key)
	return self

func any_of(keys: Array[GDScript]) -> Querier:
	_any_keys.clear()
	for key in keys:
		if _is_valid(key):
			_any_keys.append(key)
	return self

func filter(predicate: Callable) -> Querier:
	_custom_filter = predicate
	return self

func exec() -> Array[Dictionary]:
	if not _with_keys.is_empty():
		var result: Array[Dictionary] = []
		result.assign(_world.multi_view(_with_keys).filter(_internal_filter))
		return result
	if not _any_keys.is_empty():
		return _exec_union_query()
	return []

# ==============================================================================
# private

var _world: ECSWorld
var _with_keys: Array[GDScript] = []
var _without_keys: Array[GDScript] = []
var _any_keys: Array[GDScript] = []
var _custom_filter: Callable

func _init(w: ECSWorld) -> void:
	_world = w

func _is_valid(key: GDScript) -> bool:
	return not _world.resolve_name(key).is_empty()

func _internal_filter(view_data: Dictionary) -> bool:
	var entity_id: int = (view_data["entity"] as ECSEntity).id()
	if not _without_keys.is_empty():
		for key in _without_keys:
			if _world.has_component(entity_id, key):
				return false
	if not _any_keys.is_empty():
		var has_any := false
		for key in _any_keys:
			if _world.has_component(entity_id, key):
				has_any = true
				break
		if not has_any:
			return false
	if _custom_filter.is_valid():
		return _custom_filter.call(view_data)
	return true

func _exec_union_query() -> Array[Dictionary]:
	var result_map: Dictionary = {}
	for key in _any_keys:
		var name := _world.resolve_name(key)
		var type_list: Dictionary = _world._get_type_list(name)
		for entity_id: int in type_list:
			if result_map.has(entity_id):
				continue
			if not _check_without(entity_id):
				continue
			var e: ECSEntity = _world.get_entity(entity_id)
			var data: Dictionary = { "entity": e }
			for k in _any_keys:
				data[k] = _world.get_component(entity_id, k)
			if _custom_filter.is_valid() and not _custom_filter.call(data):
				continue
			result_map[entity_id] = data
	var result: Array[Dictionary] = []
	result.assign(result_map.values())
	return result

func _check_without(entity_id: int) -> bool:
	if _without_keys.is_empty():
		return true
	for key in _without_keys:
		if _world.has_component(entity_id, key):
			return false
	return true
