extends State
## Parry del jugador con doble función, en una ventana corta:
##  - PROYECTILES (objetos con método `reflect()`) dentro de la ParryArea: se reflejan hacia
##    el jefe (igual que antes; alimenta el Guard Break).
##  - ATAQUES MELÉ de enemigos NORMALES (no jefes): el parry actúa como escudo. El daño se
##    ignora mientras dura la ventana (lo gestiona la HurtBox vía set_guard()) y además se
##    empuja a los enemigos para ganar espacio.
##  - Los ataques melé de los JEFES NO se bloquean: atraviesan el escudo y dañan igual.
## No mueve al jugador.

## Duración de la ventana de parry, en segundos.
@export var parry_window: float = 0.35
## Fuerza del empuje aplicado a los enemigos cuyo ataque melé se bloquea.
@export var push_force: float = 220.0

var _t: float = 0.0
var parry_area: Area2D
var hurtbox: HurtBox

func enter(args := {}):
	_t = 0.0
	parry_area = target.get_node_or_null("ParryArea")
	hurtbox = target.get_node_or_null("HurtBox")
	target.velocity = Vector2.ZERO
	play_directional_anim("idle")
	if anim:
		anim.modulate = Color(0.6, 0.85, 1.0)  # tinte azulado: pose de parry
	if parry_area:
		parry_area.monitoring = true
	if hurtbox:
		hurtbox.set_guard(true)  # activa el escudo contra el melé de enemigos normales

func state_physics_process(delta: float) -> void:
	_t += delta
	_resolver_solapamientos()
	if _t >= parry_window:
		transitioned.emit(self, "Idle", {})

## Recorre lo que haya dentro de la ParryArea: refleja proyectiles y empuja a los enemigos
## normales cuyo ataque melé se bloquea. Los jefes se ignoran (su melé atraviesa el escudo).
func _resolver_solapamientos() -> void:
	if parry_area == null:
		return
	var boss := get_tree().get_first_node_in_group("Boss")
	for area in parry_area.get_overlapping_areas():
		if area == null:
			continue
		if area.has_method("reflect"):
			if area.reflect(boss) and target.has_method("on_projectile_reflected"):
				target.on_projectile_reflected()
		elif area is HitBox:
			_empujar_enemigo(area)

## Empuja al enemigo dueño de `hitbox` lejos del jugador (estado Hit), salvo que sea un jefe.
func _empujar_enemigo(hitbox: HitBox) -> void:
	var enemy := hitbox.get_source_entity()
	if enemy == null or enemy.is_in_group("Boss"):
		return
	var sm := enemy.get_node_or_null("StateMachine")
	if sm and sm.current_state and sm.states.has("Hit"):
		sm.change_state(sm.current_state, "Hit", {
			"knockback_from": target.global_position,
			"knockback_force": push_force,
		})

func exit():
	if parry_area:
		parry_area.monitoring = false
	if hurtbox:
		hurtbox.set_guard(false)
	if anim:
		anim.modulate = Color(1, 1, 1, 1)
