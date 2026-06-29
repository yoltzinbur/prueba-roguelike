extends SquidState
## Ataque melé normal del Jefe Squid (rango corto, 16px). Activa el HitBox ya configurado en
## la escena (NO se mueve), reproduce la animación y vuelve a perseguir tras la duración.

@export var hitbox: CollisionShape2D
## Duración del ataque antes de volver a perseguir.
@export var duration: float = 0.5

func enter(args := {}):
	super.enter(args)
	face_player(direction_to_player())

	if anim and anim.sprite_frames.has_animation("attack"):
		anim.play("attack")

	if hitbox:
		hitbox.disabled = false

	await get_tree().create_timer(duration).timeout
	transitioned.emit(self, "Chase", {})

func exit():
	if hitbox:
		hitbox.disabled = true
