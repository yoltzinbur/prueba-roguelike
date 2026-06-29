extends StaticBody2D
## Portal (Tótem) al jefe final. Tiene tres estados, controlados por el bosque (forest_main):
##  - bloqueado: oculto, sin colisión ni interacción (faltan niveles).
##  - activo: visible e interactuable; al interactuar lleva a la arena del jefe final.
##  - purificado: jefe ya derrotado; el tótem desaparece pero al pasar cerca avisa que fue
##    purificado (no se puede volver a entrar a la arena).

@onready var interaction_area: InteractionArea = $InteractionArea

# Jefe final ya derrotado: el portal queda inactivo y sólo saluda al pasar el jugador.
var _purified: bool = false
# Evita repetir el aviso de purificado varias veces en una misma visita al bosque.
var _greeted: bool = false

func _ready() -> void:
	interaction_area.interacted.connect(_on_interacted)
	interaction_area.body_entered.connect(_on_body_entered)

## Portal activo: visible, interactuable y con colisión. Lo llama forest_main cuando se
## completaron los niveles y el jefe sigue vivo.
func set_active(active: bool) -> void:
	_purified = false
	visible = active
	if interaction_area:
		interaction_area.enabled = active
	_set_body_collision(active)

## Tótem purificado (jefe derrotado): se oculta y desactiva, pero conserva la zona para
## avisar al jugador que pasa por donde estaba.
func set_purified() -> void:
	_purified = true
	visible = false
	if interaction_area:
		interaction_area.enabled = false
	_set_body_collision(false)

func _set_body_collision(enabled: bool) -> void:
	var body_collision := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if body_collision:
		body_collision.set_deferred("disabled", not enabled)

func _on_interacted() -> void:
	if _purified:
		return
	GameManager.load_scene(GameScenes.FINALBOSS)

func _on_body_entered(body: Node2D) -> void:
	if _purified and not _greeted and body.is_in_group("Player") and body.has_method("show_message"):
		_greeted = true
		body.show_message("El Tótem ha sido purificado.")
