# Contexto del Proyecto Godot - Guía de Referencia para IA

## 📁 Jerarquía de Directorios
La estructura sigue un patrón modular orientado a componentes y escenas reutilizables. Cada carpeta tiene un propósito estricto:

| Directorio | Propósito | Contenido Clave |
|------------|-----------|-----------------|
| `Assets/`  | Recursos estáticos sin lógica ejecutable. | Audio (`Audio/`), Fuentes (`Fonts/`). No se adjuntan scripts aquí. |
| `Common/`  | Lógica transversal y reutilizable. | Máquina de estados base (`StateMachine/`), estados compartidos (`States/`), documentación arquitectónica (`Docs/`). |
| `Entities/`| Nodos instanciables del juego (Jugador, Enemigos, Objetos). | Escenas `.tscn`, scripts de comportamiento, componentes reutilizables en `Scripts/Character/`. |
| `Stages/`  | Composición de niveles y escena raíz. | Tilemaps, layouts (Layout1, Cave), escena principal (`Main/Main.tscn`), lógica de transición entre escenas. |
| `Utilities/`| Gestión global, UI y sistemas auxiliares. | Singletons/Autoloads, menús (pausa, principal, game over), barras de vida, contadores, gestión de audio/tutorial. |

## 🔗 Singletons (Autoloads) Vigentes
Los siguientes scripts funcionan como nodos raíz globales (`/root/`), registrados en `Project Settings > Autoload`:

| Singleton | Ruta | Responsabilidad |
|-----------|------|-----------------|
| `GameManager` | `Utilities/game_manager.gd` | Monedas (señal `coins_updated`), transición de escenas vía `load_scene(path)`. |
| `SoundManager` | `Utilities/sound_manager.gd` | Reproducción fire-and-forget de SFX vía `play_sound(stream)`. Crea `AudioStreamPlayer` temporal, lo libera al terminar. |
| `TutorialManager` | `Utilities/TutorialManager.gd` | Tracking de pasos del tutorial (`moverse`, `atacar`, `curar`). Señales `mostrar_mensaje(texto)` / `ocultar_mensaje()`. Se inicia con `iniciar_tutorial()`. |

> ⚠️ **Nota para IA:** Nunca instancies estos nodos manualmente. Accede a ellos directamente por su nombre (`GameManager.load_scene(path)`). Si necesitas añadir un nuevo singleton, regístralo en `Project Settings > Autoload` y actualiza esta tabla.

## 🎮 Script del Jugador
El jugador (`Entities/Player/Player.tscn`) es un `CharacterBody2D` con script raíz `Entities/Player/player.gd`:
- `var current_interactable: Node` — referencia al objeto interactuable cercano (asignada por los propios interactuables).
- En `_process()`, si `input_component.input_action` y `current_interactable` no es nulo, invoca `current_interactable.interact()`.
- Este script es el puente central del sistema de interacciones. Ver `architecture.md` para el patrón completo.

## 🧠 Convenciones de Desarrollo
- **Nomenclatura:** `snake_case` para scripts y variables, `PascalCase` para clases/nodos personalizados.
- **Señales:** Usar sintaxis nativa Godot 4: `signal_name.emit(args)`. Nunca usar la forma obsoleta `emit_signal("nombre", args)`.
- **Input centralizado:** Solo `PlayerInputComponent` y `EnemyInputComponent` pueden leer de `Input`. Los objetos del entorno (`Stages/`, `Entities/Chest/`, etc.) nunca llaman a `Input.is_action_just_pressed()` directamente; usan el sistema de interacciones.
- **Scripts:** Adjuntados a escenas o componentes específicos. No se usan scripts "huérfanos" fuera de `Common/` o `Utilities/`.
- **Recursos:** `.tres`/`.res` para datos estáticos (stats de enemigos, categorías de spawn). `.json`/`ConfigFile` solo para guardado dinámico.
- **Carga de Escenas:** Uso de `PackedScene` y `instantiate()` para entidades. Transiciones de escena vía `GameManager.load_scene(path)`.

## 🏗️ Capas de Física

| Capa | Nombre | Uso |
|------|--------|-----|
| 1 | `environment` | Paredes, obstáculos |
| 2 | `hurtbox` | Áreas receptoras de daño |
| 3 | `hitbox` | Áreas de daño (enemigos) |
| 4 | `enemies` | Cuerpos de enemigos |
| 5 | `collectibles` | Monedas, pickups |
| 6 | `hitbox_player` | Áreas de ataque del jugador |
| 7 | `player` | Cuerpo del jugador |
| 8 | `interactive` | Puertas, cofres |

---
*Última actualización: Refactorización de interacciones, centralización de input, documentación de capas de física.*
	
