# Arquitectura del Proyecto - State Machine, Interacciones & Comunicación de Nodos

## ⚙️ Máquina de Estados (State Machine)
Ubicada en `Common/StateMachine/`, implementa un patrón FSM con inyección de dependencias para componentes compartidos.

### Estructura Base
- `state_machine.gd` (`StateMachine`): Controlador central. Mantiene referencia al estado activo, delega `_process`/`_physics_process` al estado actual, y ejecuta transiciones seguras mediante `change_state()`.
- `state.gd` (`State`): Clase abstracta base. Define interfaz común: `enter(args)`, `exit()`, `state_process(delta)`, `state_physics_process(delta)`, `state_input(event)`. Contiene propiedades inyectadas: `target`, `anim`, `input_component`, `velocity_component`, `health_component`, `navigation_component`.
- Estados concretos: `idle.gd`, `walk.gd`, `chase.gd`, `hit.gd`, `heal.gd`, `idle_attack.gd`, `move_attack.gd`.

### Inyección de Dependencias (Caché de Componentes)
La `StateMachine` resuelve los componentes del `target` una sola vez en `_ready()` usando `get_node_or_null()` e inyecta las referencias a todos los estados hijos:

```
StateMachine._ready()
  ├─ Cachea: InputComponent, VelocityComponent, HealthComponent, NavigationComponent
  └─ Para cada estado hijo:
	   ├─ Asigna target, anim
	   ├─ Inyecta los 4 componentes cacheados
	   └─ Conecta señal transitioned → change_state()
```

Los estados acceden a los componentes directamente como propiedades heredadas (ej: `velocity_component.move(delta, direction)`). No deben usar `target.get_node()` para componentes comunes. Solo se permite `get_node_or_null()` en `enter()` para recursos específicos del estado (ej: `audioWalk`, `audioAttack`).

### Flujo de Ejecución
1. El estado inicial se configura como `@export var initial_state: State` en el editor.
2. En cada frame, `StateMachine` delega a `current_state.state_process(delta)` y `current_state.state_physics_process(delta)`.
3. Los estados solicitan transiciones emitiendo la señal: `transitioned.emit(self, "NombreEstado", {args})`.
4. `change_state()` valida que el solicitante sea el estado actual, ejecuta `current_state.exit()`, actualiza la referencia y ejecuta `new_state.enter(args)`.

### Reglas de Implementación
- Los estados **no** deben contener lógica de renderizado ni referencias directas a UI.
- Cada estado debe ser autocontenido: animaciones, velocidades, flags de colisión se configuran en `enter()` y se limpian en `exit()`.
- Usar sintaxis nativa de señales Godot 4: `transitioned.emit(...)`, nunca `emit_signal("transitioned", ...)`.
- Evitar transiciones anidadas o recursivas. Usar un buffer de transición si es necesario.

### Mapa de Estados por Entidad

| Estado | Player | Enemigos | Descripción |
|--------|--------|----------|-------------|
| `Idle` | ✅ | ✅ | Reposo, escucha input/daño |
| `Walk` | ✅ | ❌ | Movimiento directo por input del jugador |
| `Chase` | ❌ | ✅ | Persecución vía NavigationComponent |
| `Hit` | ✅ | ✅ | Knockback temporal tras recibir daño |
| `Heal` | ✅ | ❌ | Consumo de poción (flask) |
| `IdleAttack` | ✅ | ✅ | Ataque desde reposo |
| `MoveAttack` | ✅ | ❌ | Ataque con impulso en movimiento |

---

## 🔄 Sistema de Interacciones Unificado
Los objetos interactuables del mundo (puertas, cofres) siguen un patrón reactivo controlado por el jugador. Los objetos **nunca** leen input directamente.

### Arquitectura
```
[PlayerInputComponent]  ─ input_action ─►  [Player (player.gd)]
												  │
									 (Si input_action && current_interactable)
												  ▼
										current_interactable.interact()
```

### Flujo
1. El jugador (`Entities/Player/player.gd`) tiene `var current_interactable: Node = null`.
2. Cuando el jugador entra al `Area2D` de un objeto interactuable, éste se auto-asigna: `body.current_interactable = self`.
3. Cuando el jugador sale del área, el objeto se limpia: `body.current_interactable = null` (solo si sigue siendo él mismo).
4. En `Player._process()`, si `input_component.input_action` es `true` y `current_interactable` no es nulo, se invoca `current_interactable.interact()`.

### Reglas para Nuevos Interactuables
- Implementar `func interact() -> void` como punto de entrada público.
- En `_on_body_entered(body)`: verificar `body.is_in_group("Player")` y asignar `body.current_interactable = self`.
- En `_on_body_exited(body)`: verificar grupo y limpiar con `body.current_interactable == self`.
- **Prohibido:** Leer `Input` directamente o usar `_process()` para polling de acciones en scripts de entorno/objetos.
- Interactuables actuales: `cave_door_1.gd` (transición de escena), `chest.gd` (apertura + drop de monedas).

---

## 🌳 Reglas de Comunicación del Árbol de Nodos
El proyecto prioriza el desacoplamiento y la mantenibilidad. Se aplican las siguientes directrices:

### 1. Señales (Signals) como Principal Canal
- Uso obligatorio para eventos asíncronos: daño recibido, muerte, recolección, cambio de estado global.
- Usar sintaxis nativa Godot 4: `signal_name.emit(args)`, nunca `emit_signal("nombre", args)`.
- Definir señales en el nodo emisor. Conectar en `_ready()` o mediante editor.
- Ejemplo: `health_component.gd` emite `health_changed(current_health, max_health)`, `damaged` y `muerto`.

### 2. Grupos (Groups) para Broadcast Controlado
- Grupos globales definidos: `Player`, `Enemy`.
- Usar para consultas de pertenencia (`body.is_in_group("Player")`) y búsquedas (`get_tree().get_first_node_in_group("Player")`).
- Nunca usar grupos como sustituto de referencias directas en lógica crítica.

### 3. Referencias Directas (Solo cuando sea estrictamente necesario)
- Padres a hijos: `@onready var child = $ChildNode` (seguro y optimizado).
- Hermanos/Componentes dentro de la misma entidad: usar `get_node()` o referencias predefinidas en `_ready()`.
- **Prohibido:** `get_tree().root.get_node("Path/Largo/Y/Frágil")`. Rompe encapsulamiento y causa errores en carga dinámica.

### 4. Patrón de Componentes (`Entities/Scripts/Character/`)
- `hitbox.gd` (`HitBox`) / `hurtbox.gd` (`HurtBox`): Gestión de áreas de colisión ofensivas/defensivas, detección por capas de física, emisión de señales de impacto.
- `input_component.gd` (`InputComponent`): Clase base abstracta. Expone `input_motion`, `input_attack`, `input_heal`, `input_action`. Subclases: `PlayerInputComponent` (lee de `Input`), `EnemyInputComponent` (calcula desde posición del jugador).
- `navigation_component.gd` (`NavigationComponent`): Interfaz con `NavigationAgent2D`. Timer periódico actualiza `target_position` hacia el jugador. Método `get_next_direction(target)` devuelve vector normalizado.
- `health_component.gd` (`HealthComponent`): HP con clamp, señales `health_changed`, `damaged`, `muerto`. Gestiona pociones (`flasks`), muerte y game over.
- `velocity_component.gd` (`VelocityComponent`): Movimiento con soporte de avoidance (NavigationAgent2D) y separación entre enemigos (`SeparationArea`).

> 💡 **Guía para IA:** Al modificar lógica de entidad, verifica primero si la responsabilidad corresponde a un componente existente. Si no existe, crea uno nuevo en `Entities/Scripts/Character/Nodes/` o `Classes/`, manteniendo la interfaz limpia y basada en señales. Para nuevos objetos interactuables, seguir el patrón de `chest.gd` / `cave_door_1.gd`.

---
*Última actualización: Refactorización de FSM (inyección de dependencias), sistema de interacciones unificado, migración a sintaxis Godot 4.*
