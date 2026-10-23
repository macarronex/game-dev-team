---
name: sfx-pipeline
description: Pipeline para generar efectos de sonido procedurales estilo sfxr (.wav) desde specs JSON con Godot headless, y convenciones de buses y AudioManager. Úsalo cuando haya que crear o ajustar efectos de sonido.
user-invocable: false
---

# SFX pipeline

## Herramienta: `godot/tools/sfxgen.gd`

Copiada desde `${CLAUDE_SKILL_DIR}/scripts/sfxgen.gd` durante el setup (si falta, cópiala). Desde la raíz:

```bash
godot --headless --path godot -s res://tools/sfxgen.gd -- art_src/sfx/player.json
godot --headless --path godot --import
```

Un fichero puede contener un objeto, un array, o `{"sounds": [...]}`. Agrupa por entidad (`player.json`, `ui.json`...).

### Parámetros

| Campo | Defecto | Significado |
|---|---|---|
| `name` | (obligatorio) | Nombre del fichero |
| `output` | `res://assets/audio/sfx/<name>.wav` | Ruta de salida |
| `wave` | `square` | `square`, `saw`, `triangle`, `sine`, `noise` |
| `duration` | 0.3 | Segundos |
| `freq_start` / `freq_end` | 440 / = start | Barrido de frecuencia (Hz) |
| `freq_curve` | `linear` | `linear` o `exp` (más natural en barridos amplios) |
| `duty` | 0.5 | Ancho de pulso de `square` (0.125 = más "nasal") |
| `attack`, `decay`, `sustain`, `release` | 0.005, 0.05, 0.7, 0.1 | Envolvente ADSR (s, s, nivel 0-1, s) |
| `vibrato_depth` / `vibrato_rate` | 0 / 0 | Semitonos / Hz |
| `arpeggio` | `[]` | `[{"time": 0.06, "mult": 1.5}]` saltos de tono (monedas, power-ups) |
| `noise_mix` | 0 | Mezcla de ruido sobre el tono (impactos) |
| `lowpass` | 1.0 | Filtro paso bajo 0.01-1 (1 = sin filtro; bajo = más sordo) |
| `bitcrush` | 0 | Bits de cuantización (0 = off; 4-6 = lo-fi) |
| `volume` | 0.8 | Escala del pico normalizado (pico máx. -1 dBFS) |
| `variations` / `pitch_jitter` / `seed` | 1 / 0 / 1 | Genera `<name>_1..N.wav` con tono aleatorio ±jitter |
| `sample_rate` | 44100 | Hz |

### Recetas de partida

```json
{"sounds": [
  {"name": "jump",    "wave": "square", "duty": 0.25, "duration": 0.22, "freq_start": 280, "freq_end": 620, "freq_curve": "exp", "attack": 0.0, "decay": 0.05, "sustain": 0.5, "release": 0.12},
  {"name": "coin",    "wave": "square", "duty": 0.5, "duration": 0.25, "freq_start": 988, "arpeggio": [{"time": 0.07, "mult": 1.335}], "decay": 0.04, "sustain": 0.6, "release": 0.14},
  {"name": "hit",     "wave": "noise", "duration": 0.18, "freq_start": 1800, "freq_end": 300, "attack": 0.0, "decay": 0.04, "sustain": 0.4, "release": 0.12, "lowpass": 0.6, "variations": 3, "pitch_jitter": 0.08},
  {"name": "explosion","wave": "noise", "duration": 0.7, "freq_start": 600, "freq_end": 60, "freq_curve": "exp", "attack": 0.0, "decay": 0.1, "sustain": 0.6, "release": 0.5, "lowpass": 0.35},
  {"name": "laser",   "wave": "saw", "duration": 0.2, "freq_start": 1400, "freq_end": 220, "freq_curve": "exp", "attack": 0.0, "decay": 0.02, "sustain": 0.7, "release": 0.1, "variations": 3, "pitch_jitter": 0.05},
  {"name": "powerup", "wave": "triangle", "duration": 0.5, "freq_start": 300, "freq_end": 900, "vibrato_depth": 0.6, "vibrato_rate": 14, "release": 0.2},
  {"name": "ui_click","wave": "sine", "duration": 0.06, "freq_start": 1200, "freq_end": 900, "attack": 0.001, "decay": 0.02, "sustain": 0.3, "release": 0.03, "volume": 0.5},
  {"name": "step",    "wave": "noise", "duration": 0.07, "freq_start": 900, "freq_end": 500, "lowpass": 0.25, "attack": 0.0, "release": 0.05, "volume": 0.4, "variations": 4, "pitch_jitter": 0.12}
]}
```

## Verificación

Claude no puede escuchar el audio: verifica con lo medible.
- Salida del script: duración y ficheros generados.
- Duraciones coherentes con la acción (UI < 0.1 s, saltos ~0.2 s, explosiones < 1 s).
- Sin clics: `attack` ≥ 0.001 y `release` ≥ 0.02 salvo efecto intencionado.
- Pide al usuario en el informe que escuche los sonidos clave y dé feedback ("más grave", "más corto").

## Integración

- Buses en `godot/default_bus_layout.tres`: `Master` → `Music`, `SFX`, `UI` (y `Ambient` opcional).
- Variaciones: `AudioStreamRandomizer` con los `_1.._N.wav` (`random_pitch` 1.05-1.1 para más variedad).
- `AudioManager` autoload con API por evento (`play_sfx(&"jump")`), pool de `AudioStreamPlayer`
  (8-16) para evitar cortes, y `AudioStreamPlayer2D` para sonidos posicionales.
- Música: `.ogg` en loop (import → `loop=true`), cross-fade en cambios de estado.
