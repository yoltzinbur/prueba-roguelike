# Organizacion de Datos, Mapas, Generacion Procedural y Sistema de Guardado

## Estructura de Mapas (`Stages/`)
Los niveles se componen mediante escenas modulares, tilemaps optimizados y un generador procedural.

### Escenas Principales

| Escena | Ruta | Proposito |
|--------|------|-----------|
| `Boot.tscn` | `Stages/Boot/Boot.tscn` | **Escena raiz del juego** (debe configurarse en project.godot -> `run/main_scene`). Router de arranque: `boot.gd` lee el guardado y entra al bosque (`save_location == "forest"`) o a `MainBueno`. |
| `MainBueno.tscn` | `Stages/Main/MainBueno.tscn` | Area de inicio (ya no es la escena raiz; la abre Boot cuando no hay partida en el bosque). Tilemap, jugador y `CaveDoor1` que entra a la cueva. |
| `Main.tscn` | `Stages/Main/Main.tscn` | Layout legacy del dungeon (pre-procedural). Ignorado por el flujo actual. |
| `StartCave.tscn` | `Stages/Layouts/Cave/CaveMain/StartCave.tscn` | Nivel jugable (cueva procedural). `start_cave.gd` genera el mapa. Al vencer al jefe, la puerta de avance lleva al bosque. |
| `ForestMain.tscn` | `Stages/Layouts/Forest/ForestMain.tscn` | **Hub central.** `forest_main.gd` instancia al jugador bajo `Sorting`, guarda la partida, gestiona `SavePoint`, `Chest` persistente, la entrada `Cave` (siguiente nivel) y el `BossPortal`. |
| `LayoutFinal.tscn` | `Stages/Layouts/FinalBoss/LayoutFinal.tscn` | Arena del jefe final (Squid). `layout_final.gd` instancia al jugador, activa al jefe y, al vencerlo, marca `boss_defeated` y vuelve al bosque. |

### Flujo de Juego Completo
```
Boot.tscn (boot.gd) -> lee SaveManager
   |-- save_location == "forest" -> ForestMain.tscn
   +-- si no                     -> MainBueno.tscn
                                        |
                                        | CaveDoor1.interact()
                                        v
                              StartCave.tscn (nivel)  -> start_cave.gd genera la cueva
                                        |
                                        | vencer al jefe -> CaveDoor2 (completes_level)
                                        v
                              SaveManager.complete_level()
                                 (levels_completed +=1, max_flasks +=1, guarda) -> ForestMain
                                        |
   ForestMain.tscn (hub) <-------------- llegada: instancia Player bajo Sorting + guarda
      |-- SavePoint            -> cura + guarda (fija el punto de reanudacion)
      |-- Cave (entrada)       -> niveles<2: StartCave (siguiente nivel); niveles>=2: "puzzle completado"
      +-- BossPortal (Totem)   -> aparece con todos los niveles hechos -> LayoutFinal
                                        |
                              LayoutFinal.tscn -> al vencer al Squid: boss_defeated=true,
                                                  guarda y vuelve al bosque (el Totem queda purificado)
```

Detalle de la generacion de la cueva (`StartCave -> start_cave.gd._ready()`): `seed/randomize`,
`generate_map()` (Drunkard's Walk + tipos), `build_rooms()` (N copias de `Layout1.tscn`, cada una
`configure_room(tipo, N,S,E,W)` -> puertas segun vecinos + pools + contenido interior).

---

## Generacion Procedural de Cuevas

### Arquitectura del Generador (`start_cave.gd`)
El generador vive en `Stages/Layouts/Cave/CaveMain/start_cave.gd` y extiende `Node2D`. Implementa el algoritmo **Drunkard's Walk** para crear una cuadricula organica de salas conectadas. Ademas de generar el mapa, actua como **administrador del nivel**: lleva el progreso de puzzles y desbloquea la sala del Boss (ver "Progreso de Puzzles y Desbloqueo del Jefe").

### Configuracion (Propiedades @export)
```
easy_room: int = 4          -- Salas de combate facil
medium_room: int = 3        -- Salas de combate medio
hard_room: int = 2          -- Salas de combate dificil
puzzle_room: int = 1        -- Salas de puzzle
rest_room: int = 1          -- Salas de descanso
room_size: Vector2 = (592, 368)  -- Tamano en pixeles de cada sala
generation_seed: int = -1   -- Semilla (-1 = aleatoria cada ejecucion)
```

El total de salas es siempre: `easy + medium + hard + puzzle + rest + 2` (Inicio + Jefe).

### Algoritmo Drunkard's Walk
1. Parte de la coordenada `(0, 0)`.
2. En cada paso, elige una direccion cardinal aleatoria (N, S, E, W).
3. Si la celda destino no fue visitada, la agrega a la lista.
4. Repite hasta reunir el numero exacto de celdas necesarias.
5. Limite de seguridad: `amount * 1000` iteraciones para evitar bucle infinito.

El resultado es una region conexa con forma organica — no es un rectangulo perfecto, sino que deja huecos y forma "pasillos" naturales en la cuadricula.

### Asignacion de Tipos de Sala
1. **Start**: Siempre en `(0, 0)`. Sala inicial sin enemigos ni contenido. El recorrido Drunkard's Walk genera la Sala de Inicio + las de relleno (`filler_count + 1` celdas); la Sala de Jefe NO se camina.
2. **Boss** (`_pick_boss_coord`): es una celda **extra** que asoma del mapa una posicion mas alla de uno de sus bordes (max/min en X o Y). Al quedar fuera del "bounding box" solo puede tener un vecino, por lo que la Sala de Jefe tiene **exactamente una puerta** (un callejon sin salida): nunca es sala de paso, evitando que un puzzle u otra sala quede detras del jefe. Entre las cuatro extensiones posibles (una por borde) se elige la mas lejana del inicio (distancia Manhattan), forzando el recorrido del mapa. El total de salas sigue siendo `filler_count + 2` (Inicio + Jefe).
3. **Resto**: Se construye una "bolsa" con las cantidades exactas de cada tipo (Easy, Medium, Hard, Puzzle, Rest), se mezcla aleatoriamente (`shuffle()`), y se asigna en orden a las coordenadas caminadas restantes (la celda del jefe no esta entre ellas).

### Posicionamiento Fisico
Cada sala se posiciona en el mundo a: `Vector2(coordenada_grid) * room_size`. Con `room_size = (592, 368)`, una sala en la coordenada `(2, -1)` queda en la posicion `(1184, -368)` pixeles.

---

## Plantilla de Sala (`layout_1.gd` / `Layout1.tscn`)

### Clase `RoomLayout`
`layout_1.gd` define la clase `RoomLayout` que extiende `Node2D`. Cada instancia es una sala completa con:

**Estructura de nodos:**
```
Layout1 (RoomLayout)
  |-- Layers/
  |     |-- floor (TileMapLayer)           -- Suelo base, sin colision
  |     |-- navigation_floor (TileMapLayer) -- Celdas validas para spawn de enemigos
  |     +-- walls (TileMapLayer)           -- Paredes con colision
  |-- Doors/
  |     |-- NorthDoor (con CollisionShape2D + InteractionArea)
  |     |-- SouthDoor
  |     |-- EastDoor
  |     +-- WestDoor
  |-- Content/ (Node2D)                   -- Contenido interior instanciado
  |-- EnemySpawner (enemy_spawner.gd)     -- Spawner de enemigos
  +-- RoomTrigger (Area2D)                -- Detecta entrada/salida del jugador (capa 7)
```

### Configuracion de Sala (`configure_room`)
El generador llama `configure_room(type, north, south, east, west)` donde los booleanos indican si hay sala vecina en esa direccion.

**Puertas:**
- Si hay vecino: la puerta se oculta y se desactiva su colision (pasillo abierto).
- Si no hay vecino: la puerta permanece visible con colision activa (muro de contencion).
- Las `InteractionArea` de las puertas se desactivan siempre en el mapa procedural para evitar que disparen `GameManager.load_scene()`.

**Contenido por tipo de sala:**

La cantidad de enemigos por sala la define `quantity` de cada `SpawnCategory` de la pool (no hay un tope por sala en el código).

| Tipo | Combate? | Pools | Interior |
|------|----------|-------|----------|
| Start | No | Ninguno | Ninguno |
| Easy | Si | `easy_combat` | Aleatorio de `combat_list` |
| Medium | Si | `medium_combat` | Aleatorio de `combat_list` |
| Hard | Si | `hard_combat` | Aleatorio de `combat_list` |
| Boss | Si | Ninguno (el jefe viene en el layer) | Layer dedicado de `boss_list` (`BossRoom.tscn`: trae su propio mapa con el jefe ya colocado). Arranca **bloqueada** (`_lock_boss_room()`); se abre al resolver todos los puzzles. |
| Puzzle | No | Ninguno | Aleatorio de `puzzle_list` (StackQueue / Arithmetic / Laser) |
| Rest | No | Ninguno | Aleatorio de `rest_list` (`RestRoom.tscn` con la fogata `Campfire`) |

`configure_room()` expone `room_type` como variable publica de `RoomLayout` (se fija al inicio del metodo, antes de configurar puertas/contenido) para que el generador pueda consultar el tipo de cada sala tras instanciarla.

**Salas de descanso (Rest):** usan `_setup_peaceful(rest_list)` (sin enemigos). El contenido `RestRoom.tscn` incluye una fogata (`campfire.gd`) que al interactuar, una sola vez, restaura vida y frascos del jugador al maximo. Ver el patron del interactuable en `architecture.md`.

**Sala del Jefe (Boss):** usa `_setup_boss()`, que instancia un layer de `boss_list` (`BossRoom.tscn`) en `Content`. Ese layer trae su PROPIO mapa (`TileMapLayer`) y al jefe (`Samurai`) ya colocado dentro, por lo que NO se usa el `EnemySpawner` ni una pool de enemigos: el jefe es parte de la escena. Tras instanciarlo bloquea las puertas con `_lock_boss_room()`. (Reemplaza al antiguo `boss_combat`, ya eliminado.)

**Listas de contenido (@export):**
- `combat_list: Array[PackedScene]` — Layouts internos de combate (obstaculos, decoracion).
- `puzzle_list: Array[PackedScene]` — Contenido de salas puzzle.
- `rest_list: Array[PackedScene]` — Contenido de salas de descanso.
- `boss_list: Array[PackedScene]` — Layer(s) de la zona del Jefe (`BossRoom.tscn`), con el jefe ya dentro.

### Mecanica de Salas de Combate
Las salas de combate (Easy/Medium/Hard) se comportan como las de puzzle: encierran al jugador hasta limpiar la oleada. Ya NO spawnean al instanciarse. El `RoomTrigger` gestiona el ciclo:

1. **Entrada** (`_on_room_trigger_entered` -> `_enter_combat_room`): si la sala es de combate, no esta limpiada (`is_combat_cleared`) y no hay un combate en curso (`_combat_active`), cierra las puertas activas (`_close_all_active_doors()`) y difiere `_start_combat()`.
2. **Spawn** (`_start_combat`): marca `_combat_active = true`, conecta `enemy_spawner.child_exiting_tree` y spawnea la pool guardada sobre el **piso del layout de combate instanciado** (`_combat_floor()`: la `TileMapLayer` raiz del `Combat.tscn` dentro de `Content`), NO sobre todo el interior de la sala. Ese layout mezcla suelo (tiles con poligono de navegacion) y obstaculos (tiles solo con colision); el spawner descarta por celda las que no son navegables, igual que `_puzzle_floor()` en las salas de puzzle, asi los enemigos solo aparecen sobre suelo transitable. Si no hay piso de combate, la pool esta vacia o no se pudo spawnear a nadie (`_alive_combat_enemies() == 0`), limpia de inmediato para no encerrar al jugador en una sala vacia.
3. **Muertes** (`_on_combat_enemy_exiting` -> `_check_combat_cleared`): cada vez que un enemigo (grupo "Enemy", hijo del spawner) sale del arbol, comprueba de forma diferida si era el ultimo.
4. **Limpieza** (`_clear_combat`): cuando no queda ningun enemigo vivo, marca `is_combat_cleared = true`, desconecta el vigilante de muertes y reabre las puertas (`_open_active_doors()`). Reentrar no vuelve a encerrar al jugador.

Las salas de combate NO emiten `room_cleared` (ese contador es solo para puzzles y el desbloqueo del Boss).

### Mecanica de Salas de Puzzle
Las salas de tipo Puzzle encierran al jugador hasta que resuelve el puzzle. El `RoomTrigger` (un `Area2D` con mascara en la capa 7 = player) gestiona el ciclo:

1. **Entrada** (`_on_room_trigger_entered`): asigna `body.current_room = self`. Si la sala es Puzzle y no esta resuelta, cierra todas las puertas activas (`_close_all_active_doors()`, las vuelve muro con colision) y muestra la pista del orden **una sola vez** (`_show_puzzle_hint()` -> `_hint_shown`).
2. **Salida** (`_on_room_trigger_exited`): limpia `current_room` (evita reiniciar la sala desde fuera).
3. **Resolucion** (`complete_puzzle()`, llamada por el propio puzzle al resolverse): marca `is_puzzled_cleared = true`, detiene las oleadas de enemigos, reabre las puertas restaurando la configuracion original (`_open_active_doors()`) y emite `room_cleared(self)` para el administrador del nivel.
4. **Reinicio** (`reset_current_puzzle()`, disparada por el input `reset` del jugador): destruye el contenido actual de `Content` e instancia una copia limpia de `_current_puzzle_scene`. Se ignora si la sala ya esta resuelta.

**Sala del Boss (bloqueo independiente):** `configure_room()` la cierra con `_lock_boss_room()` (`_close_all_active_doors()`). La reabre `unlock_boss_room()` (`_open_active_doors()`), invocada por `start_cave.gd` al completar todos los puzzles. Reutiliza el mismo guardado de configuracion original de puertas que el bloqueo de puzzles.

**Persistencia del reto del puzzle:** al instanciar el puzzle por primera vez (`_setup_peaceful`), si es un `PuzzleStackQueue` la sala guarda su modo y secuencia (`_puzzle_mode`, `_puzzle_order`). En cada reinicio los reimpone con `apply_fixed_config()` ANTES de anadir el nodo al arbol, para que el reto (Pila/Cola y orden) no cambie entre intentos. Ver el detalle del puzzle en `architecture.md`.

**Señal `puzzle_reset`:** emitida tras reinstanciar el contenido en `reset_current_puzzle()`, por si la UI o sistemas externos necesitan reconectarse al nuevo contenido.

---

## Progreso de Puzzles y Desbloqueo del Jefe
`start_cave.gd` actua como administrador del nivel tras generar el mapa (`_init_puzzle_progress()` en `_ready()`):

1. Recorre las salas: cuenta las de tipo Puzzle (`total_puzzles`), guarda la del Boss (`_boss_room`) y conecta `room_cleared` de cada sala de puzzle a `_on_room_cleared`.
2. Localiza el contador en la UI del jugador (`UI/PuzzlesCounter`, instancia de `PuzzlesCounter.tscn`), lo hace visible dentro del dungeon y muestra `"Puzzles: X / Y"`.
3. `_on_room_cleared(room)` cuenta cada sala **una sola vez** (set `_cleared_rooms` por `instance_id`), refresca el contador y, al alcanzar `total_puzzles`, desbloquea el Boss.
4. `_unlock_boss_room()` llama `_boss_room.unlock_boss_room()` y avisa con `show_message()`. Si el nivel no tiene puzzles, el Boss queda accesible de entrada.
5. `_exit_tree()` oculta el contador al abandonar el dungeon (protegido con `is_instance_valid`).

> **Guia para IA:** El contador de puzzles vive en la UI del **jugador**, no en el nivel, para sobrevivir a la generacion/destruccion de salas. `start_cave.gd` solo lo localiza y actualiza. Si agregas otro objetivo de nivel (p. ej. llaves), sigue este patron: cuenta tras generar, escucha una señal de la sala y actualiza un nodo de HUD ya existente.

---

## Sistema de Spawn de Enemigos

### SpawnCategory (Recurso)
Definido en `Entities/Enemies/spawn_category.gd`:
```
SpawnCategory (Resource)
  |-- name: String          -- Nombre de la categoria (ej: "Pequenitos", "Mediano")
  |-- quantity: int         -- Cantidad a spawnear
  +-- scenes: PackedScene[] -- Escenas de enemigos posibles
```

### Enemy Spawner (`enemy_spawner.gd`)
Ubicado en `Entities/Enemies/enemy_spawner.gd`, extiende `Node2D` (`class_name EnemySpawner`).

Es un **servicio pasivo**: no lee nodos del inspector ni auto-spawnea en `_ready()`. Quien lo usa (el `RoomLayout`) le indica el piso y la pool en cada llamada; el jugador se resuelve solo desde el grupo `"Player"`.

**Propiedades @export:**
```
min_player_distance: float = 150.0      -- Distancia minima al jugador para spawn
```

**API:**
```
spawn_pool(pool: Array[SpawnCategory], floor_layer: TileMapLayer) -> void
spawn_count(pool: Array[SpawnCategory], count: int, floor_layer: TileMapLayer) -> void
```
- `spawn_pool`: spawnea la `quantity` de cada `SpawnCategory` de la pool (oleada completa).
- `spawn_count`: spawnea **exactamente** `count` enemigos tomados al azar de todas las escenas de la pool. Pensado para penalizaciones de cantidad controlada (p. ej. el puzzle aritmetico spawnea `residuo` enemigos via `RoomLayout.spawn_penalty_enemies()`), evitando acumular oleadas enteras.

**Algoritmo de Spawn:**
1. `_prepare_cells(floor_layer)`: fuerza la actualizacion del mapa de navegacion (`NavigationServer2D.map_force_update()`) y devuelve las celdas usadas del piso (advertencia si esta vacio).
2. Resuelve al jugador con `get_tree().get_first_node_in_group("Player")`.
3. Por cada enemigo a colocar, `_try_spawn_one(scenes, ...)` elige una celda al azar, descarta las que no tengan poligono de navegacion, convierte a global (`map_to_local()` + `to_global()`), verifica `min_player_distance`, instancia una escena aleatoria y devuelve si lo logro.
4. Limite de intentos: `quantity * 5` (en `spawn_pool`) o `count * 5` (en `spawn_count`) para evitar bucles. La logica de una sola colocacion se comparte entre ambos metodos.

**Integracion con Generacion Procedural:**
El spawner no sabe que tipo de sala es. `RoomLayout` lo invoca segun el tipo:
- **Salas de combate** (`_setup_combat`): NO spawnea al instanciar la sala; solo guarda la pool en `_combat_pools`. Los enemigos aparecen cuando el jugador entra (ver "Mecanica de Salas de Combate"), via `spawn_pool(pool, _combat_floor())` diferido, donde `_combat_floor()` es la `TileMapLayer` del layout de combate instanciado en `Content` (suelo + obstaculos). El spawner descarta por celda las no navegables, igual que con el piso de los puzzles.
- **Salas de puzzle** (oleadas): cada `WAVE_INTERVAL_SECONDS`, `_on_wave_timer_timeout()` llama `spawn_pool()` con el piso del puzzle actual (`_puzzle_floor()`, el nodo `FloorLayer` del contenido).
- **Salas pacificas** (Start, Rest): simplemente no se invoca al spawner.

---

## Sistema de Puertas

### Puerta de Entrada (`cave_door.gd`)
`Stages/Layouts/Cave/Environment/cave_door.gd` — Puerta interactuable en la escena de inicio. (`Environment/` ya solo contiene puertas; los demas objetos de mundo se movieron a `Stages/Elements/`.)

**Flujo:**
1. El jugador entra al `InteractionArea` del `Area2D`.
2. `body_entered` -> asigna `body.current_interactable = self`.
3. El jugador presiona la accion de interaccion.
4. `interact()` -> `open()` -> emite `door_interacted`. Si `@export completes_level` es `true`,
   llama `SaveManager.complete_level()` (cuenta el nivel, sube frascos, va al bosque); si no,
   `GameManager.load_scene(GameScenes.STARTCAVE)`.

**Escenas de puertas:**
- `CaveDoor1.tscn`: Puerta de entrada a la cueva (en MainBueno.tscn). `completes_level = false`: carga `StartCave`.
- `CaveDoor2.tscn`: **Puerta de avance del Jefe.** `completes_level = true`: al vencer al jefe se revela y, al cruzarla, completa el nivel y lleva al bosque.
- `CaveWall.tscn`: Muro visual usado como puerta cerrada en salas procedurales.

### Puertas Procedurales (dentro de Layout1)
Las 4 puertas de cada sala (NorthDoor, SouthDoor, EastDoor, WestDoor) **no** transicionan escenas. Son muros o pasillos abiertos segun la vecindad en la cuadricula. Su `InteractionArea` se desactiva para evitar conflictos con el sistema de interacciones.

---

## Datos Estaticos y Dinamicos

### 1. Datos Estaticos
- **Formato:** Recursos personalizados `.tres` o scripts con `class_name` (ej: `SpawnCategory`).
- **Uso:** Stats de enemigos (HP y velocidad en `@export` de `HealthComponent` y `VelocityComponent`), categorias de spawn, parametros de fisica.
- **Ubicacion:** Configurados directamente en las escenas `.tscn` de cada entidad o como sub-recursos en las escenas de nivel.

### 2. Sistema de Guardado (`SaveManager`)
Autoload `SaveManager` (`Utilities/save_manager.gd`) — fuente de verdad del progreso, persistido
con `ConfigFile` en `user://savegame.cfg` (seccion `[game]`). **Debe registrarse como autoload
DESPUES de `GameManager`** (lee/escribe `GameManager.coins`).

**Estado persistido:**
```
max_flasks: int = 3        -- Frascos maximos (sube +1 por cada jefe de cueva vencido)
levels_completed: int = 0  -- Niveles de cueva completados (0..TOTAL_LEVELS); TOTAL_LEVELS = 2
save_location: String      -- "cave" (arranca en MainBueno) o "forest" (arranca en el bosque)
forest_spawn: String       -- Punto de reanudacion en el bosque: "level1" | "savepoint"
opened_chests: Array       -- save_id de los cofres ya abiertos (cofres con save_id)
boss_defeated: bool        -- Jefe final derrotado: el BossPortal desaparece (purificado)
coins: int                 -- Se lee/escribe desde GameManager.coins (no se duplica)
```
> `forest_spawn` transitorio: `complete_level()` del nivel 2 usa un `_next_forest_spawn = "level2"`
> en memoria (NO persistido) para aparecer una vez frente a la cueva; el punto guardado real solo
> lo cambia el SavePoint.

**API principal:**
- `save_game()` — vuelca todo al `ConfigFile`; tras guardar muestra "Partida guardada" en la UI
  del jugador (`_announce_saved`). Se llama en cada guardado real.
- `load_game()` / `has_save()` — `_ready()` carga si existe el archivo (deja `GameManager.coins`
  listo antes de que arranque `Boot`).
- `complete_level()` — al vencer al jefe de cueva: `levels_completed += 1` (cap `TOTAL_LEVELS`),
  `max_flasks += 1`, `save_location = "forest"`, guarda y carga `ForestMain`.
- `register_forest_arrival(player)` — al llegar al bosque: fija `save_location`, rellena frascos
  (`apply_player_state`) y guarda.
- `consume_forest_spawn()` — devuelve el marcador de aparicion (transitorio una vez, si no el
  persistido). Lo usa `forest_main.gd`.
- `is_chest_opened(id)` / `mark_chest_opened(id)` — estado de cofres persistentes
  (`chest.gd` con `@export save_id`). `mark_chest_opened` **solo** marca en memoria; se persiste
  en el proximo `save_game` real (asi no se guarda el cofre abierto sin las monedas que solto).

**Puntos de guardado:** llegada al bosque, `SavePoint` (interactuar), abrir un cofre persistente
(en el siguiente guardado), fin de nivel (`complete_level`) y derrota del jefe final.

### 3. Reglas de Serializacion
- Nunca guardar referencias a nodos o escenas. Solo datos primitivos (lo que hace `SaveManager`).
- El run de cueva NO se persiste (es procedural): si el jugador sale a mitad, reanuda en el bosque.
- Validar el resultado de `ConfigFile.load()/save()` (codigo de error) antes de continuar.

---

## Directrices para IA en Manipulacion de Datos

1. **Generacion Procedural:** La logica del generador esta en `Cave/CaveMain/start_cave.gd`. Para agregar nuevos tipos de sala: anadir la constante `ROOM_TIPO`, agregar un `@export` para la cantidad, incluir en la "bolsa" de tipos, y agregar el case en `layout_1.gd` `configure_room()`.
2. **Nuevas Salas de Contenido:** Crear una escena `.tscn` con el contenido interior y agregarla a `combat_list`, `puzzle_list`, `rest_list` o `boss_list` en el inspector de `Layout1.tscn`. Para la zona del Jefe, el layer (`Stages/Layouts/Cave/Layers/Bosses/`) trae su propio mapa y al jefe ya colocado; se instancia con `_setup_boss()` (sin spawner).
   - **Nuevos Puzzles:** seguir el patron de los existentes (`PuzzleStackQueue`/`PuzzleArithmetic`/`PuzzleLaser`) — emitir `puzzle_solved`/`puzzle_failed`, subir por el arbol hasta el `RoomLayout` y llamar `complete_puzzle()` al resolver (esto cuenta para el desbloqueo del Boss via `room_cleared`). Para feedback usar `player.show_message()`. Si el puzzle tiene aleatoriedad, sortearla solo cuando no este fijada y exponer una API para que la sala la conserve entre reinicios. Si necesita temporizador propio, exponer `begin()`/`halt()` y registrarlo en `_begin_timed_puzzles()`/`_halt_timed_puzzles()`. Para penalizaciones por enemigos, preferir `spawn_penalty_enemies(count)` (cantidad controlada) sobre oleadas completas.
3. **Modificacion de Tilemaps:** Siempre trabajar sobre copias o escenas duplicadas. No editar tilesets base directamente.
4. **Balanceo:** Ajustar valores en propiedades `@export` de los componentes (`HealthComponent.MAX_HEALTH`, `VelocityComponent.speed`) dentro de las escenas `.tscn`, no hardcodeados en scripts. Para dificultad de salas, ajustar `easy_max_enemies`, `medium_max_enemies`, etc. en `Layout1.tscn`.
5. **Nuevos Enemigos:** Crear una escena `.tscn` en `Entities/Enemies/NuevoEnemigo/` siguiendo la estructura de `Chort.tscn` o `Goblin.tscn` (CharacterBody2D + StateMachine + componentes). Agregar como `PackedScene` a una `SpawnCategory` en las pools correspondientes.
6. **Nuevas Puertas/Transiciones:** Seguir el patron de `cave_door.gd` (InteractionArea + signals body_entered/exited + interact() + GameManager.load_scene()). Para puertas dentro de salas procedurales, las transiciones NO son de escena sino de apertura/cierre de colision.
7. **Guardado:** Implementar hooks en `_exit_tree()` o signals de pausa para guardar automatico. Usar `FileAccess` con manejo de errores. Incluir la seed de generacion para reproducibilidad.
8. **Migracion:** Si cambia la estructura de datos, incluir logica de conversion hacia atras en `load_game()`.

---
*Ultima actualizacion: Sistema de guardado real (autoload SaveManager + ConfigFile en user://savegame.cfg: max_flasks, levels_completed, save_location, forest_spawn, opened_chests, boss_defeated, coins). Router de arranque (Stages/Boot/boot.gd como main_scene). Hub del bosque (ForestMain/forest_main.gd: spawn del jugador bajo Sorting, SavePoint, cofre persistente con save_id, entrada Cave al siguiente nivel, BossPortal/Totem). Jefe final Squid + arena LayoutFinal (layout_final.gd). Puerta de avance del Jefe (cave_door.completes_level -> complete_level). GameScenes: FORESTMAIN/MAINBUENO/FINALBOSS. (Lo previo:) Salas de combate por encierro (entras -> se cierran las puertas y aparecen los enemigos; al morir todos, se reabren; spawn diferido al entrar, ya no al instanciar; los enemigos aparecen sobre el piso navegable del layout de combate via _combat_floor(), descartando las celdas-obstaculo). Progreso de puzzles y desbloqueo del Boss (start_cave como administrador del nivel, room_cleared, UI/PuzzlesCounter, _lock/unlock_boss_room). Salas Rest con fogata (Campfire). Spawner con spawn_count (penalizacion controlada). Generador y entrada en Cave/CaveMain/, objetos de mundo en Stages/Elements/. room_type publico. Mecanica de salas de puzzle (bloqueo via RoomTrigger, complete_puzzle/reset_current_puzzle, persistencia del reto, señal puzzle_reset). Generacion procedural (Drunkard's Walk), plantilla RoomLayout, flujo MainBueno -> Cave.*
