extends Droppable
	
func on_pickup(player):
	print_debug("Got a rupee!")
	delete()
