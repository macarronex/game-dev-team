# Equipo multiagente de desarrollo de videojuegos (Godot 4 + GDScript + Rust)

## Uso

```bash
claude                 # arranca con el agente "orchestrator" como principal (settings.json → "agent")
/kickoff un roguelike de mazmorras pixel art para PC
/feature T-004
/bugfix el jugador atraviesa las paredes al hacer dash
/quality-gate
```

Para hablar directamente con un especialista: `claude --agent gdscript-developer` (pon
`GAMEDEV_ENFORCE_DELEGATION=0` si quieres que el agente principal pueda editar código).

## Requisitos de la máquina

| Herramienta | Para qué | Obligatoria |
|---|---|---|
| Git for Windows (Git Bash) | Ejecuta los hooks | Sí |
| Godot 4.3+ (usa el ejecutable `_console.exe` en Windows) | Import, tests, generación de sprites y sfx | Sí |
| Python 3 + `pip install "gdtoolkit==4.*"` | `gdformat` / `gdlint` | Recomendada |
| Rust (rustup) + `cargo install cargo-audit` | GDExtension | Solo si se usa Rust |
| jq | Parseo JSON más robusto en los hooks | Opcional |

Si `godot` no está en el PATH: copia `settings.local.example.json` a `settings.local.json` y ajusta `GODOT_BIN`.

## Contenido

```
.claude/
  settings.json          agente principal, permisos, variables y hooks
  CLAUDE.md              contrato común: stack, estructura, Definition of Done, protocolo de handoff
  agents/                orchestrator + 10 especialistas
  skills/                flujos (/kickoff, /feature, /bugfix, /quality-gate) y conocimiento técnico
  hooks/                 guardas y quality gate (bash, sin dependencias)
```

### Agentes

| Agente | Modelo | Rol |
|---|---|---|
| orchestrator | opus | Recoge requisitos, mantiene el backlog, delega y verifica (no implementa) |
| game-designer | opus | GDD, mecánicas con números, criterios de aceptación jugables |
| architect | opus | Arquitectura Godot, ADRs, decide GDScript vs Rust, descompone en tareas |
| gdscript-developer | sonnet | Gameplay y sistemas + tests GUT (TDD) |
| rust-developer | sonnet | GDExtension con gdext (solo con ADR) |
| ui-designer | sonnet | Spec de UI, Theme, implementación con Control, navegación con mando |
| artist | sonnet | Style guide, pixel art (JSON → PNG + SpriteFrames) y SVG |
| audio-designer | sonnet | SFX procedurales (JSON → WAV), buses, guía de audio |
| qa-tester | sonnet | Plan de pruebas, tests de integración, bugs con test que falla |
| code-reviewer | opus | Revisión de corrección, arquitectura, rendimiento y seguridad (solo lectura) |
| build-engineer | sonnet | Setup, GUT, export presets, CI |

### Hooks

| Hook | Evento | Qué hace |
|---|---|---|
| `session-start.sh` | SessionStart | Informa de herramientas disponibles y estado del backlog |
| `guard-bash.sh` | PreToolUse Bash | Bloquea borrados masivos, `push --force`, `reset --hard`, `curl \| sh`, lectura de secretos, volcado de entorno, publicación de paquetes |
| `guard-files.sh` | PreToolUse Write/Edit | Protege `.godot/`, `target/`, `.git`, ficheros de secretos; pide confirmación al tocar hooks/settings; obliga al orquestador a delegar; detecta secretos hard-codeados |
| `post-edit-check.sh` | PostToolUse Write/Edit | gdformat/gdlint, tipado estático, rutas `res://` existentes, coherencia de `.tscn/.tres`, rustfmt, `unwrap`/`unsafe`, aviso de test ausente |
| `quality-gate.sh` | Stop / SubagentStop | Import de Godot, gdlint, test obligatorio por script de lógica, suite GUT, cargo fmt/clippy/test/audit, patrones inseguros. Si falla, el agente no puede terminar (máx. 3 reintentos) |

Variables (en `settings.json` → `env`): `GAMEDEV_ENFORCE_DELEGATION`, `GAMEDEV_REQUIRE_TESTS`,
`GAMEDEV_TEST_EXEMPT` (regex de rutas exentas de test), `GAMEDEV_GATE_MAX_BLOCKS`,
`CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH=1` (solo el orquestador lanza subagentes).
