---
name: sprite-pipeline
description: Pipeline para generar sprites, tiles, iconos y animaciones de forma programática en Godot - pixel art desde specs JSON (PNG + SpriteFrames + preview) o arte vectorial SVG. Úsalo cuando haya que crear o modificar arte 2D o placeholders.
user-invocable: false
---

# Sprite pipeline

Dos vías. Elige según la style guide (`docs/art/style-guide.md`):

| Vía | Cuándo | Fuente | Salida |
|---|---|---|---|
| Pixel art | Estilo pixel (8-64 px) | `art_src/sprites/<nombre>.json` | PNG + `_frames.tres` + preview |
| Vectorial | Estilo limpio/flat, UI, iconos | `art_src/svg/<nombre>.svg` | SVG importado por Godot |

## Herramienta: `godot/tools/pixelart.gd`

Copiada desde `${CLAUDE_SKILL_DIR}/scripts/pixelart.gd` durante el setup (si falta, cópiala). Ejecutar
desde la raíz del repo:

```bash
godot --headless --path godot -s res://tools/pixelart.gd -- art_src/sprites/hero.json
godot --headless --path godot --import     # para que Godot importe los PNG nuevos
```

Genera:
- `output` (por defecto `res://assets/sprites/<name>.png`): spritesheet, **una fila por animación**.
- `<output>_frames.tres`: `SpriteFrames` listo para `AnimatedSprite2D` (si hay más de un frame o `"sprite_frames": true`).
- `art_src/preview/<name>_preview.png`: ampliado x8 sobre damero. **Ábrelo con Read para revisar el resultado.**

### Formato del spec

```json
{
  "name": "hero",
  "output": "res://assets/sprites/characters/hero.png",
  "frame_size": [16, 16],
  "palette": { ".": null, "k": "#1a1c2c", "s": "#f4b41b", "w": "#f4f4f4", "b": "#3b5dc9", "d": "#29366f" },
  "outline": "k",
  "animations": [
    { "name": "idle", "fps": 4, "loop": true, "frames": [ ["16 filas de 16 caracteres..."], ["..."] ] },
    { "name": "run",  "fps": 10, "loop": true, "frames": [ [...], [...], "idle:0", [...] ], "durations": [1, 1, 0.5, 1] },
    { "name": "run_left", "flip_x_of": "run", "fps": 10 }
  ]
}
```

- `palette`: un carácter → `#rrggbb`, `#rrggbbaa` o `null` (transparente). Usa la paleta de la style guide.
- Cada frame: array de `frame_size[1]` strings de longitud `frame_size[0]`; o una referencia `"anim:índice"` a un frame anterior.
- `outline` (opcional): pinta automáticamente un contorno de ese color alrededor de los píxeles opacos.
- `flip_x_of`: crea la animación espejada de otra anterior.
- `durations` (opcional): duración relativa por frame. `scale` (opcional): escalado entero del PNG (normalmente 1; el escalado lo hace el viewport).
- El script valida dimensiones y caracteres y lista todos los errores con su posición.

Ejemplo completo: [examples/slime.json](examples/slime.json).

### Técnica de pixel art (para que se lea bien)
- Diseña primero la **silueta** con 1-2 colores; luego sombras (luz desde arriba-izquierda por defecto) y 1 color de brillo.
- Máx. 3-4 tonos por material. Evita "pillow shading" (sombrear desde el borde hacia dentro por igual).
- Contorno oscuro (no negro puro) para personajes; sin contorno para fondos/tiles, para separar planos.
- Animación: idle 2-4 frames (respiración, 1 px), run 4-8, attack con anticipación (1-2 frames), impacto y recuperación.
- Personaje y fondo deben contrastar en valor (claro/oscuro), no solo en tono.
- Tiles: diseña sobre la cuadrícula (16x16 típico), comprueba la repetición colocando 3x3 en una spec de prueba.

## Vía SVG

- SVG limpio: `viewBox` igual al tamaño lógico (p. ej. `0 0 64 64`), colores de la paleta, sin texto (convierte a paths), sin filtros/blur (Godot rasteriza con ThorVG y algunos efectos no se soportan).
- Guarda el maestro en `art_src/svg/` y copia a `godot/assets/sprites/<categoría>/`. En el `.import` ajusta `svg/scale` si necesitas más resolución.
- Para revisar visualmente un SVG, rasterízalo: escribe un spec mínimo o ejecuta en Godot `Image.load_svg_from_string()` → `save_png()` en un script temporal en `art_src/preview/`.

## Placeholders

Rectángulos de color sólido del tamaño real, uno por categoría (jugador azul, enemigo rojo, pickup amarillo,
suelo gris), en `godot/assets/sprites/placeholder/`. Generados con el mismo script (spec de un solo frame relleno).

## Integración en Godot

- Pixel art: en `project.godot` → `rendering/textures/canvas_textures/default_texture_filter=0` (Nearest), y stretch `viewport` + `integer`.
- `AnimatedSprite2D.sprite_frames = preload("res://assets/sprites/characters/hero_frames.tres")`.
- Tilesets: el desarrollador crea el `TileSet` a partir del PNG (región = tamaño de tile); documenta en la style guide qué tile es cada índice.
