extends SquidState
## Ataque melé en bucle: durante unos segundos el Jefe persigue al jugador a mayor velocidad
## con el HitBox activo, golpeando sin parar. Menos agresivo que una embestida recta (sigue al
## jugador en vez de lanzarse en línea). No se interrumpe al recibir daño (como la embestida).

@export var hitbox: CollisionShape2D
## Duración total del bucle de ataque.
@export var loop_duration: float = 2.5
## Velocidad de persecución durante el bucle (mayor que la normal).
@export var loop_speed: float = 50.0 # Estaba bien culero con 130, no te daba tiempo ni de meter las manos
## Cada cuánto se "pulsa" el HitBox para volver a aplicar daño si sigue tocando al jugador.
@export var hit_interval: float = 0.5

var _t: float = 0.0
var _hit_t: float = 0.0
# True el frame en que el HitBox quedó desactivado para re-disparar el daño al reactivarse.
var _pulsing_off: bool = false

func enter(args := {}):
	super.enter(args)
	_t = 0.0
	_hit_t = 0.0
	_pulsing_off = false
	if anim and anim.sprite_frames.has_animation("attack_loop"):
		anim.play("attack_loop")
	if hitbox:
		hitbox.disabled = false

func state_physics_process(delta: float) -> void:
	_t += delta
	if _t >= loop_duration:
		transitioned.emit(self, "Chase", {})
		return

	if is_instance_valid(player):
		var dir := direction_to_player()
		face_player(dir)
		target.velocity = dir * loop_speed
		target.move_and_slide()

	_pulse_hitbox(delta)

## Reactiva el HitBox tras un frame apagado (re-dispara area_entered si sigue solapando al
## jugador) y lo apaga periódicamente para conseguir daño repetido durante el contacto.
func _pulse_hitbox(delta: float) -> void:
	if not hitbox:
		return
	if _pulsing_off:
		hitbox.disabled = false
		_pulsing_off = false
		_hit_t = 0.0
		return
	_hit_t += delta
	if _hit_t >= hit_interval:
		hitbox.disabled = true
		_pulsing_off = true

func exit():
	if hitbox:
		hitbox.disabled = true
