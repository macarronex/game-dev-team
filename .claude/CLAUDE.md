# Game Dev Team — convenciones compartidas

Este repositorio lo desarrolla un equipo de agentes de Claude Code coordinado por el agente
`orchestrator` (agente principal, definido en `.claude/settings.json`). **Todos los agentes leen este
fichero**: aquí está el contrato común. Lo específico de cada rol está en `.claude/agents/<rol>.md`.

## Stack

- **Motor**: Godot 4 (4.3 o superior, se recomienda la última 4.x estable). Lenguaje principal: **GDScript con tipado estático**.
- **Código nativo**: solo cuando GDScript no basta (rendimiento medido, algoritmos pesados, librerías
  nativas). Siempre en **Rust** mediante GDExtension (`godot-rust/gdext`, crate `godot`). Nunca C++ ni C#
  salvo decisión explícita registrada en un ADR.
- **Tests**: GUT (Godot Unit Test) para GDScript, `cargo test` para Rust.
- **Lint/format**: gdtoolkit (`gdformat`, `gdlint`) y `cargo fmt` / `cargo clippy`.

## Estructura del repositorio

```
docs/                      Documentación viva (fuente de verdad entre agentes)
  requirements.md          Requisitos recogidos por el orquestador
  GDD.md                   Game Design Document (game-designer)
  architecture.md          Arquitectura (architect)
  adr/ADR-NNN-*.md         Decisiones de arquitectura
  backlog.md               Tareas, estados y responsables (orchestrator)
  art/style-guide.md       Guía de estilo visual y paleta (artist)
  audio/audio-guide.md     Guía de audio (audio-designer)
  ui/ui-spec.md            Flujos de pantallas y wireframes (ui-designer)
  qa/test-plan.md          Plan de pruebas y bugs (qa-tester)
  reviews/                 Informes de code review (code-reviewer)
godot/                     Proyecto Godot (project.godot)
  addons/                  Plugins de terceros (GUT...). No se modifican.
  assets/sprites|audio|fonts|ui/   Assets importables
  scenes/                  Escenas .tscn (organizadas por feature: player/, enemies/, levels/, ui/)
  src/                     Lógica GDScript
    autoload/              Singletons (EventBus, GameState, SaveSystem...)
    components/            Componentes reutilizables (HealthComponent, Hitbox...)
    systems/               Sistemas de juego (combate, inventario, spawn...)
    data/                  Resources tipados (class_name XxxData extends Resource)
    ui/                    Scripts de UI
  test/unit|integration/   Tests GUT: test_<script>.gd
  tools/                   Scripts headless del equipo (pixelart.gd, sfxgen.gd). Excluidos del export.
rust/                      Workspace Cargo de la GDExtension (fuera de godot/, como recomienda gdext)
art_src/                   Fuentes de arte/audio (specs JSON de sprites, SVG maestros, specs de sfx)
```

## Convenciones de código

- Identificadores, código y comentarios de código en **inglés**. Documentación en `docs/` y
  comunicación con el usuario en **español**.
- GDScript: sigue la skill `gdscript-conventions` (tipado estático obligatorio, `snake_case`,
  `PascalCase` para `class_name`, señales en pasado `health_changed`, nada de `get_node` con rutas
  frágiles: usa `@export` o `%UniqueName`).
- Arquitectura: composición sobre herencia, comunicación desacoplada vía señales / EventBus, datos de
  diseño en `Resource` tipados (`.tres`), nunca números mágicos de balance en el código.
- Rust: `cargo clippy -D warnings` limpio, sin `unwrap()` fuera de tests, `unsafe` solo con `// SAFETY:`.

## Definition of Done (la comprueba el quality gate automáticamente)

Una tarea de código solo está terminada si:
1. El proyecto importa en Godot sin errores de script ni de escena.
2. Cada script nuevo/modificado en `godot/src/` (excepto `src/ui/`) tiene `godot/test/**/test_<nombre>.gd`.
3. La suite GUT pasa. En Rust: fmt + clippy + test (+ audit si está instalado) en verde.
4. No hay secretos en el código ni patrones inseguros (deserialización con objetos, `OS.execute` con datos externos).
5. Los criterios de aceptación de la tarea en `docs/backlog.md` se cumplen.
6. `code-reviewer` ha aprobado (para tareas marcadas como `review: required`).

Los hooks de `.claude/hooks/` hacen cumplir 1-4: al terminar un subagente se ejecuta
`quality-gate.sh`, y si falla el agente recibe el informe y debe corregir antes de terminar.
Ejecución manual: `bash .claude/hooks/quality-gate.sh [--all]`.

## Protocolo de traspaso (handoff) entre agentes

Los subagentes no comparten contexto: **los ficheros de `docs/` son la memoria del equipo**.

- Al recibir una tarea: lee la tarea en `docs/backlog.md`, y los documentos que la tarea cite
  (GDD, arquitectura, ADRs, style guide). No inventes requisitos: si falta información, dilo en el informe.
- No toques ficheros fuera de tu ámbito (lo define tu rol y la tarea). Si hace falta, indícalo.
- Termina **siempre** con este informe (es lo que lee el orquestador):

```
## Informe de <rol> — <ID de tarea>
Estado: DONE | BLOCKED | PARTIAL
Resumen: <2-4 líneas>
Ficheros creados/modificados: <lista>
Verificación: <tests ejecutados, resultado del quality gate, capturas revisadas>
Decisiones tomadas: <y si requieren ADR>
Pendiente / riesgos: <lo que queda, dudas para el usuario>
Siguiente paso sugerido: <qué agente y qué tarea>
```

## Comandos útiles

```bash
godot --headless --path godot --import                       # importar / validar proyecto
godot --headless --path godot -s res://addons/gut/gut_cmdln.gd -gdir=res://test -ginclude_subdirs -gexit
godot --path godot                                           # ejecutar el juego
cd rust && cargo build && cargo test && cargo clippy --all-targets -- -D warnings
bash .claude/hooks/quality-gate.sh --all
```

Si `godot` no está en el PATH, el ejecutable se define en `GODOT_BIN` (en `.claude/settings.local.json`).
