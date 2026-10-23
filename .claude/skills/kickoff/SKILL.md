---
name: kickoff
description: Arranca un videojuego nuevo de principio a fin - recogida de requisitos con el usuario, GDD, arquitectura, setup del proyecto Godot y backlog del primer hito jugable. Úsalo cuando el usuario quiera empezar un juego desde cero.
argument-hint: "[idea del juego en una frase]"
---

# Kickoff de un juego nuevo

Idea inicial del usuario: $ARGUMENTS

Sigue estas fases en orden. No pases a la siguiente sin cerrar la anterior.

## Fase 1 — Requisitos (tú, con AskUserQuestion)

Haz 2-3 tandas de preguntas con opciones (máx. 4 por tanda), adaptadas a la idea. Cubre:

1. **Concepto**: género, referencias ("como X pero con Y"), fantasía del jugador, perspectiva (2D lateral / top-down / isométrica / 3D).
2. **Alcance**: duración de una partida, tamaño del primer hito (prototipo / vertical slice / juego corto), plazo.
3. **Plataforma y control**: PC / web / móvil / consola; teclado+ratón / mando / táctil; resolución base.
4. **Estilo**: pixel art (tamaño de sprite 16/32/64), vectorial, low-poly; paleta o ambiente; tono.
5. **Audio**: chiptune / orgánico / mínimo.
6. **Sistemas**: guardado, progresión, multijugador (local/online — online multiplica el alcance, avísalo), localización.
7. **Restricciones**: rendimiento, accesibilidad, licencia, monetización (ninguna por defecto).

Escribe `docs/requirements.md` con: respuestas, supuestos (marcados `SUPUESTO`), fuera de alcance, y
preguntas abiertas. Enséñale al usuario el resumen en 5-8 líneas y confirma antes de seguir.

## Fase 2 — Diseño (game-designer)

Delega en `game-designer`: GDD en `docs/GDD.md` a partir de `docs/requirements.md`, con core loop,
mecánicas MVP con parámetros numéricos y criterios de aceptación jugables, y alcance por hitos.
Revisa el resultado; resume al usuario el core loop y el contenido del Hito 1 y pide confirmación.

## Fase 3 — Arquitectura y estilo (en paralelo)

Lanza en el mismo mensaje:
- `architect`: `docs/architecture.md`, ADRs iniciales (versión de Godot, estructura, guardado, ¿Rust? —
  por defecto NO salvo necesidad clara) y descomposición del Hito 1 en tareas.
- `artist`: `docs/art/style-guide.md` (paleta, tamaños, animaciones) + placeholders del Hito 1.
- `audio-designer`: `docs/audio/audio-guide.md` con la lista de eventos sonoros del Hito 1.
- `ui-designer`: `docs/ui/ui-spec.md` con flujo de pantallas del Hito 1 (menú, HUD, pausa, game over).

## Fase 4 — Setup técnico (build-engineer)

Delega en `build-engineer` la skill `godot-project-setup` (estructura, project.godot con input map y
resolución de la arquitectura, GUT, tools). Si hay ADR de Rust, también el workspace `rust/`.
Comprueba que `bash .claude/hooks/quality-gate.sh --all` pasa en el proyecto vacío.
Si faltan herramientas (Godot, gdtoolkit, Rust), dile al usuario exactamente qué instalar.

## Fase 5 — Backlog del Hito 1

Escribe `docs/backlog.md` integrando las tareas del architect (y de arte/audio/UI) con IDs `T-NNN`,
rol, dependencias, review y criterios de aceptación. Orden recomendado: core loop en gris primero
(jugador + mecánica principal + condición de victoria/derrota), luego arte/audio/UI encima.

## Cierre

Resume al usuario: qué existe, cómo abrir el proyecto (`godot --path godot -e`), el plan del Hito 1
y la primera tanda de tareas que vas a lanzar. Pregunta si arrancas la implementación (flujo `/feature`
por cada tarea o en lote).
