extends Area2D

var player
var grid_position

func _ready():
	add_to_group("entity_detect")

func _process(delta):
	if !is_instance_valid(player):
		remove_from_group("entity_detect")
		queue_free()
	else:
		var new_grid_position = global.get_grid_pos(player.position) 
		if new_grid_position != grid_position:
			grid_position = new_grid_position
			position = new_grid_position * global.SCREEN_SIZE
