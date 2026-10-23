#!/usr/bin/env bash
# PostToolUse(Write|Edit|MultiEdit): fast, per-file feedback.
#  - GDScript: gdformat (autoformat), gdlint, static typing check, res:// paths exist,
#              reminder when a logic script has no unit test.
#  - Rust: rustfmt.
#  - .tscn/.tres: header sanity + every res:// reference exists.
# Never blocks (the tool already ran); it feeds findings back to the agent.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
read_input

file="$(json_get file_path)"
[[ -z "$file" ]] && exit 0
abs="$(to_unix_path "$file")"
rel="$(rel_path "$file")"
[[ -f "$abs" ]] || exit 0

GODOT_ROOT="$PROJECT_DIR/godot"
issues=""
add() { issues+="- $1"$'\n'; }

# res://path -> existence check relative to the Godot project (skips comment lines)
check_res_paths() {
  local f="$1" p
  [[ "$rel" == godot/* ]] || return 0
  while IFS= read -r p; do
    [[ -z "$p" ]] && continue
    p="${p%%::*}"
    [[ "$p" == *%* || "$p" == *'{'* || "$p" == *'$'* || "$p" == */ ]] && continue
    [[ -e "$GODOT_ROOT/${p#res://}" ]] || add "Ruta inexistente: $p (verifica el nombre o crea el recurso)"
  done < <(grep -vE '^[[:space:]]*(#|;)' "$f" | grep -oE 'res://[^"'"'"' )]+' | sort -u)
}

case "$rel" in
  *.gd)
    if have gdformat; then
      gdformat "$abs" >/dev/null 2>&1 || add "gdformat no pudo formatear el fichero (¿error de sintaxis?)"
    fi
    if have gdlint; then
      out="$(gdlint "$abs" 2>&1)" || add "gdlint:"$'\n'"$(printf '%s' "$out" | head -n 20)"
    else
      godot="$(find_godot)"
      if [[ -n "$godot" && -f "$GODOT_ROOT/project.godot" && "$rel" == godot/* ]]; then
        out="$("$godot" --headless --path "$GODOT_ROOT" --check-only -s "res://${rel#godot/}" 2>&1)"
        if printf '%s' "$out" | grep -qE 'Parse Error|SCRIPT ERROR|ERROR:'; then
          add "Godot --check-only:"$'\n'"$(printf '%s' "$out" | grep -E 'Parse Error|SCRIPT ERROR|ERROR:|at:' | head -n 15)"
        fi
      fi
    fi
    # Static typing: every func needs an explicit return type (project convention).
    untyped="$(grep -nE '^[[:space:]]*(static[[:space:]]+)?func[[:space:]]+[A-Za-z_0-9]+[[:space:]]*\(' "$abs" | grep -v -- '->' | head -n 10)"
    [[ -n "$untyped" ]] && add "Funciones sin tipo de retorno explícito (usa '-> void', '-> int', ...):"$'\n'"$untyped"
    untyped_params="$(grep -nE '^[[:space:]]*(static[[:space:]]+)?func[[:space:]]' "$abs" |
      awk -F'[()]' '{ n = split($2, a, ","); for (i = 1; i <= n; i++) { gsub(/^[ \t]+|[ \t]+$/, "", a[i]); if (a[i] != "" && a[i] !~ /:/) { print $0; break } } }' |
      head -n 10)"
    [[ -n "$untyped_params" ]] && add "Parámetros sin tipo (usa 'nombre: Tipo'):"$'\n'"$untyped_params"
    check_res_paths "$abs"
    # Test reminder for logic scripts.
    if [[ "${GAMEDEV_REQUIRE_TESTS:-1}" == "1" && "$rel" == godot/src/* ]] &&
       ! [[ "$rel" =~ ${GAMEDEV_TEST_EXEMPT:-^$} ]]; then
      base="$(basename "$rel" .gd)"
      if [[ -z "$(find "$GODOT_ROOT/test" -name "test_${base}.gd" 2>/dev/null | head -n1)" ]]; then
        add "No existe godot/test/**/test_${base}.gd. El quality gate exigirá un test unitario GUT para este script antes de terminar."
      fi
    fi
    ;;
  *.rs)
    if have rustfmt; then
      out="$(rustfmt --edition 2021 "$abs" 2>&1)" || add "rustfmt:"$'\n'"$(printf '%s' "$out" | head -n 20)"
    fi
    grep -nE '\.unwrap\(\)|\.expect\(' "$abs" | grep -v '#\[cfg(test)\]' | grep -vE '^\s*//' | head -n 5 > "$STATE_DIR/unwrap.tmp"
    if [[ -s "$STATE_DIR/unwrap.tmp" && "$rel" != *tests* ]]; then
      add "unwrap()/expect() en código no-test: en una GDExtension un panic tumba el juego. Propaga errores o usa godot_error!:"$'\n'"$(cat "$STATE_DIR/unwrap.tmp")"
    fi
    grep -qn 'unsafe ' "$abs" && ! grep -q 'SAFETY:' "$abs" && \
      add "Bloque unsafe sin comentario '// SAFETY:' que justifique la invariante."
    rm -f "$STATE_DIR/unwrap.tmp"
    ;;
  *.tscn|*.tres)
    head1="$(head -n1 "$abs")"
    [[ "$head1" =~ ^\[gd_(scene|resource) ]] || add "Cabecera inválida: la primera línea debe ser [gd_scene ...] o [gd_resource ...]"
    grep -q 'format=3' <<<"$head1" || add "Se esperaba format=3 (Godot 4) en la cabecera"
    check_res_paths "$abs"
    # ext_resource ids referenced but not declared
    for id in $(grep -oE 'ExtResource\("[^"]+"\)' "$abs" | sed -E 's/ExtResource\("([^"]+)"\)/\1/' | sort -u); do
      grep -qE "^\[ext_resource[^]]*id=\"$id\"" "$abs" || add "ExtResource(\"$id\") usado pero no declarado"
    done
    for id in $(grep -oE 'SubResource\("[^"]+"\)' "$abs" | sed -E 's/SubResource\("([^"]+)"\)/\1/' | sort -u); do
      grep -qE "^\[sub_resource[^]]*id=\"$id\"" "$abs" || add "SubResource(\"$id\") usado pero no declarado"
    done
    ;;
esac

if [[ -n "$issues" ]]; then
  post_feedback "Revisión automática de $rel:"$'\n'"$issues""Corrige estos puntos antes de continuar."
fi
exit 0
