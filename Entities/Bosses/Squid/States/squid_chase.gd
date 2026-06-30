extends SquidState
## Cerebro de combate del Jefe Squid: persigue al jugador en la arena abierta y decide qué
## ataque ejecutar según la distancia y los cooldowns:
##   - en corto (melee_range): golpe melé (Attack).
##   - a media distancia y con cooldown: embiste en bucle persiguiendo (AttackLoop).
##   - a distancia y con cooldown: dispara un proyectil (Shoot).
##   - si no, persigue.

## Distancia para el golpe melé normal.
@export var melee_range: float = 28.0
## Distancia máxima para lanzar el ataque en bucle.
@export var loop_range: float = 90.0
## Distancia máxima para disparar.
@export var shoot_range: float = 170.0
## Tiempo mínimo entre ataques en bucle, en segundos.
@export var loop_cooldown: float = 6.0
## Tiempo mínimo entre disparos, en segundos.
@export var shoot_cooldown: float = 3.0
## Descanso entre CUALQUIER par de ataques (cuenta desde que termina uno). Da respiro al
## jugador para que no sea un machacabotones imparable.
@export var attack_cooldown: float = 1.0
## Super armadura (poise): tiempo mínimo entre reacciones de Hit. Tras encajar un golpe, el
## jefe SIGUE recibiendo daño pero IGNORA la interrupción durante este margen. Evita el
## bloqueo en el que machacando el ataque pegado al jefe (p. ej. desde arriba) nunca llega a
## contraatacar porque cada golpe lo reinicia a Hit.
@export var hit_poise_cooldown: float = 1.5

# Marcas de tiempo (ms) del último uso de cada ataque, para respetar sus cooldowns. Persisten
# porque el nodo State se reutiliza entre transiciones.
var _last_loop_ms: float = -1.0e9
var _last_shoot_ms: float = -1.0e9
# Tiempo acumulado en Chase desde el último ataque (se reinicia al entrar, es decir, al volver
# de un ataque): el jefe no vuelve a atacar hasta superar attack_cooldown.
var _rest_t: float = 0.0
# Marca de tiempo (ms) de la última reacción de Hit, para aplicar la super armadura. Persiste
# entre transiciones (el nodo State se reutiliza), así el poise se respeta al volver de Hit.
var _last_hit_react_ms: float = -1.0e9

func enter(args := {}):
	super.enter(args)
	_rest_t = 0.0
	if health_component and not health_component.damaged.is_connected(_on_damaged):
		health_component.damaged.connect(_on_damaged)
	if anim and anim.sprite_frames.has_animation("walk"):
		anim.play("walk")

func state_physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		transitioned.emit(self, "Idle", {})
		return

	_rest_t += delta

	var dist := distance_to_player()
	var dir := direction_to_player()
	face_player(dir)

	# Mientras no se cumpla el descanso entre ataques, sólo persigue (o se mantiene cerca).
	if _rest_t < attack_cooldown:
		_pursue(delta, dir)
		return

	# En rango melé: golpear.
	if dist <= melee_range:
		transitioned.emit(self, "Attack", {})
		return

	var now := float(Time.get_ticks_msec())

	# A media distancia y con cooldown: embestida en bucle.
	if dist <= loop_range and now - _last_loop_ms >= loop_cooldown * 1000.0:
		_last_loop_ms = now
		transitioned.emit(self, "AttackLoop", {})
		return

	# A distancia y con cooldown: disparo.
	if dist <= shoot_range and now - _last_shoot_ms >= shoot_cooldown * 1000.0:
		_last_shoot_ms = now
		transitioned.emit(self, "Shoot", {})
		return

	# Si no, perseguir en línea recta hacia el jugador.
	_pursue(delta, dir)

## Persigue al jugador en línea recta (animación de caminar + movimiento).
func _pursue(delta: float, dir: Vector2) -> void:
	if anim and anim.sprite_frames.has_animation("walk"):
		anim.play("walk")
	velocity_component.move(delta, dir)

func _on_damaged() -> void:
	# Super armadura: si encajó un golpe hace poco, absorbe este sin interrumpirse (el daño ya
	# se aplicó en HealthComponent). Así puede contraatacar aunque lo machaquen pegado a él.
	var now := float(Time.get_ticks_msec())
	if now - _last_hit_react_ms < hit_poise_cooldown * 1000.0:
		return
	_last_hit_react_ms = now
	transitioned.emit(self, "Hit", {})

func exit():
	if health_component and health_component.damaged.is_connected(_on_damaged):
		health_component.damaged.disconnect(_on_damaged)
