# Arquitectura del Proyecto - State Machine, Animaciones, Interacciones & Comunicación de Nodos

## Maquina de Estados (State Machine)
Ubicada en `Common/StateMachine/`, implementa un patron FSM con inyeccion de dependencias para componentes compartidos.

### Estructura Base
- `state_machine.gd` (`StateMachine`): Controlador central. Mantiene referencia al estado activo, delega `_process`/`_physics_process` al estado actual, y ejecuta transiciones seguras mediante `change_state()`.
- `state.gd` (`State`): Clase abstracta base. Define interfaz comun: `enter(args)`, `exit()`, `state_process(delta)`, `state_physics_process(delta)`, `state_input(event)`, `play_directional_anim(base_name)`. Contiene propiedades inyectadas: `target`, `anim`, `input_component`, `velocity_component`, `health_component`, `navigation_component`.
- Estados concretos: `idle.gd`, `walk.gd`, `chase.gd`, `hit.gd`, `heal.gd`, `idle_attack.gd`, `move_attack.gd`, `dodge.gd`.

### Inyeccion de Dependencias (Cache de Componentes)
La `StateMachine` resuelve los componentes del `target` una sola vez en `_ready()` usando `get_node_or_null()` e inyecta las referencias a todos los estados hijos:

```
StateMachine._ready()
  |-- Cachea: InputComponent, VelocityComponent, HealthComponent, NavigationComponent
  +-- Para cada estado hijo:
       |-- Asigna target, anim
       |-- Inyecta los 4 componentes cacheados
       +-- Conecta signal transitioned -> change_state()
```

Los estados acceden a los componentes directamente como propiedades heredadas (ej: `velocity_component.move(delta, direction)`). No deben usar `target.get_node()` para componentes comunes. Solo se permite `get_node_or_null()` en `enter()` para recursos especificos del estado (ej: `audioWalk`, `audioAttack`).

### Flujo de Ejecucion
1. El estado inicial se configura como `@export var initial_state: State` en el editor.
2. En cada frame, `StateMachine` delega a `current_state.state_process(delta)` y `current_state.state_physics_process(delta)`.
3. Los estados solicitan transiciones emitiendo la signal: `transitioned.emit(self, "NombreEstado", {args})`.
4. `change_state()` valida que el solicitante sea el estado actual, ejecuta `current_state.exit()`, actualiza la referencia y ejecuta `new_state.enter(args)`.

### Reglas de Implementacion
- Los estados **no** deben contener logica de renderizado ni referencias directas a UI.
- Cada estado debe ser autocontenido: animaciones, velocidades, flags de colision se configuran en `enter()` y se limpian en `exit()`.
- Usar sintaxis nativa de signals Godot 4: `transitioned.emit(...)`, nunca `emit_signal("transitioned", ...)`.
- Evitar transiciones anidadas o recursivas. Usar un buffer de transicion si es necesario.

### Mapa de Estados por Entidad

| Estado | Player | Enemigos | Descripcion |
|--------|--------|----------|-------------|
| `Idle` | Si | Si | Reposo, escucha input/dano |
| `Walk` | Si | No | Movimiento directo por input del jugador |
| `Chase` | No | Si | Persecucion via NavigationComponent |
| `Hit` | Si | Si | Knockback temporal tras recibir dano |
| `Heal` | Si | No | Consumo de pocion (flask) |
| `IdleAttack` | Si | Si | Ataque desde reposo |
| `MoveAttack` | Si | No | Ataque con impulso en movimiento |
| `Dodge` | Si | No | Esquive con invulnerabilidad temporal |

---

## Sistema de Animaciones Direccionales

### Concepto
El Player usa spritesheets con 4 direcciones (down, right, up, left) organizadas en filas, con columnas para los frames de animacion. Las animaciones direccionales se crean en runtime desde los spritesheets y se reproducen segun la direccion actual del personaje.

### Spritesheets del Player (`Entities/Player/Art/`)
Todos los spritesheets siguen el mismo layout de cuadricula 32x32 por frame:

| Spritesheet | Filas (direcciones) | Columnas (frames) | Layout |
|-------------|--------------------|--------------------|--------|
| `Idle.png` | 4 (down, right, up, left) | 4 | 4x4 |
| `Walk.png` | 4 (down, right, up, left) | 4 | 4x4 |
| `Attack.png` | 4 (down, right, up, left) | 4 | 4x4 |
| `Hit.png` | 2 (down, right) | 4 | 4x2 |

Mapping de filas a direcciones:
- Fila 0 (y=0): **down** (personaje mirando al frente/abajo)
- Fila 1 (y=32): **right** (personaje mirando a la derecha)
- Fila 2 (y=64): **up** (personaje mirando arriba/de espaldas)
- Fila 3 (y=96): **left** (personaje mirando a la izquierda)

### Generacion de Animaciones en Runtime
`player.gd` crea las animaciones direccionales en `_ready()` mediante `_crear_animaciones_direccionales()`:

1. Recorre cada spritesheet (idle, walk, attack) y genera 4 animaciones por sheet: `idle_down`, `idle_right`, `idle_up`, `idle_left`, etc.
2. Para cada animacion, crea `AtlasTexture` por frame recortando la region correspondiente del spritesheet.
3. Para `Hit.png` (solo 2 filas): reutiliza fila 0 (down) para `hit_up` y fila 1 (right) para `hit_left`.
4. Las animaciones originales sin sufijo (`idle`, `walk`, etc.) se mantienen como fallback para enemigos.

### Tracking de Direccion
- `InputComponent` expone `var last_direction: String = "down"` — la ultima direccion no-nula del personaje.
- `PlayerInputComponent` actualiza `last_direction` en `_process()` cuando `input_motion != Vector2.ZERO`, priorizando el eje con mayor magnitud para movimiento diagonal.
- `last_direction` persiste cuando el jugador deja de moverse, preservando la orientacion para animaciones de idle, ataque, etc.

### Helper `play_directional_anim()` en State
Metodo en la clase `State` base que encapsula la logica de seleccion de animacion:

```
play_directional_anim("idle")
  1. Lee input_component.last_direction (ej: "right")
  2. Busca "idle_right" en SpriteFrames
  3. Si existe -> anim.play("idle_right")
  4. Si no existe -> fallback a anim.play("idle")
```

El fallback garantiza compatibilidad con enemigos que no tienen animaciones direccionales. Los enemigos siguen usando `anim.scale.x` para flip horizontal en `chase.gd`.

### Estados que usan animaciones direccionales

| Estado | Llamada | Notas |
|--------|---------|-------|
| `Idle` | `play_directional_anim("idle")` | Al entrar al estado |
| `Walk` | `play_directional_anim("walk")` | Al entrar y al cambiar de direccion mid-walk |
| `IdleAttack` | `play_directional_anim("attack")` | Al entrar al estado |
| `MoveAttack` | `play_directional_anim("attack")` | Al entrar al estado |
| `Hit` | `play_directional_anim("hit")` | Al entrar al estado |
| `Dodge` | `play_directional_anim("walk")` | Reutiliza animacion de caminar |
| `Heal` | `anim.play("heal")` | Sin direccion (frame unico del flask) |
| `Chase` | `anim.play("walk")` | Enemigos: sin direccion, usa scale.x para flip |

### Reglas para Nuevos Spritesheets
- Seguir el layout de 4 filas (down, right, up, left) x N columnas.
- Frame size: 32x32 pixeles.
- Si el spritesheet no tiene las 4 direcciones, mapear las faltantes a filas existentes (como Hit.png).
- No usar `scale.x` ni `flip_h` para el Player; las direcciones se resuelven con animaciones nombradas.

---

## Sistema de Interacciones Unificado
Los objetos interactuables del mundo (puertas, cofres) siguen un patron reactivo controlado por el jugador. Los objetos **nunca** leen input directamente.

### Arquitectura
```
[PlayerInputComponent]  -- input_action -->  [Player (player.gd)]
                                                    |
                                       (Si input_action && current_interactable)
                                                    v
                                             current_interactable.interact()
```

### Flujo
1. El jugador (`Entities/Player/player.gd`) tiene `var current_interactable: Node = null`.
2. Cuando el jugador entra al `Area2D` de un objeto interactuable, este se auto-asigna: `body.current_interactable = self`.
3. Cuando el jugador sale del area, el objeto se limpia: `body.current_interactable = null` (solo si sigue siendo el mismo).
4. En `Player._process()`, si `input_component.input_action` es `true` y `current_interactable` no es nulo, se invoca `current_interactable.interact()`.

### Reglas para Nuevos Interactuables
- Implementar `func interact() -> void` como punto de entrada publico.
- En `_on_body_entered(body)`: verificar `body.is_in_group("Player")` y asignar `body.current_interactable = self`.
- En `_on_body_exited(body)`: verificar grupo y limpiar con `body.current_interactable == self`.
- **Prohibido:** Leer `Input` directamente o usar `_process()` para polling de acciones en scripts de entorno/objetos.
- Interactuables actuales: `cave_door.gd` (transicion de escena a cueva procedural), `chest.gd` (apertura + drop de monedas).

---

## Reglas de Comunicacion del Arbol de Nodos
El proyecto prioriza el desacoplamiento y la mantenibilidad. Se aplican las siguientes directrices:

### 1. Signals como Principal Canal
- Uso obligatorio para eventos asincronos: dano recibido, muerte, recoleccion, cambio de estado global.
- Usar sintaxis nativa Godot 4: `signal_name.emit(args)`, nunca `emit_signal("nombre", args)`.
- Definir signals en el nodo emisor. Conectar en `_ready()` o mediante editor.
- Ejemplo: `health_component.gd` emite `health_changed(current_health, max_health)`, `damaged` y `muerto`.

### 2. Grupos (Groups) para Broadcast Controlado
- Grupos globales definidos: `Player`, `Enemy`.
- Usar para consultas de pertenencia (`body.is_in_group("Player")`) y busquedas (`get_tree().get_first_node_in_group("Player")`).
- Nunca usar grupos como sustituto de referencias directas en logica critica.

### 3. Referencias Directas (Solo cuando sea estrictamente necesario)
- Padres a hijos: `@onready var child = $ChildNode` (seguro y optimizado).
- Hermanos/Componentes dentro de la misma entidad: usar `get_node()` o referencias predefinidas en `_ready()`.
- **Prohibido:** `get_tree().root.get_node("Path/Largo/Y/Fragil")`. Rompe encapsulamiento y causa errores en carga dinamica.

### 4. Patron de Componentes (`Entities/Scripts/Character/`)
- `hitbox.gd` (`HitBox`) / `hurtbox.gd` (`HurtBox`): Gestion de areas de colision ofensivas/defensivas, deteccion por capas de fisica, emision de signals de impacto.
- `input_component.gd` (`InputComponent`): Clase base. Expone `input_motion`, `input_attack`, `input_heal`, `input_action`, `input_dodge`, `last_direction`. Subclases: `PlayerInputComponent` (lee de `Input`, actualiza `last_direction`), `EnemyInputComponent` (calcula desde posicion del jugador).
- `navigation_component.gd` (`NavigationComponent`): Interfaz con `NavigationAgent2D`. Timer periodico actualiza `target_position` hacia el jugador. Metodo `get_next_direction(target)` devuelve vector normalizado.
- `health_component.gd` (`HealthComponent`): HP con clamp, signals `health_changed`, `damaged`, `muerto`. Gestiona pociones (`flasks`), muerte y game over.
- `velocity_component.gd` (`VelocityComponent`): Movimiento con soporte de avoidance (NavigationAgent2D) y separacion entre enemigos (`SeparationArea`).

> **Guia para IA:** Al modificar logica de entidad, verifica primero si la responsabilidad corresponde a un componente existente. Si no existe, crea uno nuevo en `Entities/Scripts/Character/Nodes/` o `Classes/`, manteniendo la interfaz limpia y basada en signals. Para nuevos objetos interactuables, seguir el patron de `chest.gd` / `cave_door.gd`. Para animaciones direccionales del Player, seguir el patron de spritesheets 4-filas y registrar en `_crear_animaciones_direccionales()`.

---
*Ultima actualizacion: Sistema de animaciones direccionales (4 direcciones con play_directional_anim), estado Dodge, refactorizacion de FSM.*
