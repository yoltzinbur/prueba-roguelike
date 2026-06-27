extends StaticBody2D
## Fogata de descanso. Al interactuar con ella una sola vez, recupera toda la
## vida y los frascos del jugador al máximo. Después queda inactiva (frame 0 del
## sprite) y ya no puede volver a usarse.

## Frascos máximos a los que se rellena al jugador (igual al tope del HUD).
@export var max_frascos: int = 3

@onready var sprite: Sprite2D = $Sprite2D
@onready var interaction_area: InteractionArea = $InteractionArea

var usada: bool = false

func _ready() -> void:
	interaction_area.interacted.connect(_on_interacted)

func _on_interacted() -> void:
	if usada:
		return

	var jugador := get_tree().get_first_node_in_group("Player")
	if jugador == null:
		return

	var health_component: HealthComponent = jugador.get_node_or_null("HealthComponent")
	if health_component == null:
		return

	usada = true

	health_component.current_health = health_component.MAX_HEALTH
	health_component.flasks = max_frascos

	# Pasa a estado inactivo y se desactiva para no poder volver a usarla.
	sprite.frame = 0
	interaction_area.enabled = false
	if jugador.current_interactable == interaction_area:
		jugador.current_interactable = null
