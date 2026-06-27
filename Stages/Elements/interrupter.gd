class_name Interrupter
extends StaticBody2D
## Interruptor accionable. Alterna su estado ON/OFF al interactuar (vía
## InteractionArea.interacted, con la entrada "enter") o al recibir un golpe del
## ataque del jugador (Área en la capa 6 = hitbox_player). Cambia el frame del
## Sprite2D y notifica el cambio con la señal interrupter_changed. Además expone un
## `value` entero que muestra en una etiqueta y que aporta a la suma del puzzle
## aritmético cuando está encendido.

## Emitida con el nuevo estado cada vez que el interruptor se alterna.
signal interrupter_changed(is_on: bool)

# Frames del Sprite2D (vframes = 2): 1 = apagado (estado inicial), 0 = encendido.
const FRAME_OFF: int = 1
const FRAME_ON: int = 0

# Máscara del Área de detección de golpe: capa 6 (hitbox_player). Se excluye la
# capa 3 (hitbox genérico de enemigos) a propósito, para que los enemigos no
# alteren el puzzle al atacar.
const ATTACK_LAYER_MASK: int = 1 << 5
# Tiempo de bloqueo tras un golpe, para no alternar varias veces por un mismo ataque.
const ATTACK_COOLDOWN: float = 0.3

const LABEL_FONT := preload("res://Assets/Fonts/Minecraft.ttf")

@onready var sprite: Sprite2D = $Sprite2D
@onready var interaction_area: InteractionArea = $InteractionArea

var is_on: bool = false
## Valor entero que aporta a la suma del puzzle cuando está encendido.
var value: int = 0

# Bloqueado: ignora interacción y golpes (p. ej. al resolver el puzzle, para que el
# jugador no pueda alterar la solución).
var _locked: bool = false

var _value_label: Label
var _attack_locked: bool = false

func _ready() -> void:
	sprite.frame = FRAME_OFF
	interaction_area.interacted.connect(_on_interacted)
	_setup_attack_detector()
	_update_value_label()

func _on_interacted() -> void:
	toggle()

## API pública: invierte el estado, actualiza el sprite y emite el cambio. Si está
## bloqueado, no hace nada.
func toggle() -> void:
	if _locked:
		return
	is_on = not is_on
	sprite.frame = FRAME_ON if is_on else FRAME_OFF
	interrupter_changed.emit(is_on)

## API pública: bloquea el interruptor para que no pueda alternarse (puzzle resuelto).
func lock() -> void:
	_locked = true

## API pública: fija el valor que aporta el interruptor y refresca su etiqueta.
func set_value(new_value: int) -> void:
	value = new_value
	_update_value_label()

## Crea (una sola vez) y actualiza la etiqueta con el valor del interruptor, fija
## sobre el sprite para que el jugador sepa cuánto suma al encenderse.
func _update_value_label() -> void:
	if _value_label == null:
		var settings := LabelSettings.new()
		settings.font = LABEL_FONT
		settings.font_size = 8
		_value_label = Label.new()
		_value_label.label_settings = settings
		_value_label.position = Vector2(4.0, -10.0)
		add_child(_value_label)
	_value_label.text = str(value)

## Añade un Área2D que detecta el ataque del jugador (capa 6) para alternar el
## interruptor también a golpes, además de con la entrada "enter".
func _setup_attack_detector() -> void:
	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask = ATTACK_LAYER_MASK
	var collision := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 8.0
	collision.shape = circle
	collision.position = Vector2(8, 8)
	area.add_child(collision)
	add_child(area)
	area.area_entered.connect(_on_attack_detected)

## Alterna el interruptor al recibir un golpe, con un breve bloqueo para no contar
## varias veces el mismo ataque.
func _on_attack_detected(_area: Area2D) -> void:
	if _attack_locked:
		return
	_attack_locked = true
	toggle()
	await get_tree().create_timer(ATTACK_COOLDOWN).timeout
	_attack_locked = false
