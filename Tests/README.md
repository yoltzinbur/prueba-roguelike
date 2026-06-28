# Tests

Pruebas automatizadas mínimas para la lógica **pura** del juego (generación
procedural y puzzles), sin dependencias externas (no requiere GUT ni ningún addon).

## Cómo ejecutarlas

Desde la raíz del proyecto, con Godot 4.6 en el PATH (o usando la ruta completa al
ejecutable):

```sh
godot --headless res://Tests/Tests.tscn
```

Se ejecutan como **escena** (modo normal) para que los autoloads (`GameManager`,
`SoundManager`, `TutorialManager`) estén disponibles y no fallen los scripts que
dependen de ellos. El proceso sale con código `0` si todo pasa y `1` si algo falla,
de modo que sirve tal cual en un pipeline de CI.

## Qué cubren

- `_drunkards_walk`: tamaño exacto, celdas únicas, inclusión del origen y conexidad
  de la región generada (`Stages/Layouts/Cave/CaveMain/start_cave.gd`).
- `_pick_boss_coord`: la Sala de Jefe es una celda nueva (no existente) con
  exactamente una entrada (una sola puerta, callejón sin salida).
- `_random_value` del puzzle aritmético: nunca devuelve múltiplos del módulo ni se
  sale de rango (`Stages/Layouts/Cave/Layers/Puzzle/puzzle_arithmetic.gd`).
- `_residue`: cálculo del residuo modular (incluido el caso módulo 0).

## Cómo añadir una prueba

En `run_tests.gd`, escribe una función `_test_*()` que use `_check(condición, mensaje)`
y llámala desde `_ready()`. Para probar lógica que no toca el árbol de escena,
instancia el script con `.new()`, llama sus métodos y libéralo con `.free()`.
