# 📋 Plan de Refactorización y Backlog de Tareas — Godot 4

Este documento contiene el listado de tareas técnicas prioritarias para refactorizar la arquitectura del proyecto conforme a las directrices de diseño limpio, optimización en Godot 4 y desacoplamiento de componentes. Está estructurado para que un agente autónomo pueda autogestionarse en bucles de ejecución (*Loops*).

---

## 🗺️ Mapa de Dependencias e Interacción de Nodos

Para unificar las interacciones (`cave_door_1.gd`, `chest.gd`), se implementa una arquitectura reactiva controlada por el jugador, eliminando el chequeo de inputs en `_process` desde los objetos del entorno.

[Image of state machine architecture and component-based entity design in game development]

```
[Input del Motor] ➔ [PlayerInputComponent] ➔ [Player (CharacterBody2D)]
                                                       │
                                          (Si presiona acción y hay área cerca)
                                                       ▼
                                          [Interactuable (Door / Chest)] ➔ .interact()
```

---

## 🛠️ Grupo de Tareas 1: Máquina de Estados (FSM) y Sintaxis de Godot 4

### Tarea 1.1: Actualización de Sintaxis de Señales en Estados Básicos
- **Descripción:** Modificar la clase base `State` y sus estados concretos (como `idle.gd`) para dejar de utilizar la sintaxis obsoleta de Godot 3 `emit_signal("transitioned", ...)`.
- **Acción:** Cambiar a la sintaxis nativa de Godot 4: `transitioned.emit(self, new_state_name, args)`.
- **Resultado Esperado:** Código limpio sin advertencias de retrocompatibilidad en el output de depuración de Godot.

### Tarea 1.2: Optimización y Caché de Componentes en `idle.gd`
- **Descripción:** Eliminar las búsquedas costosas de nodos dinámicos (`target.get_node(...)`) dentro del método `enter()` de los estados.
- **Acción:** - Centralizar la obtención de referencias críticas (`InputComponent`, `HealthComponent`) en el script del `target` (el personaje/enemigo) durante su inicialización, o realizar el caché una sola vez en el `_ready` de la `StateMachine`.
  - Modificar `idle.gd` para acceder a los componentes directamente vía `target.input_component` o pasándolos como dependencias.
- **Resultado Esperado:** Reducción de llamadas repetitivas a `get_node()` en cada transición de estado, previniendo micro-tirones de rendimiento.

---

## 📦 Grupo de Tareas 2: Arquitectura del Sistema de Interacciones Unificado

### Tarea 2.1: Implementación del Rol "Interactuable" en la Entidad Jugador (`Player`)
- **Descripción:** Modificar el script del jugador para que actúe como el puente central de las interacciones.
- **Acción:**
  - Declarar una variable de seguimiento en el script principal del jugador: `var current_interactable: Node = null`.
  - En el bucle de procesamiento del jugador (`_process`), verificar si se ha pulsado la acción de interacción a través de su componente de entrada (`input_component.input_action`) **y** si `current_interactable` no es nulo.
  - Si ambas condiciones se cumplen, invocar un método unificado en el objeto: `current_interactable.interact()`.
- **Resultado Esperado:** El jugador centraliza la intención de interactuar; los objetos del mundo se vuelven pasivos y reactivos.

### Tarea 2.2: Refactorización de la Puerta (`cave_door_1.gd`)
- **Descripción:** Eliminar la lectura directa del teclado en el script de la puerta y adaptar el uso de señales a Godot 4.
- **Acción:**
  - Eliminar por completo la función `_process(_delta)`.
  - Modificar `_on_body_entered(body)` para que si el cuerpo pertenece al grupo o nombre "Player", se asigne la puerta al jugador: `body.current_interactable = self`.
  - Modificar `_on_body_exited(body)` para limpiar la referencia en el jugador: `if body.current_interactable == self: body.current_interactable = null`.
  - Implementar el método unificado `func interact() -> void` que invoque internamente a `open_door()`.
  - Cambiar la conexión y emisión de señales a la sintaxis moderna: `interaction_area.body_entered.connect(_on_body_entered)` y `door_interacted.emit()`.
- **Resultado Esperado:** La puerta no consume recursos en `_process`. Solo responde cuando el jugador se acerca y pulsa el botón de interacción.

### Tarea 2.3: Refactorización del Cofre (`chest.gd`)
- **Descripción:** Corregir el bug de sintaxis multilínea del cofre y unificarlo bajo el mismo sistema de interacción reactivo que la puerta.
- **Acción:**
  - Eliminar por completo la función `_process(_delta)` de `chest.gd` que buscaba nodos dinámicamente con `player_ref.get_node_or_null("InputComponent")`.
  - Modificar `_on_body_entered` y `_on_body_exited` para que asignen y remuevan `self` de la propiedad `body.current_interactable` del jugador, idéntico a la lógica de la puerta.
  - Implementar el método `func interact() -> void` para que invoque a `open_chest()`.
  - **Corrección de Bug:** Corregir el salto de línea roto en `spawn_coins()` uniendo la expresión en una sola línea limpia: `coin_instance.global_position = global_position + offset`.
- **Resultado Esperado:** Unificación absoluta de la lógica de interacciones. Solución del error de compilación por la sintaxis de asignación de `global_position`.

---

## 📈 Criterios de Aceptación Globales para el Loop de Claude Code

1. **Cero Inputs Huérfanos:** Ningún script dentro de `Stages/` o entornos decorativos (`Entities/Objects/`) puede llamar directamente a `Input.is_action_just_pressed` o `Input.get_vector`. Todo debe procesarse en `PlayerInputComponent`.
2. **Sintaxis Homogénea:** No deben existir llamadas a `emit_signal()` ni estructuras `Callable(self, "string")` en los scripts refactorizados. Todo debe migrarse a las propiedades nativas de señales de Godot 4.
3. **Consistencia Documental:** Al finalizar las refactorizaciones, se deben validar los cambios contra las directrices de `architecture.md` para garantizar que no se violaron las prohibiciones (como rutas de nodos frágiles `get_tree().root...`).