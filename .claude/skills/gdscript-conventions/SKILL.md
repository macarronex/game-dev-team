---
name: gdscript-conventions
description: Guía de estilo y buenas prácticas de GDScript para Godot 4 del equipo - tipado estático, orden del script, señales, nodos, Resources, rendimiento y patrones a evitar. Úsalo al escribir o revisar cualquier fichero .gd.
user-invocable: false
paths:
  - "**/*.gd"
---

# Convenciones GDScript (Godot 4)

Base: la guía oficial de estilo de GDScript, más estas reglas del equipo. `gdformat` formatea
(tabs) y `gdlint` + los warnings del proyecto (`untyped_declaration = error`) hacen cumplir buena parte.

## Tipado estático (obligatorio)

```gdscript
var speed: float = 200.0
var velocity_dir := Vector2.ZERO            # inferencia ok cuando el tipo es obvio
var enemies: Array[Enemy] = []
var stats: Dictionary[StringName, int] = {} # Godot 4.4+; si no, Dictionary y documenta el esquema
func take_damage(amount: int, source: Node2D = null) -> void:
func get_ratio() -> float:
for enemy: Enemy in enemies:
@onready var _sprite: AnimatedSprite2D = %Sprite
```

Nada de `Variant` implícito. Castea con `as` y comprueba nulo cuando venga de APIs genéricas.

## Orden dentro del script

1. `@tool`, `class_name`, `extends`, `## docstring`
2. `signal`s → `enum`s → `const`
3. `@export` (agrupados con `@export_group`) → variables públicas → privadas (`_prefijo`) → `@onready`
4. `_init`, `_enter_tree`, `_ready`, `_process`, `_physics_process`, `_unhandled_input`
5. Métodos públicos → métodos privados → callbacks de señales (`_on_<emisor>_<señal>`)

## Nombres

`snake_case` (ficheros, variables, funciones), `PascalCase` (`class_name`, nodos en escena),
`CONSTANT_CASE`, señales en pasado (`died`, `health_changed`), booleanos `is_/has_/can_`,
acciones de input en `snake_case` (`move_left`, `jump`). Usa `StringName` (`&"jump"`) para acciones y animaciones.

## Nodos y escenas

- Referencias a hijos con `%UniqueName` o `@export var target: Node2D`; nunca `get_node("../../X")`.
- **Call down, signal up**: el padre llama al hijo; el hijo emite señales. Eventos globales por `EventBus`.
- Conecta señales en código con callables: `health.died.connect(_on_health_died)`; desconecta si el emisor vive más que el receptor.
- `queue_free()` y después no uses la referencia; comprueba `is_instance_valid()` en callbacks diferidos/await.
- Instancia con `preload("res://...tscn")` para escenas usadas a menudo; `load` solo para contenido bajo demanda.

## Datos y configuración

- Parámetros de diseño en `@export` con rangos: `@export_range(0.0, 1000.0, 1.0, "suffix:px/s") var speed: float = 200.0`.
- Contenido (enemigos, armas, niveles) en `class_name XData extends Resource` + `.tres`. Nada de números mágicos de balance.
- Lógica pura en clases `RefCounted` sin dependencia del árbol de escenas → test unitario directo.

## Rendimiento

- `_physics_process` para movimiento/física, `_process` para visual; desactívalos (`set_process(false)`) cuando no hagan falta.
- Nada de `get_node`, `find_child`, `get_tree().get_nodes_in_group()` dentro de bucles por frame; cachea.
- Timers (`get_tree().create_timer`, nodo `Timer`) en vez de contadores manuales; `Tween` para interpolaciones.
- Pooling para proyectiles/partículas masivas. `PackedVector2Array`/`PackedFloat32Array` para datos numéricos grandes.

## Seguridad

- Guardado: `FileAccess` + JSON (o `ConfigFile`) en `user://`, con versión de esquema y validación de tipos/rangos al cargar.
- Prohibido: `bytes_to_var_with_objects`, `str_to_var` sobre datos externos, cargar `.tres/.res/.gd` desde `user://` o red (ejecutan código).
- Nunca construyas rutas con input del usuario sin sanear (`validate_filename()`), ni pases datos externos a `OS.execute`.

## Errores

- `push_error()` / `push_warning()` con contexto; `assert()` solo para invariantes de desarrollo (se elimina en release).
- Funciones que pueden fallar devuelven `Error` o `null` documentado; el llamador lo comprueba.

## Plantilla

```gdscript
class_name HealthComponent
extends Node
## Tracks hit points and emits events on damage, heal and death.

signal health_changed(current: int, maximum: int)
signal died

@export_range(1, 9999) var max_health: int = 100

var current_health: int:
	set(value):
		current_health = clampi(value, 0, max_health)
		health_changed.emit(current_health, max_health)

var is_dead: bool:
	get:
		return current_health <= 0


func _ready() -> void:
	current_health = max_health


func take_damage(amount: int) -> void:
	if is_dead or amount <= 0:
		return
	current_health -= amount
	if is_dead:
		died.emit()
```
