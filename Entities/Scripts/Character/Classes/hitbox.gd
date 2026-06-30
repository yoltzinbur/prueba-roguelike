class_name HitBox
extends Area2D

@export var damage: int = 1 : set = set_damage, get = get_damage

func set_damage(value: int):
	damage = value

func get_damage() -> int:
	return damage

## Devuelve la entidad (el CharacterBody2D) dueña de este HitBox subiendo por el árbol.
## La usan el parry/HurtBox para distinguir de quién viene un golpe (p. ej. jefe vs enemigo
## normal). Devuelve null si el HitBox no cuelga de un cuerpo (p. ej. un proyectil suelto).
func get_source_entity() -> Node2D:
	var n: Node = get_parent()
	while n:
		if n is CharacterBody2D:
			return n
		n = n.get_parent()
	return null
