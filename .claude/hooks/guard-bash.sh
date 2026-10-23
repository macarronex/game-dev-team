#!/usr/bin/env bash
# PreToolUse(Bash): blocks destructive, exfiltrating or supply-chain-risky commands.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
read_input

cmd="$(json_get command)"
[[ -z "$cmd" ]] && exit 0
c="$(printf '%s' "$cmd" | tr '[:upper:]' '[:lower:]' | tr -s ' ')"

block() { deny_pretool "Bloqueado por guard-bash: $1. Si es realmente necesario, pide al usuario que lo ejecute manualmente."; }

# --- Destructive filesystem operations ---------------------------------------
[[ "$c" =~ rm[[:space:]]+(-[a-z]*r[a-z]*f|-[a-z]*f[a-z]*r|-r[[:space:]]+-f|-f[[:space:]]+-r|--recursive)[[:space:]]+(/|~|\$home|\.|\*|\.\.|/c|c:)([[:space:]]|/?$|/\*) ]] && block "borrado recursivo de una ruta raíz/proyecto"
[[ "$c" =~ remove-item.*-recurse.*(c:\\|c:/|\$home|~|[[:space:]]\.([[:space:]]|$)) ]] && block "borrado recursivo (PowerShell) de una ruta amplia"
[[ "$c" =~ (^|[[:space:];&|])(format|mkfs|diskpart|dd[[:space:]]+if=) ]] && block "operación de disco"
[[ "$c" =~ (^|[[:space:];&|])(sudo|runas)[[:space:]] ]] && block "elevación de privilegios"
[[ "$c" =~ chmod[[:space:]]+(-r[[:space:]]+)?777 ]] && block "permisos 777"
[[ "$c" =~ (rm|del|remove-item)[^\;\&\|]*(\.git([[:space:]/]|$)|\.claude/hooks|\.claude/settings) ]] && block "borrado de .git o de la configuración de Claude"

# --- Git history rewriting ----------------------------------------------------
[[ "$c" =~ git[[:space:]]+push.*(--force|[[:space:]]-f([[:space:]]|$)|--mirror) ]] && block "git push forzado"
[[ "$c" =~ git[[:space:]]+(reset[[:space:]]+--hard|clean[[:space:]]+-[a-z]*f|filter-branch|filter-repo) ]] && block "reescritura/borrado de historia o ficheros sin trackear"

# --- Remote code execution / supply chain -------------------------------------
[[ "$c" =~ (curl|wget|iwr|invoke-webrequest|irm|invoke-restmethod)[^\|]*\|[[:space:]]*(ba|z)?sh ]] && block "descarga y ejecución de script remoto (curl | sh)"
[[ "$c" =~ (iwr|irm|invoke-webrequest|invoke-restmethod).*\|[[:space:]]*iex ]] && block "descarga y ejecución de script remoto (iwr | iex)"
[[ "$c" =~ (cargo|npm|pnpm|yarn)[[:space:]]+publish ]] && block "publicación de paquetes"
[[ "$c" =~ (pip|pip3)[[:space:]]+install.*(--index-url|--extra-index-url|git\+) ]] && block "instalación de paquetes desde índices/repos no estándar"

# --- Secrets exfiltration -----------------------------------------------------
[[ "$c" =~ (cat|type|get-content|less|more|head|tail)[[:space:]].*(\.env([[:space:]]|$|\.)|id_rsa|id_ed25519|\.pem|\.keystore|export_credentials\.cfg) ]] && block "lectura de ficheros con secretos"
[[ "$c" =~ (curl|wget|invoke-webrequest|iwr).*(-d|--data|--upload-file|-f[[:space:]]|-t[[:space:]]|-infile).*(\.env|\.pem|\.keystore|credentials) ]] && block "posible exfiltración de secretos"
[[ "$c" =~ (^|[\;\&\|][[:space:]]*)(printenv|env|set|export[[:space:]]+-p)[[:space:]]*($|[\;\&\|]) ]] && block "volcado de variables de entorno"
[[ "$c" =~ get-childitem[[:space:]]+env: ]] && block "volcado de variables de entorno"

exit 0
