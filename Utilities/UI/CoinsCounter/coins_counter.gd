extends Control

@onready var label: Label = $Label

func _ready() -> void:
	GameManager.coins_updated.connect(_update_coin_text)
	label.text = "Moneditas " + str(GameManager.coins)

func _update_coin_text(new_amount: int) -> void:
	label.text = "Moneditas " + str(new_amount)
