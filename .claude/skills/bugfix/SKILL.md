---
name: bugfix
description: Flujo para corregir un bug - reproducirlo con un test automático que falle, corregirlo, revisarlo y verificar que no hay regresiones. Úsalo cuando el usuario reporte un fallo, crash o comportamiento incorrecto.
argument-hint: "[descripción del bug o BUG-NNN]"
---

# Bugfix: $ARGUMENTS

1. **Recoger datos** (si faltan): pasos, qué esperaba, qué pasó, escena/nivel, salida de la consola.
   Pregunta con `AskUserQuestion` solo lo imprescindible.
2. **Reproducir** → `qa-tester`: registrar `BUG-NNN` en `docs/qa/bugs.md` y escribir
   `godot/test/**/test_bug_NNN_<resumen>.gd` que **falle** por el bug. Si no se puede automatizar,
   pasos manuales exactos y por qué.
3. **Diagnosticar y corregir** → `gdscript-developer` (o `rust-developer` / `ui-designer` según el
   área): causa raíz (no parche del síntoma), fix mínimo, el test del bug pasa y el resto de la suite sigue en verde.
4. **Review** → `code-reviewer` si el bug era S1/S2 o tocó sistemas core.
5. **Verificar** → `qa-tester`: re-ejecución del test y comprobación de casos cercanos.
6. **Cerrar**: `BUG-NNN` como `FIXED` con la causa raíz en una línea; informa al usuario.
