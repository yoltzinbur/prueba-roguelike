class_name Box
extends CharacterBody2D
## Caja empujable para puzzles. El jugador la empuja llamando a push(velocity);
## la caja avanza con move_and_slide() (que evita atravesar paredes del
## TileMapLayer) y se frena progresivamente por fricción hasta detenerse.

## Fricción (px/s²) aplicada cada frame para frenar la caja tras un empujón.
@export var friction: float = 400.0

## Velocidad máxima permitida al empujar (evita lanzamientos exagerados).
@export var max_push_speed: float = 80.0

# Caja bloqueada: ignora empujones y se queda fija (p. ej. al resolver un puzzle,
# para que el jugador no pueda deshacer la solución moviéndola).
var _locked: bool = false

## API pública: imprime un impulso de movimiento a la caja en la dirección dada.
## `push_velocity` es un vector de velocidad (dirección * magnitud). Si la caja está
## bloqueada, ignora el empujón.
func push(push_velocity: Vector2) -> void:
	if _locked:
		return
	velocity = push_velocity.limit_length(max_push_speed)

## API pública: fija la caja en su posición actual e ignora empujones posteriores.
func lock() -> void:
	_locked = true
	velocity = Vector2.ZERO

func _physics_process(delta: float) -> void:
	if velocity == Vector2.ZERO:
		return

	move_and_slide()

	# Si chocó de frente con una pared, move_and_slide() ya anuló la componente
	# bloqueada; frenamos el resto progresivamente hasta el reposo.
	velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
