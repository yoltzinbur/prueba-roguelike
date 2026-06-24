extends Node2D

@export var coin_scene: PackedScene = preload("res://Entities/Collectables/Coin/Coin.tscn")
@export var coins_to_drop: int = 5
@export var drop_radius: float = 20.0

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var interaction_area: Area2D = $Area2D
@onready var openAudio: AudioStreamPlayer = $AudioStreamPlayer

var is_opened: bool = false

func _ready() -> void:
	interaction_area.body_entered.connect(_on_body_entered)
	interaction_area.body_exited.connect(_on_body_exited)

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
