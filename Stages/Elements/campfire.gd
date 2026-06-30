extends StaticBody2D
## Fogata de descanso. Al interactuar con ella una sola vez, recupera toda la
## vida y los frascos del jugador al máximo. Después queda inactiva (frame 0 del
## sprite) y ya no puede volver a usarse.

@onready var sprite: Sprite2D = $Sprite2D
@onready var interaction_area: InteractionArea = $InteractionArea

var usada: bool = false

func _ready() -> void:
	interaction_area.interacted.connect(_on_interacted)

func _on_interacted() -> void:
	if usada:
		return

	var jugador := get_tree().get_first_node_in_group("Player")
	if jugador == null or not jugador.has_method("curar_completo"):
		return

	usada = true

	# Restaura vida y frascos a través de la API del jugador, sin depender del
	# nombre/ruta interna de su HealthComponent. El tope de frascos sale de
	# SaveManager (sube +1 por cada jefe vencido), no de un valor fijo: así la
	# fogata rellena los 4 frascos si ya los desbloqueaste, no solo 3.
	jugador.curar_completo(SaveManager.max_flasks)

	# Pasa a estado inactivo y se desactiva para no poder volver a usarla.
	sprite.frame = 0
	interaction_area.enabled = false
	if jugador.current_interactable == interaction_area:
		jugador.current_interactable = null
