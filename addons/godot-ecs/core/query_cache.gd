extends RefCounted

## Cached query results. A live array of view dictionaries keyed by component class;
## callers must not mutate its structure.
var results: Array[Dictionary]

var _signature: Array[StringName]
var _scripts: Array[GDScript]
var _entity_indices: Dictionary[int, int] = {}
var _world: ECSWorld

func _init(w: ECSWorld, sig: Array[StringName], scripts: Array[GDScript]) -> void:
	_world = w
	_signature.assign(sig)
	_scripts.assign(scripts)
	_rebuild_all()

func _rebuild_all() -> void:
	results.clear()
	_entity_indices.clear()
	var min_count: int = 2147483647
	var best_comp: StringName = _signature[0]
	for name in _signature:
		var count: int = _world._get_type_list(name).size()
		if count < min_count:
			min_count = count
			best_comp = name
	var type_list: Dictionary = _world._get_type_list(best_comp)
	for entity_id: int in type_list:
		if _match(entity_id):
			_add(entity_id)

func _match(entity_id: int) -> bool:
	for key in _scripts:
		if not _world.has_component(entity_id, key):
			return false
	return true

func _add(entity_id: int) -> void:
	if _entity_indices.has(entity_id):
		return
	var entity: ECSEntity = _world.get_entity(entity_id)
	var view_data: Dictionary = { "entity": entity }
	for i in _signature.size():
		view_data[_scripts[i]] = _world.get_component(entity_id, _scripts[i])
	results.append(view_data)
	_entity_indices[entity_id] = results.size() - 1

func _remove(entity_id: int) -> void:
	if not _entity_indices.has(entity_id):
		return
	var idx: int = _entity_indices[entity_id]
	var last_idx: int = results.size() - 1
	var last_item: Dictionary = results[last_idx]
	var last_entity: ECSEntity = last_item["entity"] as ECSEntity
	if idx != last_idx:
		results[idx] = last_item
		_entity_indices[last_entity.id()] = idx
	results.pop_back()
	_entity_indices.erase(entity_id)

func on_component_changed(entity_id: int, component_name: StringName, is_added: bool) -> void:
	if not component_name in _signature:
		return
	var in_cache: bool = _entity_indices.has(entity_id)
	if is_added:
		if not in_cache and _match(entity_id):
			_add(entity_id)
	else:
		if in_cache:
			_remove(entity_id)
