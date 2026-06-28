extends SamuraiState
## Embestida especial del Jefe en dos fases: un windup (animación `charge_left/right`) que
## bloquea la dirección hacia el jugador, seguido de un dash recto y veloz con el HitBox
## activo. Al terminar vuelve a perseguir.

@export var hitbox: CollisionShape2D
## Desplazamiento horizontal del HitBox hacia el lado de la embestida.
@export var hitbox_offset: float = 22.0
## Duración de la preparación (animación `charge`) antes de embestir.
@export var windup_time: float = 0.6
## Duración del dash con daño.
@export var dash_time: float = 0.35
## Velocidad del dash (independiente de la velocidad normal del VelocityComponent).
@export var dash_speed: float = 220.0

var _dir: Vector2 = Vector2.ZERO
var _to_right: bool = false
var _t: float = 0.0
var _dashing: bool = false

func enter(args := {}):
	super.enter(args)
	if health_component and not health_component.damaged.is_connected(_on_damaged):
		health_component.damaged.connect(_on_damaged)

	_dir = direction_to_player()
	_to_right = _dir.x >= 0.0
	if input_component:
		input_component.last_direction = "right" if _to_right else "left"
	if anim:
		anim.rotation = 0.0
	_t = 0.0
	_dashing = false

	play_directional_anim("charge")

	if hitbox:
		hitbox.position.x = hitbox_offset if _to_right else -hitbox_offset

func state_physics_process(delta: float) -> void:
	_t += delta

	if not _dashing:
		# Fase de preparación: quieto mientras carga.
		if _t >= windup_time:
			_dashing = true
			_t = 0.0
			if hitbox:
				hitbox.disabled = false
			play_directional_anim("attack")
		return

	# Fase de dash: empuje recto en la dirección bloqueada.
	if _t >= dash_time:
		transitioned.emit(self, "Chase", {})
		return

	target.velocity = _dir * dash_speed
	target.move_and_slide()

func _on_damaged() -> void:
	transitioned.emit(self, "Hit", {})

func exit():
	if hitbox:
		hitbox.disabled = true
	if health_component and health_component.damaged.is_connected(_on_damaged):
		health_component.damaged.disconnect(_on_damaged)
