extends CanvasLayer

@onready var panel = $Panel
@onready var label = $Panel/Label

func _ready():
	print("TutorialUI cargada") 
	TutorialManager.mostrar_mensaje.connect(_on_mostrar_mensaje)
	TutorialManager.ocultar_mensaje.connect(_on_ocultar_mensaje)
	panel.visible = false
	
	# Ahora SÍ pedimos el primer mensaje, porque ya estamos listos
	TutorialManager.iniciar_tutorial()

func _on_mostrar_mensaje(texto: String):
	label.text = texto
	panel.visible = true

func _on_ocultar_mensaje():
	panel.visible = false
