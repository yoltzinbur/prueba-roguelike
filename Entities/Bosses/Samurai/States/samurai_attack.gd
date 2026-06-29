extends SamuraiState
## Ataque melé del Jefe. Usa la animación lateral (attack_left/right) según el lado del
## jugador y coloca el HitBox en ese lado para cubrir frente y costado. Los ataques van
## siempre "derechos" (sin la rotación 180° del cuerpo), porque sirven para alcanzar los
## laterales.

@export var hitbox: CollisionShape2D
## Desplazamiento horizontal del HitBox hacia el lado del ataque.
@export var hitbox_offset: float = 22.0
## Duración del ataque antes de volver a perseguir.
@export var duration: float = 0.5

func enter(args := {}):
	super.enter(args)
	var to_right := direction_to_player().x >= 0.0
	if input_component:
		input_component.last_direction = "right" if to_right else "left"

	if anim:
		anim.rotation = 0.0
	play_directional_anim("attack")

	var audio_attack: AudioStreamPlayer = target.get_node_or_null("Audios/Attack")
	if audio_attack:
		audio_attack.play()

	if hitbox:
		hitbox.position.x = hitbox_offset if to_right else -hitbox_offset
		hitbox.disabled = false

	await get_tree().create_timer(duration).timeout
	transitioned.emit(self, "Chase", {})

func exit():
	if hitbox:
		hitbox.disabled = true
