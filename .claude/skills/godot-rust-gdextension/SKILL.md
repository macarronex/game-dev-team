---
name: godot-rust-gdextension
description: Cómo crear y mantener extensiones nativas en Rust para Godot 4 con godot-rust (gdext) - layout del workspace, fichero .gdextension, clases expuestas, señales, separación núcleo/binding, tests y criterios para decidir si algo debe ir en Rust. Úsalo para cualquier trabajo en rust/.
user-invocable: false
paths:
  - "rust/**"
  - "**/*.gdextension"
---

# Rust + Godot 4 (godot-rust / gdext)

Referencia oficial: https://godot-rust.github.io/book/ y https://docs.rs/godot (comprueba la versión
actual del crate antes de empezar; la API cambia entre versiones 0.x).

## ¿Debe ir en Rust?

Sí, solo si (y con ADR): CPU caliente medido con el profiler de Godot (> ~2 ms/frame en un sistema),
simulación/pathfinding sobre miles de entidades, generación procedural pesada, o librería nativa
necesaria. No: lógica de gameplay normal, UI, escenas, cosas que el diseño cambiará a menudo.

## Layout

```
rust/
  Cargo.toml            # [workspace] members = ["game_core", "game_ext"], resolver = "2"
  game_core/            # lógica pura, SIN dependencia de godot -> cargo test rápido
    Cargo.toml
    src/lib.rs
  game_ext/             # adaptador GDExtension (cdylib)
    Cargo.toml          # [lib] crate-type = ["cdylib"]; deps: godot, game_core
    src/lib.rs
godot/game_ext.gdextension
```

`rust/Cargo.toml`:
```toml
[workspace]
members = ["game_core", "game_ext"]
resolver = "2"

[profile.release]
lto = "thin"
```

`rust/game_ext/Cargo.toml` (añade godot con `cargo add godot` para fijar la última versión; activa el
feature `api-4-N` que corresponda a la versión **mínima** de Godot del proyecto si el crate lo requiere):
```toml
[package]
name = "game_ext"
version = "0.1.0"
edition = "2021"

[lib]
crate-type = ["cdylib"]

[dependencies]
game_core = { path = "../game_core" }
godot = "x.y"   # cargo add godot
```

`godot/game_ext.gdextension` (ruta relativa al proyecto: el workspace está fuera de `godot/`):
```ini
[configuration]
entry_symbol = "gdext_rust_init"
compatibility_minimum = 4.3
reloadable = true

[libraries]
linux.debug.x86_64 = "res://../rust/target/debug/libgame_ext.so"
linux.release.x86_64 = "res://../rust/target/release/libgame_ext.so"
windows.debug.x86_64 = "res://../rust/target/debug/game_ext.dll"
windows.release.x86_64 = "res://../rust/target/release/game_ext.dll"
macos.debug = "res://../rust/target/debug/libgame_ext.dylib"
macos.release = "res://../rust/target/release/libgame_ext.dylib"
macos.debug.arm64 = "res://../rust/target/debug/libgame_ext.dylib"
macos.release.arm64 = "res://../rust/target/release/libgame_ext.dylib"
```

## Binding (game_ext/src/lib.rs)

```rust
use godot::prelude::*;

struct GameExtension;

#[gdextension]
unsafe impl ExtensionLibrary for GameExtension {}

/// Grid pathfinder exposed to GDScript. Pure logic lives in game_core::path.
#[derive(GodotClass)]
#[class(base = RefCounted, init)]
pub struct GridPathfinder {
    grid: game_core::path::Grid, // must implement Default (required by `init`)
    base: Base<RefCounted>,      // needed for self.signals()
}

#[godot_api]
impl GridPathfinder {
    #[signal]
    fn path_not_found(from: Vector2i, to: Vector2i);

    #[func]
    fn set_size(&mut self, width: i32, height: i32) {
        if width <= 0 || height <= 0 {
            godot_error!("GridPathfinder.set_size: invalid size {width}x{height}");
            return;
        }
        self.grid = game_core::path::Grid::new(width as usize, height as usize);
    }

    #[func]
    fn set_blocked(&mut self, cell: Vector2i, blocked: bool) {
        self.grid.set_blocked(cell.x, cell.y, blocked);
    }

    /// Returns the path as cells, or an empty array if unreachable.
    #[func]
    fn find_path(&mut self, from: Vector2i, to: Vector2i) -> PackedVector2Array {
        match self.grid.find_path((from.x, from.y), (to.x, to.y)) {
            Some(path) => path.into_iter().map(|(x, y)| Vector2::new(x as f32, y as f32)).collect(),
            None => {
                self.signals().path_not_found().emit(from, to);   // API de señales tipadas (gdext >= 0.3)
                PackedVector2Array::new()
            }
        }
    }
}
```

Desde GDScript: `var pf := GridPathfinder.new(); pf.set_size(64, 64); var path := pf.find_path(a, b)`.

## Reglas

- **Interfaz por lotes**: pasa arrays (`PackedVector2Array`, `PackedInt32Array`) en una llamada, no
  miles de llamadas por elemento (el cruce GDScript↔Rust tiene coste).
- Nodos (`base = Node2D`, `INode2D` con `fn process`) solo si de verdad necesitan el árbol; si no, `RefCounted`.
- **Sin panics**: nada de `unwrap()/expect()` fuera de tests; valida entradas en el borde y usa
  `godot_error!`/`godot_warn!`. Un panic en GDExtension aborta o deja el motor inconsistente.
- `unsafe` solo con `// SAFETY:` explicando la invariante. `#[gdextension] unsafe impl` es la excepción estándar.
- Tests: unitarios en `game_core` (`cargo test`); contrato desde Godot con un test GUT en
  `godot/test/integration/test_<modulo>_ext.gd` (requiere `cargo build` previo).
- Dependencias mínimas, `cargo audit` limpio, `Cargo.lock` versionado.
- Hot reload: en Windows la DLL queda bloqueada con el editor abierto; `reloadable = true` (Godot 4.2+) ayuda,
  si no, cierra el editor para recompilar.

## Comandos

```bash
cd rust && cargo build                       # debug, la que carga el editor
cd rust && cargo build --release             # para exportar
cd rust && cargo fmt --all && cargo clippy --all-targets -- -D warnings && cargo test
```
