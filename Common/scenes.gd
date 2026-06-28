class_name GameScenes
extends RefCounted
## Rutas centralizadas de las escenas que se cargan o instancian por código.
## Tener las rutas en un solo lugar evita que mover un archivo rompa varios scripts
## en silencio: un `preload` con ruta inválida falla en el editor (no en runtime), y
## una ruta movida se actualiza una sola vez aquí. Añade aquí las escenas que
## referencien rutas literales repartidas por el código.

## Escena de entrada al nivel procedural (se carga por ruta vía GameManager.load_scene).
const STARTCAVE := "res://Stages/Layouts/Cave/CaveMain/StartCave.tscn"

## Plantilla de sala que instancia el generador.
const ROOM_LAYOUT: PackedScene = preload("res://Stages/Layouts/Cave/Layout1.tscn")
