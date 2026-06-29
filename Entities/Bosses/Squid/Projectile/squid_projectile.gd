extends HitBox
## Proyectil del Jefe Squid: un círculo rojo que viaja en línea recta hacia donde estaba el
## jugador al dispararse. Daña al jugador (es un HitBox en la capa de golpe) y se libera al
## impactar con el entorno o el jugador, o al agotar su tiempo de vida.

## Velocidad de avance en píxeles por segundo.
@export var speed: float = 180.0
## Radio visual y aproximado del proyectil.
@export var radius: float = 6.0
## Tiempo de vida antes de autodestruirse, en segundos.
@export var lifetime: float = 3.0

var direction: Vector2 = Vector2.ZERO

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	var timer := get_tree().create_timer(lifetime)
	timer.timeout.connect(queue_free)
	queue_redraw()

## Fija la dirección de viaje (normalizada). La llama el estado de disparo del jefe.
func launch(dir: Vector2) -> void:
	direction = dir.normalized()

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta

func _on_body_entered(_body: Node2D) -> void:
	queue_free()

func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, Color.RED)
