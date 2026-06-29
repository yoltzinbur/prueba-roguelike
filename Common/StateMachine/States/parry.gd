extends State
## Parry del jugador: abre una ventana corta en la que cualquier PROYECTIL dentro de la
## ParryArea se refleja hacia el jefe (sin fallar). Sólo afecta proyectiles (cosas con
## método `reflect()`); el resto de hitboxes se ignoran. No mueve al jugador.

## Duración de la ventana de parry, en segundos.
@export var parry_window: float = 0.35

var _t: float = 0.0
var parry_area: Area2D

func enter(args := {}):
	_t = 0.0
	parry_area = target.get_node_or_null("ParryArea")
	target.velocity = Vector2.ZERO
	play_directional_anim("idle")
	if anim:
		anim.modulate = Color(0.6, 0.85, 1.0)  # tinte azulado: pose de parry
	if parry_area:
		parry_area.monitoring = true

func state_physics_process(delta: float) -> void:
	_t += delta
	_reflect_overlapping()
	if _t >= parry_window:
		transitioned.emit(self, "Idle", {})

## Refleja todos los proyectiles que estén dentro de la ParryArea (entren o ya estuvieran).
func _reflect_overlapping() -> void:
	if parry_area == null:
		return
	var boss := get_tree().get_first_node_in_group("Boss")
	for area in parry_area.get_overlapping_areas():
		if area and area.has_method("reflect") and area.reflect(boss):
			if target.has_method("on_projectile_reflected"):
				target.on_projectile_reflected()

func exit():
	if parry_area:
		parry_area.monitoring = false
	if anim:
		anim.modulate = Color(1, 1, 1, 1)
