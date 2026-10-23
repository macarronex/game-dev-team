extends GutTest
## Smoke test: verifies that GUT runs and that the EventBus autoload is registered.


func test_event_bus_autoload_exists() -> void:
	assert_not_null(
		get_tree().root.get_node_or_null(^"EventBus"), "EventBus autoload must be registered"
	)


func test_event_bus_emits_game_over() -> void:
	var bus: Node = get_tree().root.get_node(^"EventBus")
	watch_signals(bus)
	bus.game_over.emit(true)
	assert_signal_emitted_with_parameters(bus, "game_over", [true])
