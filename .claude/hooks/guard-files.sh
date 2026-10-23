#!/usr/bin/env bash
# PreToolUse(Write|Edit|MultiEdit):
#  1. Protects generated/cache/secret paths.
#  2. Asks the human before the team touches its own quality-gate config.
#  3. Enforces that the orchestrator (main thread) delegates code/asset work.
#  4. Blocks hard-coded secrets in the written content.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
read_input

file="$(json_get file_path)"
[[ -z "$file" ]] && exit 0
rel="$(rel_path "$file")"
rel_lc="$(printf '%s' "$rel" | tr '[:upper:]' '[:lower:]')"
agent_id="$(json_get agent_id)"
agent_type="$(json_get agent_type)"

# --- 1. Protected paths ------------------------------------------------------
case "$rel_lc" in
  .git/*|*/.git/*)
    deny_pretool "No se edita .git a mano." ;;
  godot/.godot/*|*/.godot/*)
    deny_pretool "godot/.godot/ es caché generada por el editor; no se edita. Modifica el recurso fuente (.tscn/.tres/.gd) o reimporta con 'godot --headless --path godot --import'." ;;
  rust/target/*|*/target/debug/*|*/target/release/*)
    deny_pretool "rust/target/ es salida de compilación; no se edita." ;;
  .env|.env.*|*/.env|*/.env.*|*.pem|*.key|*.keystore|*.jks|*export_credentials.cfg)
    deny_pretool "Fichero de secretos/credenciales: los agentes no lo crean ni lo editan. El usuario debe gestionarlo manualmente." ;;
esac

# --- 2. Team configuration (hooks, settings, agents) ---------------------------
case "$rel_lc" in
  .claude/settings.json|.claude/settings.local.json|.claude/hooks/*)
    ask_pretool "Se va a modificar la configuración de quality gates/hooks del equipo ($rel). ¿Lo apruebas?" ;;
esac

# --- 3. Delegation enforcement for the orchestrator ------------------------------
if [[ "${GAMEDEV_ENFORCE_DELEGATION:-1}" == "1" && -z "$agent_id" ]]; then
  if [[ -z "$agent_type" || "$agent_type" == "orchestrator" ]]; then
    case "$rel_lc" in
      godot/*|rust/*|art_src/*)
        deny_pretool "El orquestador no implementa: delega '$rel' en el subagente adecuado (gdscript-developer, rust-developer, ui-designer, artist, audio-designer, qa-tester, build-engineer). Para desactivar esta regla: GAMEDEV_ENFORCE_DELEGATION=0." ;;
    esac
  fi
fi

# --- 4. Hard-coded secrets ------------------------------------------------------
secret_re='(AKIA[0-9A-Z]{16}|-----BEGIN ([A-Z]+ )?PRIVATE KEY-----|sk-ant-[A-Za-z0-9_-]{20,}|sk-[A-Za-z0-9]{32,}|gh[pousr]_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{40,}|xox[baprs]-[A-Za-z0-9-]{10,}|AIza[0-9A-Za-z_-]{35}|(api[_-]?key|secret|passw(or)?d|token)[\"'"'"']?[[:space:]]*[:=][[:space:]]*\\?[\"'"'"'][A-Za-z0-9+/_=-]{16,})'
if printf '%s' "$HOOK_INPUT" | grep -qiE "$secret_re"; then
  ask_pretool "Posible secreto hard-codeado en $rel (API key, token, clave privada o contraseña). Los secretos van en variables de entorno o ficheros fuera del repo. ¿Continuar de todas formas?"
fi

exit 0
