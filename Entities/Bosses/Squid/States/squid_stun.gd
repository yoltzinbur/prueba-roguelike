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
	# Mientras está aturdido, cada golpe recibido vuelve a reproducir la animación de Hit
	# como indicador visual, pero NO interrumpe el aturdimiento.
	if health_component and not health_component.damaged.is_connected(_on_damaged):
		health_component.damaged.connect(_on_damaged)
	_play_hit()

func state_physics_process(delta: float) -> void:
	_t += delta
	if _t >= _duration:
		transitioned.emit(self, "Chase", {})

## Reproduce (reinicia) la animación de Hit para que se vea que recibe daño durante el stun.
func _on_damaged() -> void:
	_play_hit()

func _play_hit() -> void:
	if anim and anim.sprite_frames.has_animation("hit"):
		anim.play("hit")

func exit():
	if health_component and health_component.damaged.is_connected(_on_damaged):
		health_component.damaged.disconnect(_on_damaged)
