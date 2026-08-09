extends ECSEntity
class_name DebugEntity

## An entity wrapper with additional component tracking for debugging purposes.
## Maintains a local dictionary of components for inspection without
## requiring access to the world entity component dictionary.

var _components: Dictionary[StringName, ECSComponent]
var _groups: Dictionary[StringName, bool]

## Adds a component instance and tracks it locally.
## @param component: The ECSComponent instance to add.
## @return: This ECSEntity for chaining.
## Usage: entity.add(CompHealth.new())
func add(component: ECSComponent) -> ECSEntity:
	var name := world().resolve_name(component.get_script() as GDScript)
	if not name.is_empty():
		_components[name] = component
	return super.add(component)

## Removes a component from this entity and stops tracking it.
## @param key: The component class (GDScript) to remove.
## @return: True if the component was successfully removed.
func remove(key: GDScript) -> bool:
	var name := world().resolve_name(key)
	if not name.is_empty():
		_components.erase(name)
	return super.remove(key)

## Removes all components from this entity and clears tracking.
## @return: True if all components were removed.
func remove_all() -> bool:
	_components.clear()
	return super.remove_all()
