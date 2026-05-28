extends Collectible

@export var value: int = 1
@export var coin_sound: AudioStream

func _activate_effect(_player: Node2D) -> void:
	GameManager.add_coins(value)
	
	if coin_sound:
		SoundManager.play_sound(coin_sound)
