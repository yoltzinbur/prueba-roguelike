class_name Collectible
extends Node2D

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	if anim and anim.sprite_frames.has_animation("idle"):
		anim.play("idle")
		

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		_activate_effect(body)
		queue_free()

func _activate_effect(_player: Node2D) -> void:
	pass
