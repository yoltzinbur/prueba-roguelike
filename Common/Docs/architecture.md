# Arquitectura del Proyecto - State Machine & Comunicación de Nodos

## ⚙️ Máquina de Estados (State Machine)
Ubicada en `Common/StateMachine/`, implementa un patrón FSM robusto y desacoplado.

### Estructura Base
- `state_machine.gd`: Controlador central. Mantiene referencia al estado activo, maneja `_process`/`_physics_process`, y ejecuta transiciones seguras.
- `state.gd`: Clase abstracta base. Define interfaz común: `enter()`, `exit()`, `update(delta)`, `physics_update(delta)`, `handle_input(event)`.
- Estados concretos: `idle.gd`, `walk.gd`, `chase.gd`, `hit.gd`, `heal.gd`, `idle_attack.gd`, `move_attack.gd`.

### Flujo de Ejecución
1. Al instanciar la entidad, se asigna un estado inicial (`state_machine.set_initial_state(idle)`).
2. En cada frame, `state_machine` delega a `current_state.update(delta)`.
3. Las transiciones se solicían mediante señales o métodos públicos: `request_transition(new_state)`.
4. La máquina valida la transición, llama a `current_state.exit()`, actualiza la referencia y ejecuta `new_state.enter()`.

### Reglas de Implementación
- Los estados **no** deben contener lógica de renderizado ni referencias directas a UI.
- Cada estado debe ser autocontenido: animaciones, velocidades, flags de colisión se configuran en `enter()` y se limpian en `exit()`.
- Evitar transiciones anidadas o recursivas. Usar un buffer de transición si es necesario.

## 🌳 Reglas de Comunicación del Árbol de Nodos
El proyecto prioriza el desacoplamiento y la mantenibilidad. Se aplican las siguientes directrices:

### 1. Señales (Signals) como Principal Canal
- Uso obligatorio para eventos asíncronos: daño recibido, muerte, recolección, cambio de estado global.
- Definir señales en el nodo emisor. Conectar en `_ready()` o mediante editor.
- Ejemplo: `health_component.gd` emite `health_changed(new_value)` y `died()`.

### 2. Grupos (Groups) para Broadcast Controlado
- Usar `add_to_group("enemies")`, `add_to_group("collectables")` para consultas masivas o desactivación por área.
- Nunca usar grupos como sustituto de referencias directas en lógica crítica.

### 3. Referencias Directas (Solo cuando sea estrictamente necesario)
- Padres a hijos: `@onready var child = $ChildNode` (seguro y optimizado).
- Hermanos/Componentes dentro de la misma entidad: usar `get_node()` o referencias predefinidas en `_ready()`.
- **Prohibido:** `get_tree().root.get_node("Path/Largo/Y/Frágil")`. Rompe encapsulamiento y causa errores en carga dinámica.

### 4. Patrón de Componentes (`Entities/Scripts/Character/`)
- `hitbox.gd` / `hurtbox.gd`: Gestión de áreas de colisión, detección de capas/máscaras, emisión de señales de impacto.
- `input_component.gd`: Traducción de eventos de teclado/ratón a acciones abstractas (`move`, `attack`, `interact`).
- `navigation_component.gd`: Interfaz con `NavigationAgent2D`/`NavigationServer`. Calcula waypoints y actualiza velocidad objetivo.
- `health_component.gd`: Estado vital, regeneración, invulnerabilidad temporal, sincronización con UI.
- `velocity_component.gd`: Integración de movimiento, fricción, aceleración, límites de velocidad.

> 💡 **Guía para IA:** Al modificar lógica de entidad, verifica primero si la responsabilidad corresponde a un componente existente. Si no existe, crea uno nuevo en `Entities/Scripts/Character/Nodes/` o `Classes/`, manteniendo la interfaz limpia y basada en señales.

---
*Última actualización: Generado por IA experta en Godot 4.6.1.stable.mono*
