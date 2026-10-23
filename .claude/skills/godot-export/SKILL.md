---
name: godot-export
description: Exportación y CI de proyectos Godot 4 - export_presets.cfg sin secretos, filtros de exclusión, plantillas de export, builds headless por plataforma, integración de la GDExtension Rust y workflow de GitHub Actions con los mismos checks que el quality gate. Úsalo para preparar builds o pipelines.
user-invocable: false
---

# Export y CI

## Export presets

- `godot/export_presets.cfg` se versiona **sin credenciales**. Keystores Android, certificados de firma,
  contraseñas: en `godot/.godot/export_credentials.cfg` (Godot 4 las separa ahí; ignorado por git) o en
  variables de entorno/secrets de CI (`GODOT_ANDROID_KEYSTORE_RELEASE_PATH`, etc.).
- Filtro de exclusión en cada preset: `exclude_filter="tools/*, test/*, addons/gut/*, *.md"`.
- Nombre de preset = plataforma (`Windows Desktop`, `Linux`, `Web`, `macOS`, `Android`).
- Versión del juego en `project.godot` → `application/config/version="0.1.0"` (SemVer). Ese valor se muestra en el menú.
- Las plantillas de export (`export_templates`) deben coincidir exactamente con la versión de Godot; descargarlas requiere aprobación del usuario.

## Build

```bash
mkdir -p build/windows build/linux build/web
godot --headless --path godot --import
godot --headless --path godot --export-release "Windows Desktop" ../build/windows/game.exe
godot --headless --path godot --export-release "Linux" ../build/linux/game.x86_64
godot --headless --path godot --export-release "Web" ../build/web/index.html
# debug: --export-debug ; solo datos: --export-pack "Linux" ../build/game.pck
```

Con Rust: `cd rust && cargo build --release` **antes** del export, para cada target (`--target x86_64-pc-windows-msvc`, ...).
La web requiere build `wasm32-unknown-emscripten` y soporte de threads: valora si compensa (ADR).

## GitHub Actions (`.github/workflows/ci.yml`)

```yaml
name: ci
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    env:
      GODOT_VERSION: "4.x.y"          # fija la versión exacta del proyecto
    steps:
      - uses: actions/checkout@v4
      - name: Install Godot
        run: |
          wget -q https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip
          unzip -q Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip
          sudo mv Godot_v${GODOT_VERSION}-stable_linux.x86_64 /usr/local/bin/godot
      - uses: actions/setup-python@v5
        with: { python-version: "3.12" }
      - run: pip install "gdtoolkit==4.*"
      - uses: dtolnay/rust-toolchain@stable
        with: { components: "clippy, rustfmt" }
        if: hashFiles('rust/Cargo.toml') != ''
      - run: cd rust && cargo build
        if: hashFiles('rust/Cargo.toml') != ''
      - name: Quality gate
        run: bash .claude/hooks/quality-gate.sh --all
```

(El quality gate trata como avisos las herramientas ausentes; en CI todas deben estar instaladas.)
Para releases: job adicional por tag `v*` que instala export templates, exporta y sube artefactos.
