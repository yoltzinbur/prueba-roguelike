class_name SquidState
extends State
## Base de los estados propios del Jefe Squid. Aísla su lógica de los estados genéricos y
## ofrece acceso al jugador y la orientación. El Squid usa animaciones NO direccionales
## (idle/walk/attack/attack_loop/shoot/hit); se orienta volteando el sprite (flip_h).

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

## Voltea el sprite para mirar hacia el jugador (izquierda si está a la izquierda).
func face_player(dir: Vector2) -> void:
	if anim and dir.x != 0.0:
		anim.flip_h = dir.x < 0.0
