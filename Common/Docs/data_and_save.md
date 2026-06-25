# Organización de Datos, Mapas y Sistema de Guardado

## 🗺️ Estructura de Mapas (`Stages/`)
Los niveles se componen mediante escenas modulares y tilemaps optimizados.

### Composición de la Escena Principal
`Stages/Main/Main.tscn` es la escena raíz del juego. Contiene:
- `TilemapLeyers` (instancia de `Layout1/TilemapLeyers.tscn`): capas de tilemap (floor, walls, navigation_floor, decoraciones).
- `Player` (instancia de `Entities/Player/Player.tscn`): jugador con todos sus componentes.
- `Enemies` (`enemy_spawner.gd`): spawner con categorías configurables (`SpawnCategory`).
- `Chest` (instancia de `Entities/Chest/Chest.tscn`): cofre interactuable.
- `TutorialUI`: interfaz del tutorial (oculta por defecto).
- `CanvasLayer` > `PauseMenu`: menú de pausa en capa UI separada.
- `Music` (`AudioStreamPlayer`): música de fondo con autoplay.

### Layouts Disponibles
- `Stages/Layouts/Layout1/TilemapLeyers.tscn`: Layout principal del dungeon con capas de tilemap organizadas por función:
  - `Floor`: Suelo base, sin colisión.
  - `Walls`: Paredes y obstáculos, máscara de colisión activa.
  - `navigation_floor`: Capa para NavigationRegion2D usada por el spawner de enemigos.
  - Decoraciones: Elementos visuales no interactivos.
- `Stages/Layouts/Cave/`: Sistema de cuevas con sub-layouts:
  - `CaveMain/CaveMain.tscn`: Escena principal de la cueva.
  - `Layouts/LayoutCombat/LayoutCombat1.tscn`: Layout de combate dentro de la cueva.
  - `CaveDoor1.tscn`: Puerta interactuable que transiciona escenas vía `GameManager.load_scene()`.

### Carga y Transición de Escenas
- Las transiciones entre escenas se realizan mediante `GameManager.load_scene(scene_path)`, que usa `get_tree().change_scene_to_file()`.
- Las puertas (`cave_door_1.gd`) usan el sistema de interacciones unificado: el jugador se acerca, el objeto se asigna como `current_interactable`, y al presionar la acción de interacción se ejecuta `interact()` → `open_door()`.

## 🎲 Sistema de Spawn de Enemigos
El spawner (`Entities/Enemies/enemy_spawner.gd`) utiliza recursos `SpawnCategory` para configurar el spawn:

```
SpawnCategory (Resource)
├── name: String          — nombre de la categoría (ej: "Pequeñitos", "Mediano")
├── quantity: int         — cantidad a spawnear
└── scenes: PackedScene[] — escenas de enemigos posibles
```

- Se spawnean sobre celdas válidas de la capa `navigation_floor` del tilemap.
- Respeta una distancia mínima configurable desde el jugador (`min_player_distance`).
- Selección aleatoria de celda y escena dentro de cada categoría.

## 💾 Estructura de Datos del Juego
El proyecto separa datos estáticos (balancing, configuración) de datos dinámicos (progreso, inventario).

### 1. Datos Estáticos
- **Formato:** Recursos personalizados `.tres` o scripts con `class_name` (ej: `SpawnCategory`).
- **Uso:** Stats de enemigos (HP y velocidad en `@export` de `HealthComponent` y `VelocityComponent`), categorías de spawn, parámetros de física.
- **Ubicación:** Configurados directamente en las escenas `.tscn` de cada entidad o como sub-recursos en las escenas de nivel.

### 2. Datos Dinámicos y Persistencia
- **Formato:** `ConfigFile` para ajustes del usuario, `JSON` o serialización binaria para progreso.
- **Ruta de Guardado:** `user://save_data/` (accesible vía `OS.get_user_data_dir()`).
- **Gestión:** `GameManager` centraliza el estado de monedas en runtime (señal `coins_updated`).
- **Estructura JSON sugerida:**
  ```json
  {
	"player": { "position": [x, y], "health": 100, "coins": 50 },
	"flags": { "tutorial_completed": true, "boss_defeated": false },
	"stage": "Layout1"
  }
  ```

### 3. Reglas de Serialización
- Nunca guardar referencias a nodos o escenas. Solo datos primitivos o estructuras convertibles.
- Usar `var_to_str()` / `str_to_var()` para objetos complejos si es necesario, pero preferir JSON legible para depuración.
- Validar integridad del archivo al cargar (versión de save, checksum básico).

## 🤖 Directrices para IA en Manipulación de Datos
1. **Modificación de Tilemaps:** Siempre trabajar sobre copias o escenas duplicadas. No editar tilesets base directamente.
2. **Balanceo:** Ajustar valores en propiedades `@export` de los componentes (`HealthComponent.MAX_HEALTH`, `VelocityComponent.speed`) dentro de las escenas `.tscn`, no hardcodeados en scripts.
3. **Nuevos Enemigos:** Crear una escena `.tscn` en `Entities/Enemies/NuevoEnemigo/` siguiendo la estructura de `Chort.tscn` o `Goblin.tscn` (CharacterBody2D + StateMachine + componentes). Agregar como `PackedScene` a una `SpawnCategory`.
4. **Guardado:** Implementar hooks en `_exit_tree()` o señales de pausa para guardar automático. Usar `FileAccess` con manejo de errores (`ERR_FILE_NOT_FOUND`, etc.).
5. **Migración:** Si cambia la estructura de datos, incluir lógica de conversión hacia atrás en `load_game()`.

---
*Última actualización: Documentación del sistema de spawn, layouts de cueva, composición de Main.tscn.*
