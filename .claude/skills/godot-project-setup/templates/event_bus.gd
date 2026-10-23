extends Node
## Global event bus (autoload "EventBus").
## Only cross-system events live here; local communication uses each node's own signals.
## Add signals as the architecture requires them, always typed and in past tense.

@warning_ignore("unused_signal")
signal game_started

@warning_ignore("unused_signal")
signal game_paused(is_paused: bool)

@warning_ignore("unused_signal")
signal game_over(victory: bool)
