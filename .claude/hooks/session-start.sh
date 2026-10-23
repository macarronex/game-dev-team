#!/usr/bin/env bash
# SessionStart: tells the team which toolchain is available and where the project stands.
# Plain stdout is added to Claude's context.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
read_input

line() { printf '%s\n' "$1"; }
tool_status() {
  if have "$1"; then printf '%s ✓' "$1"; else printf '%s ✗' "$1"; fi
}

line "## Estado del entorno (hook SessionStart)"
godot="$(find_godot)"
if [[ -n "$godot" ]]; then
  ver="$("$godot" --version 2>/dev/null | head -n1)"
  line "- Godot: $godot (${ver:-versión desconocida})"
else
  line "- Godot: NO ENCONTRADO. Instálalo (4.3+) y define GODOT_BIN en .claude/settings.local.json. Sin Godot no hay tests, ni import, ni generación de sprites/sfx."
fi
line "- Herramientas: $(tool_status gdformat), $(tool_status gdlint), $(tool_status cargo), $(tool_status rustfmt), $(tool_status cargo-audit), $(tool_status git), $(tool_status jq)"

if [[ -f "$PROJECT_DIR/godot/project.godot" ]]; then
  name="$(grep -m1 '^config/name=' "$PROJECT_DIR/godot/project.godot" | cut -d= -f2-)"
  line "- Proyecto Godot: godot/project.godot ${name:+($name)}"
  [[ -d "$PROJECT_DIR/godot/addons/gut" ]] && line "- GUT instalado ✓" || line "- GUT no instalado ✗ (skill gut-testing)"
else
  line "- Proyecto Godot: aún no existe. Usa /kickoff para arrancar un juego nuevo."
fi
[[ -f "$PROJECT_DIR/rust/Cargo.toml" ]] && line "- Workspace Rust (GDExtension): rust/Cargo.toml"

if [[ -f "$PROJECT_DIR/docs/backlog.md" ]]; then
  todo=$(grep -cE '^\|[[:space:]]*T-[0-9]+.*\|[[:space:]]*(TODO|todo)[[:space:]]*\|' "$PROJECT_DIR/docs/backlog.md")
  prog=$(grep -cE '\|[[:space:]]*(IN_PROGRESS|in_progress)[[:space:]]*\|' "$PROJECT_DIR/docs/backlog.md")
  rev=$(grep -cE '\|[[:space:]]*(REVIEW|review)[[:space:]]*\|' "$PROJECT_DIR/docs/backlog.md")
  done_=$(grep -cE '\|[[:space:]]*(DONE|done)[[:space:]]*\|' "$PROJECT_DIR/docs/backlog.md")
  line "- Backlog (docs/backlog.md): TODO=$todo IN_PROGRESS=$prog REVIEW=$rev DONE=$done_"
fi
[[ -f "$PROJECT_DIR/docs/GDD.md" ]] && line "- GDD: docs/GDD.md"
[[ -f "$PROJECT_DIR/docs/architecture.md" ]] && line "- Arquitectura: docs/architecture.md"
exit 0
