extends Node

signal mostrar_mensaje(texto: String)
signal ocultar_mensaje()

## Tamaño (px) al que se incrustan los íconos de botón en los mensajes del tutorial.
## Se usan las variantes "_white" de los SVG (íconos ya en blanco) para que se lean
## sobre el panel oscuro del banner sin depender de teñido por código.
const _ICON_SIZE: int = 20
const _ICONS_DIR: String = "res://Utilities/UI/TouchControls/Icons/"

var pasos_completados = {
	"moverse": false,
	"rodar":false,
	"atacar": false,
	"parry": false,
	"curar": false,
	"interactuar":false,
	"entrar":false
}

## Devuelve el BBCode para incrustar el ícono del botón `nombre` (attack, parry,
## dodge, heal, enter, map...) dentro de un mensaje del tutorial.
func _icono(nombre: String) -> String:
	return "[img=%d]%s%s.svg[/img]" % [_ICON_SIZE, _ICONS_DIR, nombre]

func registrar_accion(accion: String):
	if accion in pasos_completados and not pasos_completados[accion]:
		pasos_completados[accion] = true
		verificar_siguiente_paso()

func verificar_siguiente_paso():
	if not pasos_completados["moverse"]:
		mostrar_mensaje.emit("Mueve el  [b]joystick[/b]  de la izquierda para caminar")
	elif not pasos_completados["rodar"]:
		mostrar_mensaje.emit("Toca %s para rodar y esquivar" % _icono("dodge_white"))
	elif not pasos_completados["atacar"]:
		mostrar_mensaje.emit("¡Bien! Ahora toca %s para atacar" % _icono("attack_white"))
	elif not pasos_completados["parry"]:
		mostrar_mensaje.emit("Toca %s para hacer un parry: refleja proyectiles y bloquea/empuja a los enemigos" % _icono("parry_white"))
	elif not pasos_completados["curar"]:
		mostrar_mensaje.emit("Genial. Ahora toca %s para curarte" % _icono("heal_white"))
	elif not pasos_completados["interactuar"]:
		mostrar_mensaje.emit("Toca %s para abrir el cofre" % _icono("enter_white"))
	elif not pasos_completados["entrar"]:
		mostrar_mensaje.emit("Genial, dirígete a la entrada de la cueva y toca %s" % _icono("enter_white"))
	else:
		ocultar_mensaje.emit()

# YA NO llames verificar_siguiente_paso() aquí
func _ready():
	pass

# La UI llama esta función cuando está lista
func iniciar_tutorial():
	verificar_siguiente_paso()
