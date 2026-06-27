class_name Interrupter
extends StaticBody2D
## Interruptor accionable. Al interactuar (vía InteractionArea.interacted)
## alterna su estado ON/OFF, cambia el frame del Sprite2D y notifica el cambio
## con la señal interrupter_changed.

## Emitida con el nuevo estado cada vez que el interruptor se alterna.
signal interrupter_changed(is_on: bool)

# Frames del Sprite2D (vframes = 2): 1 = apagado (estado inicial), 0 = encendido.
const FRAME_OFF: int = 1
const FRAME_ON: int = 0

@onready var sprite: Sprite2D = $Sprite2D
@onready var interaction_area: InteractionArea = $InteractionArea

var is_on: bool = false

func _ready() -> void:
	sprite.frame = FRAME_OFF
	interaction_area.interacted.connect(_on_interacted)

func _on_interacted() -> void:
	toggle()

## API pública: invierte el estado, actualiza el sprite y emite el cambio.
func toggle() -> void:
	is_on = not is_on
	sprite.frame = FRAME_ON if is_on else FRAME_OFF
	interrupter_changed.emit(is_on)
