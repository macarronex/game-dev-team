---
name: godot-project-setup
description: Crea el esqueleto de un proyecto Godot 4 con la estructura del equipo - carpetas, project.godot con warnings de tipado como error, input map, EventBus, GUT, herramientas headless (pixelart, sfxgen, input_map), gitignore y lint - y lo valida con el quality gate. Úsalo al arrancar un juego o para reparar la estructura.
argument-hint: "[nombre del juego]"
---

# Setup de proyecto Godot 4

Plantillas en `${CLAUDE_SKILL_DIR}/templates/`, scripts en `${CLAUDE_SKILL_DIR}/scripts/` y en las skills
`sprite-pipeline` y `sfx-pipeline`. Nombre del juego: $ARGUMENTS (o el de `docs/requirements.md`).

## 1. Comprobar herramientas

```bash
godot --version      # o "$GODOT_BIN" --version ; se requiere 4.3+
gdformat --version; gdlint --version; git --version
cargo --version      # solo si hay ADR de Rust
```
Si falta algo, **no lo instales**: devuelve en el informe la lista exacta (herramienta, URL oficial, versión).

## 2. Estructura

```bash
mkdir -p docs/adr docs/art docs/audio docs/ui docs/qa docs/reviews \
  godot/addons godot/assets/sprites/placeholder godot/assets/audio/sfx godot/assets/audio/music \
  godot/assets/fonts godot/assets/ui/theme godot/scenes/main godot/scenes/ui \
  godot/src/autoload godot/src/components godot/src/systems godot/src/data godot/src/ui \
  godot/test/unit/autoload godot/test/integration godot/tools \
  art_src/sprites art_src/svg art_src/sfx art_src/preview
```

## 3. Ficheros desde plantillas

| Plantilla | Destino |
|---|---|
| `templates/project.godot` | `godot/project.godot` (rellena los `{{...}}`, ver tabla abajo) |
| `templates/main.tscn` | `godot/scenes/main/main.tscn` |
| `templates/event_bus.gd` | `godot/src/autoload/event_bus.gd` |
| `templates/test_event_bus.gd` | `godot/test/unit/autoload/test_event_bus.gd` |
| `templates/gutconfig.json` | `godot/.gutconfig.json` |
| `templates/input_map.json` | `godot/tools/input_map.json` (ajústalo a los controles del GDD) |
| `templates/gdlintrc` | `.gdlintrc` (raíz) |
| `templates/gitignore` | `.gitignore` (raíz) |
| `templates/gitattributes` | `.gitattributes` (raíz) |
| `scripts/input_map.gd` | `godot/tools/input_map.gd` |
| `../sprite-pipeline/scripts/pixelart.gd` | `godot/tools/pixelart.gd` |
| `../sfx-pipeline/scripts/sfxgen.gd` | `godot/tools/sfxgen.gd` |

Valores de `project.godot`:

| Placeholder | Pixel art | HD / vectorial |
|---|---|---|
| `BASE_WIDTH`×`BASE_HEIGHT` | 320×180 o 640×360 | 1920×1080 |
| `WINDOW_WIDTH`×`WINDOW_HEIGHT` | 1280×720 | 1280×720 |
| `STRETCH_MODE` | `viewport` | `canvas_items` |
| `SCALE_MODE` | `integer` | `fractional` |
| `TEXTURE_FILTER` | `0` (Nearest) | `1` (Linear) |
| `RENDERER` | `gl_compatibility` (web/móvil/2D simple) o `forward_plus` (escritorio) / `mobile` | |
| `GODOT_MAJOR_MINOR` | versión instalada, p. ej. `4.5` | |

Si la versión de Godot es < 4.4, elimina de las plantillas lo que no exista (p. ej. `Dictionary[K, V]` tipados).

## 4. GUT

GUT (https://github.com/bitwes/Gut, licencia MIT) se instala en `godot/addons/gut/`, en la versión compatible
con la versión de Godot (GUT 9.x para Godot 4.x; consulta la tabla de compatibilidad del README).
**Descargar requiere aprobación del usuario** (vía orquestador). Opciones:
- El usuario lo instala desde el editor: AssetLib → "Gut - Godot Unit Testing (Godot 4)" → Install.
- O, con aprobación, descarga del release oficial de GitHub y copia solo la carpeta `addons/gut`.

Hasta que esté instalado, quita `res://addons/gut/plugin.cfg` de `[editor_plugins]` para que el import no falle.

## 5. Validar

```bash
godot --headless --path godot -s res://tools/input_map.gd -- res://tools/input_map.json
godot --headless --path godot --import
godot --headless --path godot -s res://addons/gut/gut_cmdln.gd -gdir=res://test -ginclude_subdirs -gexit
bash .claude/hooks/quality-gate.sh --all
```
Todo debe terminar sin errores. Si el directorio no es un repo git, indícalo en el informe para que el
orquestador pregunte al usuario si hacer `git init` (no lo hagas por tu cuenta).

## 6. Rust (solo con ADR)

Sigue la skill `godot-rust-gdextension`: `rust/` workspace + `godot/game_ext.gdextension`, `cargo build`,
y comprueba que Godot carga la extensión (`--import` sin errores de GDExtension).
