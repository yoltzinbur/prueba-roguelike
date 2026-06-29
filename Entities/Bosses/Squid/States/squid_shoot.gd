extends SquidState
## Disparo a distancia del Jefe: lanza un proyectil hacia la dirección del jugador y vuelve a
## perseguir tras la animación.

const PROJECTILE := preload("res://Entities/Bosses/Squid/Projectile/SquidProjectile.tscn")

## Duración de la animación de disparo antes de volver a perseguir.
@export var duration: float = 0.6

func enter(args := {}):
	super.enter(args)
	var dir := direction_to_player()
	face_player(dir)

	if anim and anim.sprite_frames.has_animation("shoot"):
		anim.play("shoot")

	_spawn_projectile(dir)

	await get_tree().create_timer(duration).timeout
	transitioned.emit(self, "Chase", {})

## Instancia el proyectil en la posición del jefe, apuntando hacia `dir`, y lo añade a la
## arena (el padre del jefe) para que persista tras salir de este estado.
func _spawn_projectile(dir: Vector2) -> void:
	if dir == Vector2.ZERO:
		return
	var projectile := PROJECTILE.instantiate()
	target.get_parent().add_child(projectile)
	projectile.global_position = target.global_position
	if projectile.has_method("launch"):
		projectile.launch(dir)
