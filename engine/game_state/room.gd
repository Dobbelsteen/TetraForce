extends Node

class_name Room


#var map 
var tile_rect = Rect2(0, 0, 16, 9)
var entities = []
var enemies = [] 

signal player_entered()
signal player_exited()
signal enemies_defeated()
signal empty()

func add_entity(entity):
	entities.append(entity)

	if entity.is_in_group("enemy"):
		enemies.append(entity)

	if entity.is_in_group("player"):
		emit_signal("player_entered")

func remove_entity(entity):
	entities.erase(entity)

	if entity.is_in_group("enemy"):
		enemies.erase(entity)

		if enemies.empty():
			emit_signal("enemies_defeated")

	if entity.is_in_group("player"):
		emit_signal("player_exited")

	if entities.empty():
		emit_signal("empty")
