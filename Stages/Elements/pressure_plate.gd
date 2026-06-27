class_name PressurePlate
extends Node2D
## Placa de presión. Solo reacciona a las Cajas (Box), nunca al jugador ni a otros
## cuerpos: en un pasillo estrecho el jugador pisa las placas de forma inevitable y
## eso falsearía la resolución del puzzle. Se activa mientras haya al menos una caja
## sobre su InteractionArea y se desactiva solo cuando la última se retira.
## Cambia de frame y notifica su estado con la señal plate_activated.

## Emitida al activarse (true) o desactivarse (false) la placa.
signal plate_activated(activated: bool)

# Frames del Sprite2D (hframes = 2): 0 = sin presionar, 1 = presionada.
const FRAME_INACTIVE: int = 0
const FRAME_ACTIVE: int = 1

@onready var sprite: Sprite2D = $Sprite2D
@onready var interaction_area: Area2D = $InteractionArea

# Contador de cajas sobre la placa: evita desactivarla si queda alguna encima.
var _boxes_on_plate: int = 0

func _ready() -> void:
	sprite.frame = FRAME_INACTIVE
	interaction_area.body_entered.connect(_on_body_entered)
	interaction_area.body_exited.connect(_on_body_exited)

## Es el flanco de subida (primera caja) el que activa la placa. Ignora al jugador
## y cualquier otro cuerpo que no sea una Caja.
func _on_body_entered(body: Node2D) -> void:
	if not body is Box:
		return
	_boxes_on_plate += 1
	if _boxes_on_plate == 1:
		sprite.frame = FRAME_ACTIVE
		plate_activated.emit(true)

## Solo la última caja en salir desactiva la placa. Ignora al jugador y a cualquier
## otro cuerpo que no sea una Caja.
func _on_body_exited(body: Node2D) -> void:
	if not body is Box:
		return
	_boxes_on_plate = max(_boxes_on_plate - 1, 0)
	if _boxes_on_plate == 0:
		sprite.frame = FRAME_INACTIVE
		plate_activated.emit(false)
