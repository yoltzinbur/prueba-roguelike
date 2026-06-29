extends Node2D

@export var coin_scene: PackedScene = preload("res://Entities/Collectables/Coin/Coin.tscn")
@export var coins_to_drop: int = 5
@export var drop_radius: float = 20.0
## Si se asigna, el cofre persiste su estado abierto vía SaveManager (no vuelve a dar
## monedas tras salir y volver). Vacío = cofre no persistente (cueva, MainBueno).
@export var save_id: String = ""

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var interaction_area: Area2D = $InteractionArea
@onready var openAudio: AudioStreamPlayer = $AudioStreamPlayer

var is_opened: bool = false

func _ready() -> void:
	interaction_area.body_entered.connect(_on_body_entered)
	interaction_area.body_exited.connect(_on_body_exited)
	# Cofre persistente ya abierto en una sesión previa: mostrarlo abierto y vacío.
	if save_id != "" and SaveManager.is_chest_opened(save_id):
		_show_already_opened()

func interact() -> void:
	if not is_opened:
		open_chest()

func open_chest() -> void:
	is_opened = true

	if anim.sprite_frames.has_animation("open"):
		anim.play("open")
		if openAudio:
			openAudio.play()

	spawn_coins()

	# Persistir la apertura para que no vuelva a dar monedas al reentrar a la escena.
	if save_id != "":
		SaveManager.mark_chest_opened(save_id)

## Deja el cofre en su estado abierto final, sin soltar monedas ni sonido. Lo usa el
## arranque cuando el cofre ya estaba abierto en el guardado.
func _show_already_opened() -> void:
	is_opened = true
	if anim.sprite_frames.has_animation("open"):
		anim.animation = "open"
		anim.frame = anim.sprite_frames.get_frame_count("open") - 1
		anim.pause()

func spawn_coins() -> void:
	for i in range(coins_to_drop):
		var coin_instance = coin_scene.instantiate()

		var angle = randf() * 2 * PI
		var distance = randf() * drop_radius
		var offset = Vector2(cos(angle), sin(distance)) * distance
		coin_instance.global_position = global_position + offset

		get_tree().current_scene.add_child(coin_instance)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		body.current_interactable = self

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("Player") and body.current_interactable == self:
		body.current_interactable = null
