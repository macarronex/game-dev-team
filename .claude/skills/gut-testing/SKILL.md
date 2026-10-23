---
name: gut-testing
description: Cómo escribir y ejecutar tests unitarios y de integración con GUT (Godot Unit Test) en Godot 4 - estructura, asserts, señales, dobles, simulación de input y frames, y ejecución headless. Úsalo al crear o arreglar tests GDScript.
user-invocable: false
paths:
  - "godot/test/**"
---

# Testing con GUT (Godot 4, GUT 9.x)

## Estructura

```
godot/test/unit/<mismo árbol que src>/test_<script>.gd      # lógica aislada, rápida
godot/test/integration/test_<feature>.gd                    # escenas reales, input, señales
godot/.gutconfig.json                                       # config del runner
```

El quality gate exige `test_<nombre>.gd` para cada script de `godot/src/` (salvo `src/ui/`).

## Ejecutar

```bash
godot --headless --path godot --import          # primera vez / tras añadir class_name
godot --headless --path godot -s res://addons/gut/gut_cmdln.gd -gdir=res://test -ginclude_subdirs -gexit
# un fichero / un test:
godot --headless --path godot -s res://addons/gut/gut_cmdln.gd -gtest=res://test/unit/test_health_component.gd -gunit_test_name=test_dies -gexit
```

`.gutconfig.json` recomendado:
```json
{ "dirs": ["res://test/"], "include_subdirs": true, "prefix": "test_", "suffix": ".gd",
  "log_level": 1, "should_exit": true, "double_strategy": "SCRIPT_ONLY" }
```

## Plantilla de test unitario

```gdscript
extends GutTest

var _health: HealthComponent


func before_each() -> void:
	_health = HealthComponent.new()
	_health.max_health = 100
	add_child_autofree(_health)          # entra en el árbol -> se llama _ready(); se libera solo


func test_starts_at_max_health() -> void:
	assert_eq(_health.current_health, 100)


func test_damage_reduces_health() -> void:
	_health.take_damage(30)
	assert_eq(_health.current_health, 70, "30 damage from 100 should leave 70")


func test_emits_died_when_health_reaches_zero() -> void:
	watch_signals(_health)
	_health.take_damage(150)
	assert_signal_emitted(_health, "died")
	assert_eq(_health.current_health, 0, "health is clamped at 0")


func test_ignores_non_positive_damage() -> void:
	watch_signals(_health)
	_health.take_damage(0)
	_health.take_damage(-5)
	assert_signal_not_emitted(_health, "health_changed")


var damage_cases: Array = [[10, 90], [100, 0], [1, 99]]
func test_damage_table(params: Array = use_parameters(damage_cases)) -> void:
	_health.take_damage(params[0])
	assert_eq(_health.current_health, params[1])
```

## Asserts más usados

`assert_eq / assert_ne / assert_true / assert_false / assert_null / assert_not_null`,
`assert_almost_eq(got, expected, tolerance)` (floats y Vector2 — **nunca** `assert_eq` con floats calculados),
`assert_gt / assert_lt / assert_between`, `assert_has(array, value)`,
`assert_signal_emitted(obj, "sig")`, `assert_signal_emitted_with_parameters(obj, "sig", [args])`,
`assert_signal_emit_count(obj, "sig", n)`, `assert_called(double, "method")`, `assert_no_new_orphans()`.

## Integración: escenas, frames, input

```gdscript
const PlayerScene: PackedScene = preload("res://scenes/player/player.tscn")

func test_player_moves_right_with_input() -> void:
	var player: Player = add_child_autofree(PlayerScene.instantiate())
	var start_x: float = player.global_position.x
	Input.action_press(&"move_right")
	await wait_physics_frames(10)        # o wait_seconds(0.2)
	Input.action_release(&"move_right")
	assert_gt(player.global_position.x, start_x)

func test_enemy_dies_signal() -> void:
	var enemy: Enemy = add_child_autofree(EnemyScene.instantiate())
	watch_signals(enemy)
	enemy.health.take_damage(9999)
	await wait_for_signal(enemy.died, 1.0)
	assert_signal_emitted(enemy, "died")
```

- Avanzar lógica sin esperar tiempo real: `simulate(node, frames, delta)` llama a `_process`/`_physics_process`.
- Libera siempre `Input.action_release` / usa `after_each` para no contaminar otros tests.

## Dobles (mocks/stubs)

```gdscript
var audio = double(AudioManagerScript).new()        # doble parcial: partial_double(...)
stub(audio, "play_sfx").to_do_nothing()
system.audio = audio
system.jump()
assert_called(audio, "play_sfx", [&"jump"])
```

Para autoloads: inyecta la dependencia (propiedad o parámetro) en vez de acceder al singleton global, así se puede doblar.

## Reglas del equipo

- Un test = un comportamiento; nombre `test_<qué>_<cuando>` que se lea como especificación.
- Deterministas: `seed()` / `RandomNumberGenerator.seed` fijos; nada de depender del tiempo real salvo esperas acotadas.
- Sin huérfanos: `add_child_autofree`/`autofree`, y `assert_no_new_orphans()` en tests de escenas.
- Bugs: `test_bug_NNN_<resumen>.gd` que falla antes del fix.
- Instalación de GUT: ver skill `godot-project-setup` (addon en `godot/addons/gut`, plugin habilitado).
