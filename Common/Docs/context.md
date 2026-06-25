# Contexto del Proyecto Godot - Guia de Referencia para IA

## Jerarquia de Directorios
La estructura sigue un patron modular orientado a componentes y escenas reutilizables. Cada carpeta tiene un proposito estricto:

| Directorio | Proposito | Contenido Clave |
|------------|-----------|-----------------|
| `Assets/` | Recursos estaticos sin logica ejecutable. | Audio (`Audio/`), Fuentes (`Fonts/`). No se adjuntan scripts aqui. |
| `Common/` | Logica transversal y reutilizable. | Maquina de estados base (`StateMachine/`), estados compartidos (`States/`), documentacion arquitectonica (`Docs/`). |
| `Entities/` | Nodos instanciables del juego (Jugador, Enemigos, Objetos). | Escenas `.tscn`, scripts de comportamiento, componentes reutilizables en `Scripts/Character/`. |
| `Entities/Player/Art/` | Spritesheets del jugador. | `Idle.png`, `Walk.png`, `Attack.png`, `Hit.png` — layout de 4 filas (down, right, up, left) x N columnas, 32x32 por frame. |
| `Stages/` | Composicion de niveles, generacion procedural y escena raiz. | Tilemaps, layouts (Layout1, Cave), escena principal (`Main/MainBueno.tscn`), generador procedural (`Cave/start_cave.gd`). |
| `Stages/Layouts/Cave/` | Sistema de cuevas procedurales. | Generador (`start_cave.gd`), plantilla de sala (`layout_1.gd`/`Layout1.tscn`), puertas (`Environment/`), escena entrada (`StartCave.tscn`). |
| `Utilities/` | Gestion global, UI y sistemas auxiliares. | Singletons/Autoloads, menus (pausa, principal, game over), barras de vida, contadores, gestion de audio/tutorial. |

## Singletons (Autoloads) Vigentes
Los siguientes scripts funcionan como nodos raiz globales (`/root/`), registrados en `Project Settings > Autoload`:

| Singleton | Ruta | Responsabilidad |
|-----------|------|-----------------|
| `GameManager` | `Utilities/game_manager.gd` | Monedas (signal `coins_updated`), transicion de escenas via `load_scene(path)`. |
| `SoundManager` | `Utilities/sound_manager.gd` | Reproduccion fire-and-forget de SFX via `play_sound(stream)`. Crea `AudioStreamPlayer` temporal, lo libera al terminar. |
| `TutorialManager` | `Utilities/TutorialManager.gd` | Tracking de pasos del tutorial (`moverse`, `atacar`, `curar`). Signals `mostrar_mensaje(texto)` / `ocultar_mensaje()`. Se inicia con `iniciar_tutorial()`. |

> **Nota para IA:** Nunca instancies estos nodos manualmente. Accede a ellos directamente por su nombre (`GameManager.load_scene(path)`). Si necesitas anadir un nuevo singleton, registralo en `Project Settings > Autoload` y actualiza esta tabla.

## Script del Jugador
El jugador (`Entities/Player/Player.tscn`) es un `CharacterBody2D` con script raiz `Entities/Player/player.gd`:
- `var current_interactable: Node` — referencia al objeto interactuable cercano (asignada por los propios interactuables).
- En `_ready()`, ejecuta `_crear_animaciones_direccionales()` que genera animaciones con sufijo de direccion (`idle_down`, `walk_right`, `attack_up`, etc.) desde los spritesheets usando `AtlasTexture`.
- En `_process()`, si `input_component.input_action` y `current_interactable` no es nulo, invoca `current_interactable.interact()`.
- Las animaciones originales sin sufijo se mantienen como fallback para entidades sin spritesheets direccionales (enemigos).
- Ver `architecture.md` para el patron completo de animaciones y el sistema de interacciones.

## Convenciones de Desarrollo
- **Nomenclatura:** `snake_case` para scripts y variables, `PascalCase` para clases/nodos personalizados.
- **Signals:** Usar sintaxis nativa Godot 4: `signal_name.emit(args)`. Nunca usar la forma obsoleta `emit_signal("nombre", args)`.
- **Input centralizado:** Solo `PlayerInputComponent` y `EnemyInputComponent` pueden leer de `Input`. Los objetos del entorno (`Stages/`, `Entities/Chest/`, etc.) nunca llaman a `Input.is_action_just_pressed()` directamente; usan el sistema de interacciones.
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
*Ultima actualizacion: Animaciones direccionales del Player, directorio Cave procedural, escena principal actualizada a MainBueno.tscn.*
