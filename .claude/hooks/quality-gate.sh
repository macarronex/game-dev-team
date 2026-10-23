#!/usr/bin/env bash
# Quality gate for the game-dev team.
#
#   bash .claude/hooks/quality-gate.sh            # manual: checks files changed since last green gate
#   bash .claude/hooks/quality-gate.sh --all      # manual: checks everything
#   bash .claude/hooks/quality-gate.sh --hook     # Stop/SubagentStop hook (reads JSON on stdin)
#
# Checks (each one is skipped if its tool is not installed, with a warning):
#   Godot  : project import without script/scene errors      (godot --headless --import)
#   GDScript: gdlint on changed scripts, unit test exists for logic scripts, GUT suite passes
#   Rust   : cargo fmt --check, cargo clippy -D warnings, cargo test, cargo audit
#   Security: risky API patterns in changed code
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

MODE="manual"; ALL=0
for a in "$@"; do
  case "$a" in
    --hook) MODE="hook" ;;
    --all) ALL=1 ;;
  esac
done

if [[ "$MODE" == "hook" ]]; then
  read_input
  event="$(json_get hook_event_name)"
  agent_type="$(json_get agent_type)"
  agent_id="$(json_get agent_id)"
  # Read-only / document-only roles are never blamed for others' code.
  case "$agent_type" in
    code-reviewer|architect|game-designer|Explore|Plan|claude-code-guide|statusline-setup) exit 0 ;;
  esac
  [[ "$event" == "Stop" ]] && agent_id="main"
  COUNTER_FILE="$STATE_DIR/gate-blocks-${agent_id:-main}"
fi

GODOT_ROOT="$PROJECT_DIR/godot"
RUST_ROOT="$PROJECT_DIR/rust"
MARKER="$STATE_DIR/last-gate-ok"
RUN_MARKER="$STATE_DIR/gate-run-$$"
touch "$RUN_MARKER"
trap 'rm -f "$RUN_MARKER"' EXIT

newer=()
if [[ $ALL -eq 0 && -f "$MARKER" ]]; then newer=(-newer "$MARKER"); fi

changed_gd=(); changed_rs=(); changed_res=()
if [[ -d "$GODOT_ROOT" ]]; then
  while IFS= read -r f; do changed_gd+=("$f"); done < <(
    find "$GODOT_ROOT" \( -path "$GODOT_ROOT/.godot" -o -path "$GODOT_ROOT/addons" \) -prune -o \
      -type f -name '*.gd' "${newer[@]}" -print 2>/dev/null)
  while IFS= read -r f; do changed_res+=("$f"); done < <(
    find "$GODOT_ROOT" \( -path "$GODOT_ROOT/.godot" -o -path "$GODOT_ROOT/addons" \) -prune -o \
      -type f \( -name '*.tscn' -o -name '*.tres' -o -name '*.png' -o -name '*.svg' -o -name '*.wav' -o -name '*.ogg' -o -name 'project.godot' \) \
      "${newer[@]}" -print 2>/dev/null)
fi
if [[ -d "$RUST_ROOT" ]]; then
  while IFS= read -r f; do changed_rs+=("$f"); done < <(
    find "$RUST_ROOT" -path "$RUST_ROOT/target" -prune -o -type f \( -name '*.rs' -o -name 'Cargo.toml' -o -name 'Cargo.lock' \) \
      "${newer[@]}" -print 2>/dev/null)
fi

if [[ ${#changed_gd[@]} -eq 0 && ${#changed_rs[@]} -eq 0 && ${#changed_res[@]} -eq 0 ]]; then
  [[ "$MODE" == "manual" ]] && echo "Quality gate: no hay cambios desde el último gate en verde (usa --all para forzar)."
  exit 0
fi

failures=""; warnings=""; passed=""
fail() { failures+="✗ $1"$'\n'; }
warn() { warnings+="! $1"$'\n'; }
ok()   { passed+="✓ $1"$'\n'; }
relp() { printf '%s' "${1#$PROJECT_DIR/}"; }

godot="$(find_godot)"

# ---------------------------------------------------------------- Godot / GDScript
if [[ ${#changed_gd[@]} -gt 0 || ${#changed_res[@]} -gt 0 ]]; then
  if [[ -n "$godot" && -f "$GODOT_ROOT/project.godot" ]]; then
    out="$("$godot" --headless --path "$GODOT_ROOT" --import 2>&1)"
    errs="$(printf '%s' "$out" | grep -E 'SCRIPT ERROR|Parse Error|ERROR: Failed to load|ERROR: Cannot|ERROR: Resource file not found|Failed loading resource' | sort -u | head -n 25)"
    if [[ -n "$errs" ]]; then fail "Godot import con errores:"$'\n'"$errs"; else ok "Godot import sin errores"; fi
  elif [[ -f "$GODOT_ROOT/project.godot" ]]; then
    warn "Godot no encontrado (define GODOT_BIN en .claude/settings.local.json). No se han podido validar escenas ni ejecutar tests."
  fi
fi

if [[ ${#changed_gd[@]} -gt 0 ]]; then
  if have gdlint; then
    out="$(gdlint "${changed_gd[@]}" 2>&1)" && ok "gdlint (${#changed_gd[@]} ficheros)" || fail "gdlint:"$'\n'"$(printf '%s' "$out" | head -n 30)"
  else
    warn "gdlint no instalado (pip install gdtoolkit==4.*): estilo GDScript sin verificar."
  fi

  if [[ "${GAMEDEV_REQUIRE_TESTS:-1}" == "1" ]]; then
    missing=""
    for f in "${changed_gd[@]}"; do
      r="$(relp "$f")"
      [[ "$r" == godot/src/* ]] || continue
      [[ "$r" =~ ${GAMEDEV_TEST_EXEMPT:-^$} ]] && continue
      base="$(basename "$f" .gd)"
      [[ -n "$(find "$GODOT_ROOT/test" -name "test_${base}.gd" 2>/dev/null | head -n1)" ]] || missing+="  $r -> falta godot/test/unit/**/test_${base}.gd"$'\n'
    done
    if [[ -n "$missing" ]]; then fail "Scripts de lógica sin test unitario GUT:"$'\n'"$missing"; else ok "Cobertura mínima: cada script de lógica tiene su test"; fi
  fi
fi

if [[ -d "$GODOT_ROOT/addons/gut" && -d "$GODOT_ROOT/test" && ( ${#changed_gd[@]} -gt 0 || ${#changed_res[@]} -gt 0 ) ]]; then
  if [[ -n "$godot" ]]; then
    out="$("$godot" --headless --path "$GODOT_ROOT" -s res://addons/gut/gut_cmdln.gd \
      -gdir=res://test -ginclude_subdirs -gprefix=test_ -gexit 2>&1)"
    code=$?
    summary="$(printf '%s' "$out" | grep -E 'Passing|Failing|Pending|Risky|Asserts|Tests|---- Totals|\[Failed\]|FAILED|Error' | tail -n 25)"
    if [[ $code -ne 0 ]] || printf '%s' "$out" | grep -qE '\[Failed\]|Failing Tests'; then
      fail "Tests GUT fallando (código $code):"$'\n'"$summary"
    else
      ok "Tests GUT en verde"
    fi
  fi
elif [[ ${#changed_gd[@]} -gt 0 && -f "$GODOT_ROOT/project.godot" ]]; then
  warn "GUT no instalado en godot/addons/gut: no se han ejecutado tests (ver skill gut-testing)."
fi

# ---------------------------------------------------------------- Rust
if [[ ${#changed_rs[@]} -gt 0 && -f "$RUST_ROOT/Cargo.toml" ]]; then
  if have cargo; then
    pushd "$RUST_ROOT" >/dev/null || exit 0
    out="$(cargo fmt --all -- --check 2>&1)" && ok "cargo fmt" || fail "cargo fmt --check (ejecuta 'cargo fmt --all'):"$'\n'"$(printf '%s' "$out" | head -n 20)"
    out="$(cargo clippy --all-targets --quiet -- -D warnings 2>&1)" && ok "cargo clippy" || fail "cargo clippy -D warnings:"$'\n'"$(printf '%s' "$out" | grep -E '^(error|warning)|-->' | head -n 30)"
    out="$(cargo test --quiet 2>&1)" && ok "cargo test" || fail "cargo test:"$'\n'"$(printf '%s' "$out" | tail -n 30)"
    if have cargo-audit; then
      out="$(cargo audit -q 2>&1)" && ok "cargo audit" || fail "cargo audit (dependencias con vulnerabilidades):"$'\n'"$(printf '%s' "$out" | head -n 20)"
    else
      warn "cargo-audit no instalado (cargo install cargo-audit): dependencias Rust sin auditar."
    fi
    popd >/dev/null || true
  else
    warn "cargo no encontrado: código Rust sin compilar ni testear."
  fi
fi

# ---------------------------------------------------------------- Security patterns
sec=""
for f in "${changed_gd[@]}"; do
  r="$(relp "$f")"
  hits="$(grep -nE 'bytes_to_var_with_objects|str_to_var\(|allow_objects[[:space:]]*=[[:space:]]*true|get_var\([^)]*true' "$f" | head -n 5)"
  [[ -n "$hits" ]] && sec+="  $r: deserialización que puede instanciar objetos/código (usa JSON o Resources tipados):"$'\n'"$hits"$'\n'
  hits="$(grep -nE 'OS\.(execute|create_process|shell_open|execute_with_pipe)\(' "$f" | head -n 5)"
  [[ -n "$hits" ]] && warn "$r: llamada a OS.execute/shell_open; verifica que los argumentos no provienen de datos externos:"$'\n'"$hits"
  hits="$(grep -nE 'HTTPRequest|HTTPClient' "$f" | grep -v 'https://' | grep -E 'http://' | head -n 3)"
  [[ -n "$hits" ]] && warn "$r: conexión HTTP sin TLS:"$'\n'"$hits"
done
[[ -n "$sec" ]] && fail "Patrones inseguros:"$'\n'"$sec"

# ---------------------------------------------------------------- Report
report="QUALITY GATE"$'\n'
[[ -n "$passed" ]] && report+="$passed"
[[ -n "$warnings" ]] && report+="$warnings"
[[ -n "$failures" ]] && report+="$failures"

if [[ -z "$failures" ]]; then
  mv -f "$RUN_MARKER" "$MARKER"
  trap - EXIT
  [[ "$MODE" == "hook" ]] && rm -f "$COUNTER_FILE"
  if [[ "$MODE" == "hook" ]]; then
    [[ -n "$warnings" ]] && printf '{"systemMessage":%s}\n' "$(json_escape "$report")"
    exit 0
  fi
  printf '%s' "$report"; exit 0
fi

if [[ "$MODE" == "manual" ]]; then
  printf '%s' "$report"; exit 1
fi

blocks=0
[[ -f "$COUNTER_FILE" ]] && blocks="$(cat "$COUNTER_FILE" 2>/dev/null || echo 0)"
max="${GAMEDEV_GATE_MAX_BLOCKS:-3}"
if (( blocks >= max )); then
  rm -f "$COUNTER_FILE"
  printf '{"systemMessage":%s}\n' "$(json_escape "Quality gate sigue en ROJO tras $max intentos; se deja terminar para no entrar en bucle. Revisa manualmente:"$'\n'"$report")"
  exit 0
fi
echo $((blocks + 1)) > "$COUNTER_FILE"
printf '{"decision":"block","reason":%s}\n' "$(json_escape "$report"$'\n'"No termines todavía: corrige los fallos marcados con ✗ (intento $((blocks + 1))/$max). Si un fallo no es tuyo o no se puede resolver, explícalo en tu informe final.")"
exit 0
