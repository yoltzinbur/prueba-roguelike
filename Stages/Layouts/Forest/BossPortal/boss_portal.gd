extends StaticBody2D
## Portal al jefe final. Aparece (visible + interactuable) sólo cuando se han completado
## todos los niveles; al interactuar, lleva a la arena del jefe final.

@onready var interaction_area: InteractionArea = $InteractionArea

func _ready() -> void:
	interaction_area.interacted.connect(_on_interacted)

## Activa o desactiva el portal: visibilidad, colisión del cuerpo y posibilidad de
## interactuar. Lo llama el bosque (forest_main) según los niveles completados. Mientras
## está bloqueado se oculta y se desactiva su colisión para no dejar un muro invisible.
func set_active(active: bool) -> void:
	visible = active
	if interaction_area:
		interaction_area.enabled = active
	var body_collision := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if body_collision:
		body_collision.set_deferred("disabled", not active)

func _on_interacted() -> void:
	GameManager.load_scene(GameScenes.FINALBOSS)
