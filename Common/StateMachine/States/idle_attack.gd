extends State

@export var hitbox: CollisionShape2D

var audioAttack: AudioStreamPlayer

func enter(args := {}):
	audioAttack = target.get_node_or_null("Audios/Attack")

	anim.play("attack")

	if audioAttack:
		audioAttack.play()

	if hitbox:
		hitbox.disabled = false

	await get_tree().create_timer(0.5).timeout
	transitioned.emit(self, "Idle", {})

func exit():
	if hitbox:
		hitbox.disabled = true
