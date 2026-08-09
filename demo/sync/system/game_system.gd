extends ECSSystem

# override
func _on_enter(w: ECSWorld) -> void:
	# init
	_init_entity()
	
	# add system (same runner as this system)
	var runner := w.get_runner("main")
	runner.add_system(preload("my_system.gd").new(self))
	runner.add_system(preload("save_system.gd").new(self))
	
	# debug print on
	w.debug_print = true
	w.debug_entity = true
	
# override
func _on_exit(w: ECSWorld) -> void:
	# free (runner cleanup handles sub-system removal)
	_free_entity()
	
func _init_entity():
	# create entity
	var e = world().create_entity()
	# add component
	e.add(PlayerUnit.new())
	e.add(MyComponent.new())
	
func _free_entity():
	world().remove_all_entities()
	
