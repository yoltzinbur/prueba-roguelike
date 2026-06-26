extends Control

@onready var potion_label: Label = $PotionLabel
@onready var potion_icon: TextureRect = $PotionIcon

var health_component: HealthComponent = null

func _ready() -> void:
	var player = get_tree().get_first_node_in_group("Player")
	if player and player.has_node("HealthComponent"):
		health_component = player.get_node("HealthComponent")
		health_component.flasks_changed.connect(_on_flasks_changed)

	update_ui()

func update_ui() -> void:
	if health_component:
		potion_label.text = str(health_component.flasks)
		if health_component.flasks <= 0:
			potion_icon.modulate = Color(0.5, 0.5, 0.5)
		else:
			potion_icon.modulate = Color.WHITE

func _on_flasks_changed(_current_flasks: int) -> void:
	update_ui()

func add_potion(amount: int = 1) -> void:
	if health_component:
		health_component.flasks = clampi(health_component.flasks + amount, 0, 5)

func set_max_potions(value: int) -> void:
	if health_component:
		health_component.flasks = clampi(health_component.flasks, 0, value)
