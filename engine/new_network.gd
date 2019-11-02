extends Node

var is_active = false # whether or not we're in multiplayer
var current_map = null

var active_maps = {}
var current_players = []
var map_owners = {}
var map_peers = []

var current_player_id = 0
var player_data = {}

var my_player_data = {
	skin ="res://player/player.png",
	name = "", 
}

var clock

func _ready():
	set_process(false)
	get_tree().connect("network_peer_connected", self, "_player_connected")
	get_tree().connect("network_peer_disconnected", self, "_player_disconnected")

func _player_connected(id):
	is_active = true
	update_current_players()
	network_debugger.write_log("Player connected: " + str(id) + " Me: " + current_player_id)
	
	if current_player_id == 1:
		network_debugger.write_log("I'm the server")
		# Server should announce to everyone about the new player?
		
	rpc("_notify_player_map_change", current_map.name)


func _player_disconnected(id):
	if get_tree().is_network_server():
		active_maps.erase(id)
	update_maps()


func announce_map_change(map):
	network_debugger.write_log("Me, Player " + str(network.current_player_id) + " changed map to " + map)
	var new_map_has_owner = false
	for peer in active_maps:
		if map == active_maps[peer]:
			new_map_has_owner = true
			continue
			# There is already an owner
	if !new_map_has_owner:
		network_debugger.write_log("I'm going to take over a new map")
		active_maps[network.current_player_id] = map
	network_debugger.force_write_to_log()
	rpc("_notify_player_map_change", map)
	
	call_deferred("update_current_players")
	call_deferred("update_maps")
	#update_current_players()
	#update_maps()	
	pass

remote func _notify_player_map_change(map):
	var sender = get_tree().get_rpc_sender_id()
	network_debugger.write_log("Other Player " + str(sender) + " changed map to " + map + " We are at " + current_map)
	if current_map.name == active_maps[sender]:
		map_peers.erase(sender)

	var new_map_has_owner = false
	for peer in active_maps:
		if map == active_maps[peer]:
			new_map_has_owner = true
			#continue
			# There is already an owner
	network_debugger.write_log("new map has an owner: " + str(new_map_has_owner))
	
	if !new_map_has_owner:
		map_owners[sender] = map
	
	active_maps[sender] = map
	
	network_debugger.force_write_to_log()
	call_deferred("update_current_players")
	call_deferred("update_maps")
	#update_current_players()
	#update_maps()	
	

func update_current_players():
	var new_current_players = []
	for peer in active_maps:
		if active_maps.get(peer) == current_map.name:
			new_current_players.append(peer)
	
	# Should check if there's still more than 1 player around, otherwise put is_active to false
	
	var other_players = new_current_players
	other_players.erase(get_tree().get_network_unique_id())
	map_peers = other_players
	current_players = new_current_players


func initialize():
	clock = Timer.new()
	clock.wait_time = 5 # TODO: Restore clock time to 0.1
	clock.one_shot = false
	#clock.owner = self
	add_child(clock)
	clock.start()
	clock.connect("timeout", self, "clock_update")
	
	if get_tree().is_network_server():
		player_data[1] = my_player_data
	# Store this value for easier access later
	current_player_id = get_tree().get_network_unique_id()
	#if !get_tree().is_network_server():
	if is_active && current_player_id != 1:
		rpc_id(1, "_receive_my_player_data", my_player_data)

func get_current_map_owner():
	return map_owners[current_map.name]

func is_scene_owner():
	# Player will be the map owner if the map is not active yet, or if it's the owner
	return !map_owners.has(current_map.name) || map_owners[current_map.name] == current_player_id

remote func _receive_my_player_data(new_player_data):
	var id = get_tree().get_rpc_sender_id()
	var collision_count = 0
	var player_name = new_player_data.name
	
	while _check_dupe_name(player_name):
		collision_count += 1
		player_name = _get_player_name(new_player_data.name, collision_count)
		
	new_player_data.name = player_name
	player_data[id] = new_player_data
	
	rpc("_receive_all_player_data", player_data)

	
func clear():
	if is_instance_valid(current_map):
		current_map.free()
	if is_instance_valid(clock):
		clock.stop()
	active_maps.clear()
	current_players.clear()
	map_owners.clear()
	map_peers.clear()
	player_data.clear()
	is_active = false
	current_player_id = 0



remote func _receive_all_player_data(received_player_data):
	player_data = received_player_data

func clock_update():
	update_maps()
	update_current_players()

func update_maps():
	if get_tree().is_network_server():
		active_maps[1] = current_map.name
		
		rpc("_receive_active_maps", active_maps)
		_update_map_owners()
	else:
		_send_current_map()
	
	update_current_players()
	current_map.update_players()


func _update_map_owners():
	for map in active_maps.values():
		if !map_owners.keys().has(map):
			map_owners[map] = active_maps.keys()[active_maps.values().find(map)]
	
	# remove old maps
	for map in map_owners.keys():
		if !active_maps.values().has(map):
			map_owners.erase(map)
	
	# reassign owners
	for map in map_owners.keys():
		var map_owner = map_owners.get(map) # gets player id of map
		if active_maps[map_owner] != map: # if player id is not in that map...
			map_owners[map] = active_maps.keys()[active_maps.values().find(map)] # change owner to a player in that map
	
	rpc("_receive_map_owners", map_owners)

# client only, sends current_map to server
func _send_current_map():
	print('asking for ', current_map.name)
	rpc_id(get_current_map_owner(), "_receive_current_map", current_map.name)

# server only, updates active_maps
remote func _receive_current_map(map):
	print("Sending data")
	print(active_maps)
	var sender_id = get_tree().get_rpc_sender_id()
	active_maps[sender_id] = map
	rpc_id(sender_id, "_receive_active_maps", active_maps)

# received by clients
remote func _receive_active_maps(maps):
	active_maps = maps

remote func _receive_map_owners(owners):
	map_owners = owners

func _get_player_name(player_name, collision_count):
	if collision_count == 0:
		return player_name
	else:
		return player_name + "%d" % collision_count

func _check_dupe_name(player_name):
	for value in player_data.values():
		if player_name == value.name:
			return true
			
	return false