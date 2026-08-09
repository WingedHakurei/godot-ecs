# Agent Guidelines for Godot Light ECS

This document provides guidelines for AI agents working on this Godot ECS framework.

## Build, Test & Run

### Running the Project
- **Editor**: Open the project in Godot 4.7+ via `godot_mcp_launch_editor` or the Godot editor directly
- **Headless Testing**: Run `godot_mcp_run_project` with specific scene paths

### Running Tests
Tests are located in `addons/godot-ecs/core/`:
- **Full Test Suite**: `ECSTestSuite.new().run()` - Tests CRUD, queries, events, commands, scheduler, serialization
- **Scheduler Stress Test**: `ECSSchedulerStressTest.new().run()` - Tests dependency analysis, conflict resolution, cyclic detection

To run a single test:
```gdscript
var suite = ECSTestSuite.new()
suite._run_test("Test Name", suite._test_entity_component_crud)
suite.run()
```

Or call specific test methods directly:
```gdscript
var suite = ECSTestSuite.new()
suite._setup()
suite._test_entity_component_crud()
suite._teardown()
```

### Export
- Export presets are in `export_presets.cfg`
- Run Godot export via editor or CLI: `godot --export-release "Windows"`

## Code Style Guidelines

### File Organization
- One class per file (except inner test classes)
- Filename must match class name: `class_name ECSWorld` → `world.gd`
- Core framework in `addons/godot-ecs/core/`
- Utilities in `addons/godot-ecs/utils/`

### Class Declaration
```gdscript
extends RefCounted  # or Node, Serializer, etc.
class_name ECSWorld  # Required for all public classes
```

### Naming Conventions
- **Classes**: PascalCase (`ECSWorld`, `CompHealth`, `SysMovement`)
- **Methods/Variables**: snake_case (`entity_id`, `debug_print`, `multi_view`)
- **Private Members**: Leading underscore (`_name`, `_entity_pool`, `_on_update`)
- **Constants**: SCREAMING_SNAKE_CASE (`VERSION`, `READ_ONLY`, `READ_WRITE`)
- **Component/System identity**: component names are derived from `class_name` (GDScript class as the public key); `StringName` is the internal storage key

### Type Hints (Required)
- **Mandatory** explicit type annotations for parameters, return values, and variables — unless the type is auto-inferred by the engine (e.g., `:=` with an initializer, or a typed loop variable like `for c: ECSComponent in ...`)
- **Avoid `Variant`** as much as possible; prefer concrete types and typed containers (`Array[ECSComponent]`, `Dictionary[StringName, int]`)
- **Strengthen type constraints**: use `StringName` over `String` for identifiers, typed arrays/dictionaries over untyped ones, and `as T` casts where dynamic access is unavoidable
```gdscript
func name() -> StringName:
	return _name

func add_component(entity_id: int, component: ECSComponent) -> bool:

var healths: Array[ECSComponent] = world.view(CompHealth)
var views: Dictionary[StringName, ECSComponent]
var hp: CompHealth = e.getc(CompHealth) as CompHealth
```

### String Types
- Use `StringName` for keys, identifiers, and component names
- Use `String` for general text and formatting
```gdscript
var _name: StringName
var message: String = "entity created"
```

### Comments
- Use `##` for doc comments above functions/classes
- Use `#` for inline explanations
- Avoid redundant comments; code should be self-documenting

### Error Handling
- Use `assert()` for precondition validation and invariants
- Return `bool` to indicate success/failure
- Use `null` return for optional values
- Never silently ignore errors; log with `print_rich()` or `print()`

### Signal Patterns
- Define signals with typed parameters: `signal on_update(delta: float)`
- Connect/disconnect explicitly in lifecycle methods
- Use `weakref()` to avoid circular references with `WeakRef`

### Component Design
- Components extend `ECSComponent` (data-only; no `World`/`Entity`/system references)
- Component names derive from `class_name` (fallback: filename basename)
- Override `_on_pack(ar: Archive)` and `_on_unpack(ar: Archive)` for serialization
- Never store `World` or `Entity` references directly; use `WeakRef`

### System Design
- **Direct Mode**: Extend `ECSSystem` (Node) for single-threaded, stateful systems; override `_on_enter/_on_exit/_on_update`
- **Parallel Mode**: Extend `ECSParallel` for multi-threaded, stateless systems; `_list_components`/`_view_components` are `@abstract`
- Systems are keyed by class (GDScript); **only one instance per class** per runner/scheduler
- `_list_components() -> Dictionary[GDScript, int]` declares read/write access; use `_parallel() -> bool` to enable WorkerThreadPool
- Use `before(systems: Array[GDScript])`/`after(systems: Array[GDScript])` for explicit dependency declarations

### Query Patterns
```gdscript
# Single component view
var healths: Array[ECSComponent] = world.view(CompHealth)

# Multi-component AND query (cached; view dicts keyed by component class)
var results: Array[Dictionary] = world.multi_view([CompPos, CompVel])

# Complex queries with Querier
var query: Array[Dictionary] = world.query().with([CompHealth]).without([CompMana]).exec()
```

### Testing Patterns
- Use `ECSTestSuite` as base for test classes
- Helper method `_assert(condition: bool, msg: String)`
- Use `print_rich()` for colored test output: `[color=red][FAIL][/color]`
- Mock inner classes defined within test methods
- Always call `_setup()` before and `_teardown()` after tests

### Godot-Specific Patterns
- Use `Node` for systems that need child management (RPC support)
- Use `RefCounted` for pure data/logic classes
- Use `Callable` for callbacks and deferred execution
- Use `WorkerThreadPool` for parallel task distribution
- Use `Time.get_ticks_usec()` for microsecond timing

### Imports and Preloading
```gdscript
const Querier = preload("querier.gd")
const QueryCache = preload("query_cache.gd")
```

### Code Organization
- Group related functionality with `# ==============================================================================` separators
- Mark sections: `public`, `private`, `override`, `Test Cases`
- Keep `_init()` simple; defer complex setup
- Use `queue_free()` in `on_exit()` for Node-based systems

## Project Structure
```
addons/
  godot-ecs/           # Framework root
	core/              # ECS core
	  component.gd     # ECSComponent base
	  system.gd        # ECSSystem base (Node, direct mode)
	  parallel_system.gd  # ECSParallel base (@abstract)
	  world.gd         # ECSWorld entry point
	  entity.gd        # ECSEntity wrapper
	  querier.gd       # Query builder
	  query_cache.gd   # Cached multi-view results
	  scheduler.gd     # DAG-based scheduler
	  scheduler_commands.gd # Command buffer
	  runner.gd        # Sequential system executor
	  packer.gd        # World serialization
	  debug_entity.gd  # Debug entity wrapper
	  test_suite.gd    # Full test suite
	  test_scheduler.gd # Scheduler stress tests
	utils/             # Utilities
	  event.gd         # GameEvent
	  event_center.gd  # Event system
	  factory.gd       # Object factory (serialization)
	  packer.gd / pack.gd / byte_stream.gd
	  serialization/   # Archive/Serializer
demo/                # Examples
  sync/              # Direct mode (runner) examples
  async/             # Parallel mode (scheduler) examples
```

## Key Design Principles
1. **Zero GDExtension**: Pure GDScript for easy debugging
2. **Dual Mode**: Direct (main thread, `ECSSystem`) vs Parallel (worker threads, `ECSParallel`)
3. **Type-Safe Keys**: Public component/system keys are GDScript classes; `StringName` is internal
4. **DAG Scheduling**: Automatic dependency resolution
5. **O(1) Queries**: Cached query results via `QueryCache`
6. **Stateless Parallel**: Parallel systems must be pure functions
7. **Weak References**: Prevent memory leaks in component/entity
