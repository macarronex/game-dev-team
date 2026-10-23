---
name: quality-gate
description: Ejecuta todas las comprobaciones de calidad del proyecto (import de Godot, gdlint, tests GUT, cobertura mínima de tests, cargo fmt/clippy/test/audit y patrones de seguridad) y resume el estado. Úsalo antes de cerrar un hito o cuando el usuario pida el estado de calidad.
argument-hint: "[--all]"
allowed-tools: Bash(bash .claude/hooks/quality-gate.sh *)
---

# Quality gate

Ejecuta:

```bash
bash .claude/hooks/quality-gate.sh --all
```

(Usa el argumento recibido si es distinto: `$ARGUMENTS`. Sin `--all` solo comprueba lo cambiado
desde el último gate en verde.)

Después:
1. Resume en una tabla: comprobación → ✓ / ! / ✗.
2. Para cada ✗, identifica el rol responsable (por ruta del fichero) y propone la tarea de corrección.
3. Para cada `!` (herramienta no instalada), indica al usuario el comando exacto de instalación:
   - Godot 4: descarga oficial desde https://godotengine.org/download y `GODOT_BIN` en `.claude/settings.local.json`.
   - gdtoolkit: `pip install "gdtoolkit==4.*"` (requiere Python 3).
   - Rust: https://rustup.rs → `rustup component add clippy rustfmt` → `cargo install cargo-audit`.
4. Si el usuario lo aprueba, crea las tareas en `docs/backlog.md` y delega las correcciones.
