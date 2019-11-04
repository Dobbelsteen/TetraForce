extends Node

var game_state
signal player_entered

func _ready():
	world_state.local_map = self
	
	# Connect gamestate
	game_state = preload("res://engine/game_state/game_state.tscn").instance()
	add_child(game_state)
	game_state.connect("got_state", self, "_state_loaded")
	
	add_child(preload("res://engine/camera.tscn").instance())
	add_child(preload("res://ui/hud.tscn").instance())
	
	add_new_player(world_state.player_id)
	for peer in world_state.local_peers:
		add_new_player(peer)

	# TODO: Failsafe, in case player can't get state from current owner
	screenfx.play("fadein")
	screenfx.stop() # Wait on the first frame until state is loaded
	
	# Should keep the effect white until we get the gamestate from the server, if needed.
	set_process(false)

func _state_loaded():
	set_process(true)	
	screenfx.play()

func _process(delta): # TODO: Can improve this to make it trigger once every map change
	var visible_enemies = []
	for entity_detect in get_tree().get_nodes_in_group("entity_detect"):
		for entity in entity_detect.get_overlapping_bodies():
			if entity.is_in_group("enemy"):
				visible_enemies.append(entity)
	
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if visible_enemies.has(enemy):
			enemy.set_physics_process(true)
		else:
			enemy.set_physics_process(false)
			enemy.position = enemy.home_position

func add_new_player(id):
	var new_player = preload("res://player/player.tscn").instance()
	new_player.name = str(id)
	new_player.set_network_master(id, true)
	
	var entity_detect = preload("res://engine/entity_detect.tscn").instance()
	entity_detect.player = new_player
	add_child(entity_detect)
	
	add_child(new_player)
	new_player.position = get_node("Spawn").position
	new_player.initialize()
	
	if id == get_tree().get_network_unique_id():
		new_player.get_node("Sprite").texture = load(network.my_player_data.skin)
		new_player.texture_default = load(network.my_player_data.skin)
		new_player.set_player_label(network.my_player_data.name)
	else:
		new_player.get_node("Sprite").texture = load(network.player_data.get(id).skin)
		new_player.texture_default = load(network.player_data.get(id).skin)
		new_player.set_player_label(network.player_data.get(id).name)
	
	emit_signal("player_entered", id)

func remove_player(id):
	get_node(str(id)).queue_free() # TODO: Make sure all other player nodes are gone?

remote func spawn_subitem(dropped, pos, subitem_name):
	var drop_instance = load(dropped).instance()
	drop_instance.name = subitem_name
	add_child(drop_instance)
	drop_instance.global_position = pos

remote func receive_chat_message(source, text):
	print_debug("Polo")
	global.player.chat_messages.append({"source": source, "message": text})
	var chatBox = get_node("HUD/Chat")
	if chatBox:
		chatBox.add_new_message(source, text)
