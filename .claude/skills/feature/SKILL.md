---
name: feature
description: Flujo completo para desarrollar una funcionalidad o tarea del backlog - aclarar requisitos, diseño, tareas técnicas, implementación con tests, assets, code review y verificación de QA. Úsalo cuando el usuario pida una nueva mecánica, sistema, pantalla o tarea T-NNN.
argument-hint: "[descripción de la feature o ID T-NNN]"
---

# Feature: $ARGUMENTS

## 1. Entender
- Si es un ID del backlog, léelo. Si es una petición nueva, comprueba si encaja en el GDD.
- Si hay ambigüedad que cambie el resultado (comportamiento, controles, alcance), pregunta con
  `AskUserQuestion` (opciones concretas). Si no, asume lo razonable y anótalo como supuesto.

## 2. Diseñar (solo si la feature es nueva o cambia el diseño)
- `game-designer`: sección en `docs/GDD.md` con reglas, parámetros, feedback y criterios de aceptación.
- `architect`: encaje técnico (escenas, señales, datos, ¿ADR?) y descomposición en tareas.
  Para features pequeñas que encajan claramente en la arquitectura existente, sáltate el architect y
  define tú la tarea.
- Añade las tareas a `docs/backlog.md` (estado `TODO`).

## 3. Implementar
- Lanza en paralelo lo independiente: p. ej. `gdscript-developer` (lógica + tests unitarios),
  `artist` (sprites), `audio-designer` (sfx), `ui-designer` (HUD/menú). Dales ámbitos de ficheros
  que no se solapen. Marca las tareas `IN_PROGRESS`.
- Código nativo solo con ADR → `rust-developer`.
- Cuando un desarrollador entregue, verifica su informe (ficheros, quality gate en verde).
  Si el gate falló tras los reintentos, devuelve la tarea con el detalle.

## 4. Revisar
- Si la tarea es `review: required` (o toca sistemas core, guardado, red o Rust): `code-reviewer`.
- `CHANGES_REQUESTED` → vuelve al desarrollador con los BLOCKER/MAJOR citados literalmente → nueva review.
- Marca `REVIEW` mientras tanto.

## 5. Verificar (QA)
- `qa-tester`: tests de integración del flujo y veredicto por criterio de aceptación.
- Bugs → `/bugfix` o devolver al desarrollador.

## 6. Cerrar
- Ejecuta `bash .claude/hooks/quality-gate.sh` tú mismo como comprobación final.
- Marca `DONE` en el backlog. Dile al usuario qué puede probar (`godot --path godot`, qué escena, qué
  controles) y qué queda pendiente.
