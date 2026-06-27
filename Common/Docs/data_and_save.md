# Organizacion de Datos, Mapas, Generacion Procedural y Sistema de Guardado

## Estructura de Mapas (`Stages/`)
Los niveles se componen mediante escenas modulares, tilemaps optimizados y un generador procedural.

### Escenas Principales

| Escena | Ruta | Proposito |
|--------|------|-----------|
| `MainBueno.tscn` | `Stages/Main/MainBueno.tscn` | **Escena raiz del juego** (configurada en project.godot). Area de inicio con tilemap, jugador y puerta de entrada a la cueva. |
| `Main.tscn` | `Stages/Main/Main.tscn` | Layout legacy del dungeon (pre-procedural). Contiene tilemap estatico, spawner de enemigos, cofre, tutorial y menu de pausa. |
| `StartCave.tscn` | `Stages/Layouts/Cave/StartCave.tscn` | Punto de entrada al sistema procedural. Ejecuta `start_cave.gd` para generar el mapa de cueva. |

### Flujo de Juego Completo
```
MainBueno.tscn (area de inicio)
       |
       | Jugador interactua con CaveDoor1
       v
GameManager.load_scene("res://Stages/Layouts/Cave/StartCave.tscn")
       |
       v
StartCave.tscn -> start_cave.gd._ready()
       |
       |-- seed(generation_seed) o randomize()
       |-- generate_map()  -> Drunkard's Walk + asignacion de tipos
       +-- build_rooms()   -> Instancia N copias de Layout1.tscn
              |
              +-- Cada Layout1: configure_room(tipo, N, S, E, W)
                     |-- Abre/cierra puertas segun vecinos
                     |-- Inyecta pools de enemigos al spawner
                     +-- Instancia contenido interior (combat/puzzle/rest)
```

---

## Generacion Procedural de Cuevas

### Arquitectura del Generador (`start_cave.gd`)
El generador vive en `Stages/Layouts/Cave/start_cave.gd` y extiende `Node2D`. Implementa el algoritmo **Drunkard's Walk** para crear una cuadricula organica de salas conectadas.

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
1. **Start**: Siempre en `(0, 0)`. Sala inicial sin enemigos ni contenido.
2. **Boss**: Se ubica en la coordenada con mayor **distancia Manhattan** desde `(0, 0)`. Garantiza que el jugador recorra el mapa para llegar.
3. **Resto**: Se construye una "bolsa" con las cantidades exactas de cada tipo (Easy, Medium, Hard, Puzzle, Rest), se mezcla aleatoriamente (`shuffle()`), y se asigna en orden a las coordenadas restantes.

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

| Tipo | Combate? | Max Enemigos | Pools | Interior |
|------|----------|-------------|-------|----------|
| Start | No | 0 | Ninguno | Ninguno |
| Easy | Si | 4 | `easy_combat` | Aleatorio de `combat_list` |
| Medium | Si | 6 | `medium_combat` | Aleatorio de `combat_list` |
| Hard | Si | 8 | `hard_combat` | Aleatorio de `combat_list` |
| Boss | Si | 1 | `boss_combat` | Aleatorio de `combat_list` |
| Puzzle | No | 0 | Ninguno | Aleatorio de `puzzle_list` |
| Rest | No | 0 | Ninguno | Aleatorio de `rest_list` |

**Listas de contenido (@export):**
- `combat_list: Array[PackedScene]` — Layouts internos de combate (obstaculos, decoracion).
- `puzzle_list: Array[PackedScene]` — Contenido de salas puzzle.
- `rest_list: Array[PackedScene]` — Contenido de salas de descanso.

### Mecanica de Salas de Puzzle
Las salas de tipo Puzzle encierran al jugador hasta que resuelve el puzzle. El `RoomTrigger` (un `Area2D` con mascara en la capa 7 = player) gestiona el ciclo:

1. **Entrada** (`_on_room_trigger_entered`): asigna `body.current_room = self`. Si la sala es Puzzle y no esta resuelta, cierra todas las puertas activas (`_close_all_active_doors()`, las vuelve muro con colision) y muestra la pista del orden **una sola vez** (`_show_puzzle_hint()` -> `_hint_shown`).
2. **Salida** (`_on_room_trigger_exited`): limpia `current_room` (evita reiniciar la sala desde fuera).
3. **Resolucion** (`complete_puzzle()`, llamada por el propio puzzle al resolverse): marca `is_puzzled_cleared = true` y reabre las puertas restaurando la configuracion original guardada en `configure_room()`.
4. **Reinicio** (`reset_current_puzzle()`, disparada por el input `reset` del jugador): destruye el contenido actual de `Content` e instancia una copia limpia de `_current_puzzle_scene`. Se ignora si la sala ya esta resuelta.

**Persistencia del reto del puzzle:** al instanciar el puzzle por primera vez (`_setup_peaceful`), si es un `PuzzleStackQueue` la sala guarda su modo y secuencia (`_puzzle_mode`, `_puzzle_order`). En cada reinicio los reimpone con `apply_fixed_config()` ANTES de anadir el nodo al arbol, para que el reto (Pila/Cola y orden) no cambie entre intentos. Ver el detalle del puzzle en `architecture.md`.

**Señal `puzzle_reset`:** emitida tras reinstanciar el contenido en `reset_current_puzzle()`, por si la UI o sistemas externos necesitan reconectarse al nuevo contenido.

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
Ubicado en `Entities/Enemies/enemy_spawner.gd`, extiende `Node2D`.

**Propiedades @export:**
```
spawn_categories: Array[SpawnCategory]  -- Pools de enemigos (inyectadas por RoomLayout)
max_enemies: int = 5                    -- Limite maximo de enemigos
node_floor_layer: Node2D                -- Referencia al nodo padre de TileMapLayers
player: Node2D                          -- Referencia al jugador
min_player_distance: float = 150.0      -- Distancia minima al jugador para spawn
```

**Algoritmo de Spawn:**
1. En `_ready()`, obtiene la capa `navigation_floor` del `node_floor_layer`.
2. Ejecuta `spawn_all_categories()` de forma diferida (`call_deferred`).
3. Fuerza actualizacion del mapa de navegacion: `NavigationServer2D.map_force_update()`.
4. Para cada `SpawnCategory`:
   a. Elige una celda aleatoria de `navigation_floor.get_used_cells()`.
   b. Convierte a posicion global con `map_to_local()` + `to_global()`.
   c. Verifica que la posicion este a mas de `min_player_distance` del jugador.
   d. Elige una escena aleatoria de `category.scenes` e instancia.
   e. Limite de intentos: `category.quantity * 5` para evitar bucles.
5. Si `spawn_categories` esta vacio, no spawnea nada (sala pacifica).

**Integracion con Generacion Procedural:**
El spawner no sabe que tipo de sala es. `RoomLayout.configure_room()` inyecta las pools correctas y el `max_enemies` antes de que el spawner ejecute su `_ready()` diferido. Para salas pacificas (Start, Puzzle, Rest), `_clear_spawner()` vacia las categorias.

---

## Sistema de Puertas

### Puerta de Entrada (`cave_door.gd`)
`Stages/Layouts/Cave/Environment/cave_door.gd` — Puerta interactuable en la escena de inicio.

**Flujo:**
1. El jugador entra al `InteractionArea` del `Area2D`.
2. `body_entered` -> asigna `body.current_interactable = self`.
3. El jugador presiona la accion de interaccion.
4. `interact()` -> `open()` -> emite `door_interacted` y llama `GameManager.load_scene("res://.../StartCave.tscn")`.

**Escenas de puertas:**
- `CaveDoor1.tscn`: Puerta de entrada a la cueva procedural (en MainBueno.tscn).
- `CaveDoor2.tscn`: Puerta interna de cueva (disponible para uso futuro).
- `CaveWall.tscn`: Muro visual usado como puerta cerrada en salas procedurales.

### Puertas Procedurales (dentro de Layout1)
Las 4 puertas de cada sala (NorthDoor, SouthDoor, EastDoor, WestDoor) **no** transicionan escenas. Son muros o pasillos abiertos segun la vecindad en la cuadricula. Su `InteractionArea` se desactiva para evitar conflictos con el sistema de interacciones.

---

## Datos Estaticos y Dinamicos

### 1. Datos Estaticos
- **Formato:** Recursos personalizados `.tres` o scripts con `class_name` (ej: `SpawnCategory`).
- **Uso:** Stats de enemigos (HP y velocidad en `@export` de `HealthComponent` y `VelocityComponent`), categorias de spawn, parametros de fisica.
- **Ubicacion:** Configurados directamente en las escenas `.tscn` de cada entidad o como sub-recursos en las escenas de nivel.

### 2. Datos Dinamicos y Persistencia
- **Formato:** `ConfigFile` para ajustes del usuario, `JSON` o serializacion binaria para progreso.
- **Ruta de Guardado:** `user://save_data/` (accesible via `OS.get_user_data_dir()`).
- **Gestion:** `GameManager` centraliza el estado de monedas en runtime (signal `coins_updated`).
- **Estructura JSON sugerida:**
  ```json
  {
    "player": { "position": [x, y], "health": 100, "coins": 50 },
    "flags": { "tutorial_completed": true, "boss_defeated": false },
    "stage": "Cave",
    "seed": 12345
  }
  ```

### 3. Reglas de Serializacion
- Nunca guardar referencias a nodos o escenas. Solo datos primitivos o estructuras convertibles.
- Usar `var_to_str()` / `str_to_var()` para objetos complejos si es necesario, pero preferir JSON legible para depuracion.
- Validar integridad del archivo al cargar (version de save, checksum basico).
- Para reproducibilidad de mapas procedurales, guardar la `generation_seed` usada.

---

## Directrices para IA en Manipulacion de Datos

1. **Generacion Procedural:** La logica del generador esta en `start_cave.gd`. Para agregar nuevos tipos de sala: anadir la constante `ROOM_TIPO`, agregar un `@export` para la cantidad, incluir en `_build_room_bag()`, y agregar el case en `layout_1.gd` `configure_room()`.
2. **Nuevas Salas de Contenido:** Crear una escena `.tscn` con el contenido interior y agregarla a `combat_list`, `puzzle_list` o `rest_list` en el inspector de `Layout1.tscn`.
   - **Nuevos Puzzles:** seguir el patron de `PuzzleStackQueue` — emitir `puzzle_solved`/`puzzle_failed`, subir por el arbol hasta el `RoomLayout` y llamar `complete_puzzle()` al resolver. Para feedback usar `player.show_message()`. Si el puzzle tiene aleatoriedad, sortearla solo cuando no este fijada y exponer una API tipo `apply_fixed_config()` para que la sala la conserve entre reinicios.
3. **Modificacion de Tilemaps:** Siempre trabajar sobre copias o escenas duplicadas. No editar tilesets base directamente.
4. **Balanceo:** Ajustar valores en propiedades `@export` de los componentes (`HealthComponent.MAX_HEALTH`, `VelocityComponent.speed`) dentro de las escenas `.tscn`, no hardcodeados en scripts. Para dificultad de salas, ajustar `easy_max_enemies`, `medium_max_enemies`, etc. en `Layout1.tscn`.
5. **Nuevos Enemigos:** Crear una escena `.tscn` en `Entities/Enemies/NuevoEnemigo/` siguiendo la estructura de `Chort.tscn` o `Goblin.tscn` (CharacterBody2D + StateMachine + componentes). Agregar como `PackedScene` a una `SpawnCategory` en las pools correspondientes.
6. **Nuevas Puertas/Transiciones:** Seguir el patron de `cave_door.gd` (InteractionArea + signals body_entered/exited + interact() + GameManager.load_scene()). Para puertas dentro de salas procedurales, las transiciones NO son de escena sino de apertura/cierre de colision.
7. **Guardado:** Implementar hooks en `_exit_tree()` o signals de pausa para guardar automatico. Usar `FileAccess` con manejo de errores. Incluir la seed de generacion para reproducibilidad.
8. **Migracion:** Si cambia la estructura de datos, incluir logica de conversion hacia atras en `load_game()`.

---
*Ultima actualizacion: Mecanica de salas de puzzle (bloqueo de puertas via RoomTrigger, complete_puzzle/reset_current_puzzle, persistencia del reto entre reinicios, señal puzzle_reset). Generacion procedural (Drunkard's Walk), plantilla RoomLayout, flujo MainBueno -> Cave, puertas procedurales.*
