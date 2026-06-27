class_name InteractionArea
extends Area2D
## Nodo agregable y reutilizable que generaliza la interactividad. Reemplaza a los
## Area2D sueltos de objetos como Chest o CaveDoor: gestiona por sí mismo el
## registro del jugador (current_interactable) y, al recibir la interacción,
## reemite la señal `interacted`. Así cada objeto dueño solo implementa su lógica
## conectándose a esa señal, sin repetir el cableado de detección.
##
## Uso: añadir este nodo como hijo del objeto, darle una CollisionShape2D y
## conectar su señal `interacted` al método del objeto que ejecuta la acción.

## Emitida cuando el jugador interactúa con este objeto (vía Player._process()).
signal interacted

## Grupo al que debe pertenecer el cuerpo para considerarse "el jugador".
@export var player_group: String = "Player"

## Si es false, la zona ignora entradas/salidas y no registra al jugador.
@export var enabled: bool = true

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

## El jugador se acerca: este nodo se registra como su interactuable actual.
func _on_body_entered(body: Node2D) -> void:
	if not enabled:
		return
	if body.is_in_group(player_group):
		body.current_interactable = self

## El jugador se aleja: se desvincula solo si seguía siendo el interactuable activo.
func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group(player_group) and body.current_interactable == self:
		body.current_interactable = null

## Llamada por el Player cuando se pulsa la acción. Reemite la interacción para
## que el objeto dueño ejecute su propia lógica.
func interact() -> void:
	if enabled:
		interacted.emit()
