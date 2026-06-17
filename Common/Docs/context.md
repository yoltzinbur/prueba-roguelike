# Contexto del Proyecto Godot - Guía de Referencia para IA

## 📁 Jerarquía de Directorios
La estructura sigue un patrón modular orientado a componentes y escenas reutilizables. Cada carpeta tiene un propósito estricto:

| Directorio | Propósito | Contenido Clave |
|------------|-----------|-----------------|
| `Assets/`  | Recursos estáticos sin lógica ejecutable. | Audio (`Audio/`), Fuentes (`Fonts/`). No se adjuntan scripts aquí. |
| `Common/`  | Lógica transversal y reutilizable. | Máquina de estados base, estados compartidos, utilidades matemáticas o extensiones de clases nativas. |
| `Entities/`| Nodos instanciables del juego (Jugador, Enemigos, Objetos). | Escenas `.tscn`, scripts de comportamiento, componentes físicos/lógicos (`hitbox`, `hurtbox`, `input`, `navigation`, `health`, `velocity`). |
| `Stages/`  | Composición de niveles y escena raíz. | Tilemaps, layouts, escena principal (`Main.tscn`), lógica de carga de nivel. |
| `Utilities/`| Gestión global, UI y sistemas auxiliares. | Singletons/Autoloads, menús, barras de vida, contadores, gestión de audio/tutorial. |

## 🔗 Singletons (Autoloads) Vigentes
Basado en la estructura del repositorio, los siguientes scripts funcionan como nodos raíz globales (`/root/`):

| Singleton | Ruta | Responsabilidad |
|-----------|------|-----------------|
| `GameManager` | `Utilities/game_manager.gd` | Estado global del juego, transición de escenas, control de flujo principal, persistencia básica. |
| `SoundManager` | `Utilities/sound_manager.gd` | Reproducción de SFX/BGM, gestión de canales, volúmenes, pausado/reanudado de audio. |
| `TutorialManager` | `Utilities/TutorialManager.gd` | Control de flags de tutorial, desbloqueo progresivo de mecánicas, sincronización con UI. |

> ⚠️ **Nota para IA:** Nunca instancies estos nodos manualmente. Accede a ellos directamente por su nombre (`GameManager.some_method()`). Si necesitas añadir un nuevo singleton, regístralo en `Project Settings > Autoload` y actualiza esta tabla.

## 🧠 Convenciones de Desarrollo
- **Nomenclatura:** `snake_case` para scripts y variables, `PascalCase` para clases/nodos personalizados.
- **Scripts:** Adjuntados a escenas o componentes específicos. No se usan scripts "huérfanos" fuera de `Common/` o `Utilities/`.
- **Recursos:** `.tres`/`.res` para datos estáticos (stats de enemigos, configuraciones). `.json`/`ConfigFile` solo para guardado dinámico.
- **Carga de Escenas:** Uso de `PackedScene` y `instantiate()` para entidades. Carga asíncrona (`ResourceLoader.load_threaded_request`) para niveles grandes.

---
*Última actualización: Generado por IA experta en Godot 4.6.1.stable.mono*
