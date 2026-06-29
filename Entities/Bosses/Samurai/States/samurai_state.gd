class_name SamuraiState
extends State
## Base de los estados propios del Jefe Samurai. Aísla la lógica del jefe de los estados
## genéricos (idle/chase) que comparten Chort/Goblin. Ofrece acceso al jugador y la
## orientación: el cuerpo (idle/walk, que es frontal) rota 180° para mirar arriba/abajo, y
## los ataques usan animaciones laterales (attack_left/right, charge_left/right).

var player: CharacterBody2D

func enter(args := {}):
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("Player")

func distance_to_player() -> float:
	if not is_instance_valid(player):
		return INF
	return target.global_position.distance_to(player.global_position)

func direction_to_player() -> Vector2:
	if not is_instance_valid(player):
		return Vector2.ZERO
	return (player.global_position - target.global_position).normalized()

## Orienta el CUERPO (movimiento/reposo). El sprite de idle/walk es frontal; se rota 180°
## cuando el objetivo está arriba (queda "de cabeza", mirando hacia arriba) y 0° cuando
## está abajo. También deja registrado el lado horizontal en last_direction para que los
## ataques elijan su variante L/R.
func orient_body(dir: Vector2) -> void:
	if not anim or dir == Vector2.ZERO:
		return
	anim.rotation = PI if dir.y < 0.0 else 0.0
	if input_component:
		input_component.last_direction = "left" if dir.x < 0.0 else "right"

## Lado horizontal hacia el jugador, "left" o "right". Lo usan los ataques para elegir su
## animación lateral y colocar el HitBox.
func side_to_player() -> String:
	return "left" if direction_to_player().x < 0.0 else "right"
