# Contexto del Proyecto Godot - Guia de Referencia para IA

## Jerarquia de Directorios
La estructura sigue un patron modular orientado a componentes y escenas reutilizables. Cada carpeta tiene un proposito estricto:

| Directorio | Proposito | Contenido Clave |
|------------|-----------|-----------------|
| `Assets/` | Recursos estaticos sin logica ejecutable. | Audio (`Audio/`), Fuentes (`Fonts/`). No se adjuntan scripts aqui. |
| `Common/` | Logica transversal y reutilizable. | Maquina de estados base (`StateMachine/`), estados compartidos (`States/`), documentacion arquitectonica (`Docs/`). |
| `Entities/` | Nodos instanciables del juego (Jugador, Enemigos, Objetos). | Escenas `.tscn`, scripts de comportamiento, componentes reutilizables en `Scripts/Character/`. |
| `Entities/Player/Art/` | Spritesheets del jugador. | `Idle.png`, `Walk.png`, `Attack.png`, `Hit.png` — layout de 4 filas (down, right, up, left) x N columnas, 32x32 por frame. |
| `Stages/` | Composicion de niveles, generacion procedural y escena raiz. | Tilemaps, layouts (Layout1, Cave), escena principal (`Main/MainBueno.tscn`), generador procedural (`Cave/CaveMain/start_cave.gd`), objetos de mundo (`Elements/`). |
| `Stages/Elements/` | Objetos de mundo reutilizables (no son salas ni puzzles completos). | Cajas empujables (`box.gd`/`Box`), placas de presion (`pressure_plate.gd`/`PressurePlate`), interruptores (`interrupter.gd`/`Interrupter`), fogata (`campfire.gd`/`Campfire`), y piezas del puzzle de laser (`Laser`, `Receptor`, `Totem`). |
| `Stages/Layouts/Cave/` | Sistema de cuevas procedurales. | Generador (`CaveMain/start_cave.gd`), plantilla de sala (`layout_1.gd`/`Layout1.tscn`), puertas (`Environment/`), escena entrada (`CaveMain/StartCave.tscn`), contenido de salas (`Layers/`). |
| `Stages/Layouts/Cave/Environment/` | Puertas de cueva (los demas objetos de mundo se movieron a `Stages/Elements/`). | `cave_door.gd`/`CaveDoor1`/`CaveDoor2`/`CaveWall`. |
| `Stages/Layouts/Cave/Layers/Puzzle/` | Puzzles instanciables en salas de tipo Puzzle. | `PuzzleStackQueue` (Pila/Cola), `PuzzleArithmetic` (residuo modular con temporizador), `PuzzleLaser` (compuertas logicas). |
| `Stages/Layouts/Cave/Layers/Rest/` | Contenido de salas de descanso. | `RestRoom.tscn` — incluye la fogata (`Campfire`) que restaura vida y frascos. |
| `Stages/Boot/` | Router de arranque (escena raiz). | `Boot.tscn`/`boot.gd` — lee el guardado y entra a `ForestMain` o `MainBueno`. |
| `Stages/Layouts/Forest/` | Hub central del juego. | `ForestMain.tscn`/`forest_main.gd` (spawn del jugador bajo `Sorting`, SavePoint, cofre, Cave, BossPortal), `BossPortal/` (`boss_portal.gd` = Totem al jefe final). |
| `Stages/Layouts/FinalBoss/` | Arena del jefe final. | `LayoutFinal.tscn`/`layout_final.gd` con el `Squid` y un `RoomTrigger`. |
| `Entities/Bosses/` | Jefes. | `Samurai/` (cueva) y `Squid/` (jefe final: `squid.gd`, `States/`, `Projectile/SquidProjectile.tscn`). |
| `Stages/Elements/SavePoint/` | Punto de guardado del bosque. | `SavePoint.tscn`/`save_point.gd` — cura y guarda al interactuar. `Cave.tscn`/`cave_entrance.gd` = entrada al siguiente nivel. |
| `Utilities/` | Gestion global, UI y sistemas auxiliares. | Singletons/Autoloads, menus (pausa, principal, game over), barras de vida, contadores, gestion de audio/tutorial. |
| `Utilities/UI/MessageUI/` | Mensaje reutilizable en pantalla. | `Message.tscn` (`MessageUI`: Panel animado + Label con la fuente pixel-art). El panel se desliza al entrar/salir; expone `show_message()`/`hide_message()`. Usado por el jugador para feedback efimero (pistas de puzzle, guardado, jefe). |
| `Utilities/UI/MapOverlay/` | Overlay de mapa del nivel procedural. | `MapOverlay.tscn` (`map_overlay.gd`). Se descubre por sala (accion `map`/tecla M), pausa el juego. Instanciado bajo el `CanvasLayer` de `StartCave.tscn`. Ver `architecture.md`. |
| `Utilities/UI/PauseMenu/` | Menu de pausa reutilizable. | `pause_menu.tscn`. Instanciado bajo el `CanvasLayer` de las escenas jugables (`StartCave.tscn`, `ForestMain.tscn`). |
| `Utilities/UI/MainMenu/` | Menu principal. | `MainMenu.tscn`/`MainMenu.gd`. START entra al router `Boot`; NEW GAME llama `SaveManager.reset_save()` (borra el guardado) y entra a `Boot`. |
| `Utilities/UI/PuzzlesCounter/` | Contador de progreso de puzzles del nivel. | `PuzzlesCounter.tscn` (icono + Label `"Puzzles: X / Y"`). Vive bajo `UI/PuzzlesCounter` del jugador; lo controla `start_cave.gd`. |

## Singletons (Autoloads) Vigentes
Los siguientes scripts funcionan como nodos raiz globales (`/root/`), registrados en `Project Settings > Autoload`:

| Singleton | Ruta | Responsabilidad |
|-----------|------|-----------------|
| `GameManager` | `Utilities/game_manager.gd` | Monedas (signal `coins_updated`), transicion de escenas via `load_scene(path)`. |
| `SaveManager` | `Utilities/save_manager.gd` | **Guardado de la partida** (ConfigFile en `user://savegame.cfg`): frascos maximos, niveles completados, punto de guardado, cofres abiertos, jefe final derrotado, monedas. Registrar **despues** de `GameManager`. Ver `data_and_save.md`. |
| `SoundManager` | `Utilities/sound_manager.gd` | Reproduccion fire-and-forget de SFX via `play_sound(stream)`. Crea `AudioStreamPlayer` temporal, lo libera al terminar. |
| `TutorialManager` | `Utilities/TutorialManager.gd` | Tracking de pasos del tutorial (`moverse`, `atacar`, `curar`). Signals `mostrar_mensaje(texto)` / `ocultar_mensaje()`. Se inicia con `iniciar_tutorial()`. |

> **Nota para IA:** Nunca instancies estos nodos manualmente. Accede a ellos directamente por su nombre (`GameManager.load_scene(path)`). Si necesitas anadir un nuevo singleton, registralo en `Project Settings > Autoload` y actualiza esta tabla.

## Script del Jugador
El jugador (`Entities/Player/Player.tscn`) es un `CharacterBody2D` con script raiz `Entities/Player/player.gd`:
- `var current_interactable: Node` — referencia al objeto interactuable cercano (asignada por los propios interactuables).
- `var current_room: Node` — sala (`RoomLayout`) en la que se encuentra el jugador, asignada por el `RoomTrigger` de la sala. La usa el input de reset para saber que puzzle reiniciar.
- En `_ready()`, ejecuta `_crear_animaciones_direccionales()` que genera animaciones con sufijo de direccion (`idle_down`, `walk_right`, `attack_up`, etc.) desde los spritesheets usando `AtlasTexture`. Tambien deja oculto el Label de mensajes.
- En `_process()`, si `input_component.input_action` y `current_interactable` no es nulo, invoca `current_interactable.interact()`; si `input_component.input_reset` y hay `current_room`, llama `current_room.reset_current_puzzle()`.
- `show_message(text, duration = 3.0)` — **delega** en `message_ui.show_message(...)` (instancia de `MessageUI/Message.tscn` bajo `UI/Message`, referencia `@onready message_ui: MessageUI`). Toda la presentacion (panel animado deslizante, token anti-temporizador-viejo) vive en `message_ui.gd`; `player.gd` ya no toca el Label. Es el canal de feedback que usan los puzzles y demas sistemas. Ver `architecture.md`.
- **Parry / Guard Break:** con la accion `parry` (clic derecho) entra al estado `Parry` (refleja proyectiles del jefe). `on_projectile_reflected()` cuenta reflejos y cada 3 dispara un Guard Break (aturde al jefe + abre ventana de critico); `consume_crit_multiplier()` aplica el ×3 al siguiente golpe. Ver `architecture.md`.
- Las animaciones originales sin sufijo se mantienen como fallback para entidades sin spritesheets direccionales (enemigos).
- El nodo `UI` del jugador hospeda elementos de HUD reutilizables que sistemas externos localizan por ruta: `UI/Message` (mensajes efimeros) y `UI/PuzzlesCounter` (contador de puzzles, controlado por `start_cave.gd` y oculto fuera del dungeon).
- Ver `architecture.md` para el patron completo de animaciones, interacciones y el sistema de puzzles.

## Convenciones de Desarrollo
- **Nomenclatura:** `snake_case` para scripts y variables, `PascalCase` para clases/nodos personalizados.
- **Signals:** Usar sintaxis nativa Godot 4: `signal_name.emit(args)`. Nunca usar la forma obsoleta `emit_signal("nombre", args)`.
- **Input centralizado:** Solo `PlayerInputComponent` y `EnemyInputComponent` pueden leer de `Input`. Los objetos del entorno (`Stages/`, `Entities/Chest/`, etc.) nunca llaman a `Input.is_action_just_pressed()` directamente; usan el sistema de interacciones. Acciones definidas en `project.godot` incluyen `parry` (clic derecho, estado `Parry`) y `map` (tecla M, abre/cierra el overlay de mapa). El overlay de mapa (`map_overlay.gd`) lee `Input` directamente porque es un nodo de UI global, no una entidad del mundo.
- **Animaciones direccionales:** El Player usa `play_directional_anim("base_name")` en los estados, que busca `base_name_{direction}` y hace fallback a `base_name`. Los enemigos usan `scale.x` para flip horizontal. No mezclar ambos enfoques en la misma entidad.
- **Scripts:** Adjuntados a escenas o componentes especificos. No se usan scripts "huerfanos" fuera de `Common/` o `Utilities/`.
- **Recursos:** `.tres`/`.res` para datos estaticos (stats de enemigos, categorias de spawn). `.json`/`ConfigFile` solo para guardado dinamico.
- **Carga de Escenas:** Uso de `PackedScene` y `instantiate()` para entidades. Transiciones de escena via `GameManager.load_scene(path)`.

## Capas de Fisica

| Capa | Nombre | Uso |
|------|--------|-----|
| 1 | `environment` | Paredes, obstaculos |
| 2 | `hurtbox` | Areas receptoras de dano |
| 3 | `hitbox` | Areas de dano (enemigos) |
| 4 | `enemies` | Cuerpos de enemigos |
| 5 | `collectibles` | Monedas, pickups |
| 6 | `hitbox_player` | Areas de ataque del jugador |
| 7 | `player` | Cuerpo del jugador |
| 8 | `interactive` | Puertas, cofres |

---
*Ultima actualizacion: Overlay de mapa del nivel (Utilities/UI/MapOverlay, accion `map`/tecla M, descubrimiento por sala, pausa el juego). MessageUI como clase con panel animado (show_message/hide_message; player.gd delega). MainMenu START via router Boot y NEW GAME via SaveManager.reset_save(). PauseMenu instanciado tambien en ForestMain. (Lo previo:) Sistema de guardado (autoload SaveManager). Router de arranque (Stages/Boot). Hub del bosque (Stages/Layouts/Forest: forest_main, SavePoint, Cave, BossPortal/Totem). Jefe final (Entities/Bosses/Squid + Stages/Layouts/FinalBoss). Parry + Guard Break (accion parry / clic derecho, estado Parry, critico x3). (Lo previo:) Reorganizacion de objetos de mundo a `Stages/Elements/` (Box, PressurePlate, Interrupter, Campfire, piezas de Laser); `Environment/` queda solo con puertas. Generador y entrada movidos a `Cave/CaveMain/`. Nuevos puzzles (Arithmetic, Laser) y salas de descanso con fogata. Contador de puzzles (`UI/PuzzlesCounter`). Sistema de puzzles, mensaje de UI reutilizable, current_room e input_reset, show_message(). Animaciones direccionales, directorio Cave procedural, escena principal MainBueno.tscn.*
