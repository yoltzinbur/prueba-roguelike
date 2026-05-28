extends Node

signal coins_updated(total_coins: int)

var coins: int = 0:
	set(value):
		coins = value
		coins_updated.emit(coins)

func add_coins(amount: int = 1) -> void:
	coins += amount
