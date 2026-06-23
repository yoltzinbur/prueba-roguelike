extends Control

@onready var potion_label: Label = $PotionLabel
@onready var potion_icon: TextureRect = $PotionIcon

# Referencia al jugador para acceder a su cantidad de pociones
var player: Node2D = null

func _ready() -> void:
	# Buscar al jugador en la escena principal
	player = get_tree().root.get_node_or_null("Main/Player")
	
	if player:
		# Conectar a señales del componente de salud si existe
		if player.has_node("HealthComponent"):
			var health_component = player.get_node("HealthComponent")
			health_component.health_changed.connect(_on_health_changed)
	
	update_ui()

func _process(delta: float) -> void:
	# Actualizar el contador si el jugador cambia su cantidad de pociones
	if player and player.has_node("HealthComponent"):
		# La interfaz se actualiza automáticamente por la señal
		pass

func update_ui() -> void:
	# Actualizar la interfaz con el número actual de pociones
	if potion_label and player and player.has_node("HealthComponent"):
		var health_component = player.get_node("HealthComponent")
		potion_label.text = str(health_component.flasks)
	
	# Cambiar el icono según la cantidad
	if player and player.has_node("HealthComponent"):
		var health_component = player.get_node("HealthComponent")
		if health_component.flasks <= 0:
			potion_icon.modulate = Color(0.5, 0.5, 0.5)  # Gris cuando no hay pociones
		else:
			potion_icon.modulate = Color.WHITE

func _on_health_changed(current_health: int, max_health: int) -> void:
	# Esta señal se emite cuando la salud cambia, pero también queremos actualizar 
	# el contador de pociones cuando se usa una poción
	update_ui()

func add_potion(amount: int = 1) -> void:
	if player and player.has_node("HealthComponent"):
		var health_component = player.get_node("HealthComponent")
		health_component.flasks += amount
		health_component.flasks = clampi(health_component.flasks, 0, 5)
	
	update_ui()

func set_max_potions(value: int) -> void:
	if player and player.has_node("HealthComponent"):
		var health_component = player.get_node("HealthComponent")
		health_component.flasks = clampi(health_component.flasks, 0, value)
	
	update_ui()
