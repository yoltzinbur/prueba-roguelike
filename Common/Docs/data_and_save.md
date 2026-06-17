# Organización de Datos, Mapas y Sistema de Guardado

## 🗺️ Estructura de Mapas (`Stages/`)
Los niveles se componen mediante escenas modulares y tilemaps optimizados para carga progresiva.

### Composición de Escena
- `Stages/Main/Main.tscn`: Escena raíz del juego. Contiene cámara principal, luz ambiental, nodos de gestión global y contenedor dinámico para niveles.
- `Stages/Layouts/Layout1/TilemapLeyers.tscn`: Layout reutilizable con capas de tilemap organizadas por función:
  - `Floor`: Suelo base, sin colisión.
  - `Walls`: Paredes y obstáculos, máscara de colisión activa.
  - `Decorations`: Elementos visuales no interactivos.
  - `Navigation`: Capa oculta para `NavigationRegion2D` (bake automático o manual).

### Carga y Transición
- Los niveles se instancian como hijos de `Main.tscn` mediante `GameManager`.
- Uso de `Viewport` o `SubViewport` si se requiere renderizado aislado por nivel.
- Los tilesets (`atlas_floor-16x16.png`, `atlas_walls_low-16x16.png`) se comparten globalmente para reducir memoria.

## 💾 Estructura de Datos del Juego
El proyecto separa datos estáticos (balancing, configuración) de datos dinámicos (progreso, inventario).

### 1. Datos Estáticos
- **Formato:** Recursos personalizados `.tres` o scripts con `class_name`.
- **Uso:** Stats de enemigos, curvas de dificultad, configuraciones de UI, parámetros de física.
- **Ubicación:** `Entities/` (por entidad) o `Common/Data/` (si se crea).
- **Ejemplo:** `EnemyStats.tres` con propiedades exportadas (`@export var max_hp: int`, `@export var speed: float`).

### 2. Datos Dinámicos y Persistencia
- **Formato:** `ConfigFile` para ajustes del usuario, `JSON` o serialización binaria para progreso.
- **Ruta de Guardado:** `user://save_data/` (accesible vía `OS.get_user_data_dir()`).
- **Gestión:** `GameManager` centraliza llamadas a `save_game()` y `load_game()`.
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
2. **Balanceo:** Ajustar valores en recursos `.tres`, nunca hardcodeados en scripts.
3. **Guardado:** Implementar hooks en `_exit_tree()` o señales de pausa para guardar automático. Usar `FileAccess` con manejo de errores (`ERR_FILE_NOT_FOUND`, etc.).
4. **Migración:** Si cambia la estructura de datos, incluir lógica de conversión hacia atrás en `load_game()`.

---
*Última actualización: Generado por IA experta en Godot 4.6.1.stable.mono*
