class_name GameScenes
extends RefCounted
## Rutas centralizadas de las escenas que se cargan o instancian por código.
## Tener las rutas en un solo lugar evita que mover un archivo rompa varios scripts
## en silencio: un `preload` con ruta inválida falla en el editor (no en runtime), y
## una ruta movida se actualiza una sola vez aquí. Añade aquí las escenas que
## referencien rutas literales repartidas por el código.

## Escena de entrada al nivel procedural (se carga por ruta vía GameManager.load_scene).
const STARTCAVE := "res://Stages/Layouts/Cave/CaveMain/StartCave.tscn"

## Escena del bosque (hub). Se carga al vencer al jefe y al reanudar partida guardada.
const FORESTMAIN := "res://Stages/Layouts/Forest/ForestMain.tscn"

## Escena de inicio (menú/sala inicial). El router de arranque la usa cuando aún no hay
## partida guardada en el bosque.
const MAINBUENO := "res://Stages/Main/MainBueno.tscn"

## Arena del jefe final. Se entra por el BossPortal del bosque al completar todos los niveles.
const FINALBOSS := "res://Stages/Layouts/FinalBoss/LayoutFinal.tscn"

## Plantilla de sala que instancia el generador (ruta; se carga con load() donde se use).
## NO usar preload aquí: arrastraría todo el árbol de la sala —incluidas las puertas con
## script (cave_door.gd)— dentro de la compilación de GameScenes, y como cave_door.gd
## referencia a GameScenes se forma una dependencia circular que rompe la carga.
const ROOM_LAYOUT := "res://Stages/Layouts/Cave/Layout1.tscn"
