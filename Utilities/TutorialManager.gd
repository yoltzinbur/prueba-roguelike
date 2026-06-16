extends Node

signal mostrar_mensaje(texto: String)
signal ocultar_mensaje()

var pasos_completados = {
	"moverse": false,
	"atacar": false,
	"curar": false
}

func registrar_accion(accion: String):
	if accion in pasos_completados and not pasos_completados[accion]:
		pasos_completados[accion] = true
		verificar_siguiente_paso()

func verificar_siguiente_paso():
	if not pasos_completados["moverse"]:
		mostrar_mensaje.emit("Usa las flechas o WASD para moverte")
	elif not pasos_completados["atacar"]:
		mostrar_mensaje.emit("¡Bien! Ahora presiona ATTACK para atacar")
	elif not pasos_completados["curar"]:
		mostrar_mensaje.emit("Genial. Ahora presiona R para curarte")
	else:
		ocultar_mensaje.emit()

# YA NO llames verificar_siguiente_paso() aquí
func _ready():
	pass

# La UI llama esta función cuando está lista
func iniciar_tutorial():
	verificar_siguiente_paso()
