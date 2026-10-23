---
name: game-design-doc
description: Plantilla y criterios para escribir el Game Design Document (docs/GDD.md) y especificar features de juego con parámetros numéricos y criterios de aceptación jugables. Úsalo al crear o ampliar el diseño del juego.
user-invocable: false
---

# Game Design Document

Escribe `docs/GDD.md` con esta estructura. Conciso: tablas y listas antes que prosa. Cada sección MVP
debe ser implementable sin preguntas.

```markdown
# <Título> — GDD  (versión N, fecha)

## 1. Visión
- Pitch (1 frase) · Fantasía del jugador · Pilares de diseño (3 máx.) · Referencias
- Plataforma, controles, duración de sesión, público

## 2. Core loop
- Bucle de 30 s / 5 min / sesión (diagrama mermaid)
- Condiciones de victoria, derrota y reintento

## 3. Mecánicas
### 3.x <Mecánica>  [MVP | Deseable | Futuro]
- Regla(s)
- Parámetros: | Parámetro | Valor inicial | Rango de tuning | Unidad |
- Casos límite
- Feedback (visual / sonoro / háptico)
- Criterios de aceptación (verificables por QA): "Dado… cuando… entonces…"

## 4. Controles
| Acción | Teclado | Mando | Táctil | Acción de input (`move_left`…) |

## 5. Entidades y contenido
Tablas por tipo (jugador, enemigos, objetos, armas) con los campos de su Resource (`EnemyData`: hp, speed, damage, …)

## 6. Progresión y economía
Curvas (fórmula + tabla de los primeros N niveles), fuentes y sumideros de recursos

## 7. Niveles / mundo
Estructura, lista de niveles del MVP, ritmo (introducción → práctica → giro → examen) de cada mecánica

## 8. UI/UX
Pantallas necesarias y la información que muestra el HUD (detalle en docs/ui/ui-spec.md)

## 9. Arte y audio (dirección)
Estilo, tamaños, paleta orientativa, ambiente sonoro (detalle en style-guide/audio-guide)

## 10. Accesibilidad y opciones

## 11. Alcance por hitos
| Hito | Objetivo jugable | Contenido incluido |

## 12. Preguntas abiertas y riesgos
```

## Criterios de calidad

- Parámetros con unidades (px, px/s, s, tiles). Para plataformas, define el salto por altura y tiempo
  hasta el ápice y deriva gravedad/velocidad (`g = 2h/t²`, `v0 = 2h/t`), para que el desarrollador no adivine.
- Feel: lista coyote time, jump buffer, hit-stop, i-frames, knockback… con valores.
- Cada mecánica MVP tiene ≥ 2 criterios de aceptación medibles.
- Marca explícitamente lo que está fuera de alcance.
