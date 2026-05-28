extends Collectible

@export var value: int = 1

func _activate_effect(_player: Node2D) -> void:
	GameManager.add_coins(value)
