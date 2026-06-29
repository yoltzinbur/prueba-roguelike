extends SquidState
## Aturdimiento del Jefe (Guard Break): queda quieto unos segundos sin atacar. Sigue
## recibiendo daño por su HurtBox, pero NO se conecta a `damaged`, así que el aturdimiento
## no se interrumpe al golpearlo (es justo la ventana para el crítico del jugador).

var _t: float = 0.0
var _duration: float = 3.0

func enter(args := {}):
	super.enter(args)
	_t = 0.0
	_duration = args.get("duration", 3.0)
	target.velocity = Vector2.ZERO
	if anim and anim.sprite_frames.has_animation("hit"):
		anim.play("hit")

func state_physics_process(delta: float) -> void:
	_t += delta
	if _t >= _duration:
		transitioned.emit(self, "Chase", {})
