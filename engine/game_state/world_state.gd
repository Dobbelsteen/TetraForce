extends Node

const SERVER_TIMEOUT: = 2 # Max time to wait for server to respond
const CONNECT_ATTEMPTS: = 10 # Max amount of tries to get game state before taking over map
var _connects_attempted: = 0

# Kinda have to hardcode these for now.
var START_SCENE: = "res://maps/overworld.tscn"
var START_SCENE_NAME: = "overworld"

var original_state: = {}
var updated_state: = {}

var is_world_owner: = false
var is_map_owner: = false # Precache whether or not the local player is the map owner of his/her map
var local_map_owner: = -1 # If not, store the id of the local_map_owner

var is_multiplayer: = false

var player_id: = -1
var players: = {} # Dictionary of players + their map, eg. {1: "overworld", 1321564: "testmap"}
var map_owners: = {} # Dictionary of maps + their owner, eg. {"overworld": 1, "testmap": 123123123}

var local_map = null
var local_peers: = [] # Peers of local player for local map

var _timer # Timer object reference to keep track of server timeout
var _got_world_state: = false # whether a client got the state of the server yet or not

signal got_world_state


func set_value(key, value):
	if !updated_state.has(key) || updated_state[key] != value: 
		updated_state[key] = value
		# Notify others of the change
		if player_id == 1:
			rpc('_remote_set_value', key, value)
		else:
			for player in players:
				if player != player_id:
					rpc_id(player, '_remote_set_value', key, value)


remote func _remote_set_value(key, value):
	updated_state[key] = value

func get_value(key):
	# Wait until we get the world state values
	if !_got_world_state:
		# TODO: Should use timeout instead of yield tbh
		yield(self, "got_world_state")
	
	if updated_state.has(key):
		return updated_state[key]
	else:
		return null

func get_local_map_owner():
	if !local_map:
		return -1 # This shouldn't happen
	return map_owners[local_map.name]

func prepare_world_state(is_owner) -> void:
	get_tree().connect("network_peer_disconnected", self, "_player_disconnected")
	is_world_owner = is_owner
	if is_world_owner:
		_owner_joined_world()
	else:
		get_tree().connect("network_peer_connected", self, "_client_joined_world")


# Should be called by exits/teleports to annouce a player changing maps
func announce_map_change(map):
	network_debugger.write_log("Me, Player " + str(player_id) + " changed map to " + map)
	_player_enters_map(player_id, map)
	
	if is_multiplayer:
		rpc("_notify_player_map_change", map)


func _create_world(id): # Create the world for a player_id
	_add_player(id)
	
	var start_scene = load(START_SCENE).instance()
	local_map = start_scene
	get_tree().get_root().add_child(start_scene)
	
	network_debugger.write_log(str(player_id) + " created the world")
	network_debugger.write_log(str(local_peers) + " are the other players")
	
	network.call_deferred("initialize", true)
	network.call_deferred("set_process", true)


func _owner_joined_world():
	# Connect self to stuff
	#keep track of ALL scene changes
	_got_world_state = true
	emit_signal("got_world_state")
	network_debugger.write_log("Initialized world as world owner")
	player_id = 1
	call_deferred("_create_world", 1)


func _add_player(id):
	_player_enters_map(id, START_SCENE_NAME)


func _player_disconnected(id):
	_remove_player_from_map(id, players[id])
	players.erase(id)
	
	if players.size() == 1:
		is_multiplayer = false


remote func _notify_player_map_change(map):
	var sender = get_tree().get_rpc_sender_id()
	_player_enters_map(sender, map)
	network_debugger.write_log("Other Player " + str(sender) + " changed map to " + map)


# Called whenever a player enters/changes map
func _player_enters_map(id, map):
	# Check if the player was in another map
	var old_map = null
	if players.has(id):
		old_map = players[id]
	if old_map:
		# Remove player from previous map, this has to be done first
		_remove_player_from_map(id, old_map)
	
	# Move player to another map
	players[id] = map
	# Check map ownership
	if map_owners.has(map):
		# Map already has an owner, so the local player can't be owner
		if id == player_id: 
			is_map_owner = false 
	else:
		if id == player_id:
			is_map_owner = true # Map doesn't have an owner, make local player owner
		map_owners[map] = id # Make this player the owner of the scene
	
	# If this affects the local already on the map player, update peers
	if players[player_id] == map:
		var new_peers = []
		for player in players:
			if players[player] == map && player != player_id:
				new_peers.append(player)
		local_peers = new_peers
		network.map_peers = local_peers
		#network.map_peers = map_peers[map]
		
		# Add the player to our map
		if id != player_id:
			local_map.add_new_player(id)


# Clean up removing a player from a map, and reassign owners if needed
func _remove_player_from_map(id, map):
	# Check if ownership of old map changes
	if map && map_owners[map] == id: # Current map owner is being removed from his map
		var players_on_map = []
		# Check which players are left on the map
		for player in players:
			if players[player] == map && player != id: # All players on that map, except the one we're removing
				players_on_map.append(player)
			
		if players_on_map.empty():
			# Clear the entire map, no one's left on map
			map_owners.erase(map)
		else:
			var new_owner = players_on_map[0] # new owner is the first of the players left on map
			map_owners[map] = new_owner # Assign new owner
			
			if new_owner == player_id: # If new_owner is current player, make it owner
				is_map_owner = true
			players_on_map.erase(player_id) # Remove local player from peer list
			local_peers = players_on_map
			network.map_peers = local_peers
	elif map:
		if players[player_id] == map && player_id != id:
			local_peers.erase(id)
			network.map_peers = local_peers
	
	# Remove player from local map if the local player is on that map
	if players[player_id] == map:
		# Remove player from map scene
		if local_map:
			local_map.call_deferred("remove_player", id)


func _client_joined_world(id):
	player_id = get_tree().get_network_unique_id()
	get_tree().disconnect("network_peer_connected", self, "_client_joined_world")
	rpc_id(1, "_send_world_state_to_peer")
	
	_timer = Timer.new()
	_timer.set_wait_time(SERVER_TIMEOUT)
	_timer.set_one_shot(true)
	_timer.connect("timeout", self, "_on_server_timeout") 
	add_child(_timer)
	_timer.start()


remote func _send_world_state_to_peer():
	var peer = get_tree().get_rpc_sender_id()
	# We can get the sender id from this handy method, instead of sending it along again
	network_debugger.write_log("Sending world state to " + str(peer))
	_add_player(peer) # Add new player to the playerList in the start_scene
	is_multiplayer = true
	rpc_id(peer, "_get_world_state_from_owner", updated_state, players, map_owners)


remote func _get_world_state_from_owner(state, player_list, map_owners_list):
	updated_state = state
	players = player_list
	map_owners = map_owners_list
	is_multiplayer = true
	_got_world_state = true
	emit_signal("got_world_state")
	network_debugger.write_log("Got world state from server")
	network_debugger.write_log(str(players))
	network_debugger.write_log(str(state))
	
	player_id = get_tree().get_network_unique_id()
	
	call_deferred("_create_world", player_id)

func _on_server_timeout():
	_connects_attempted += 1
	if _got_world_state:
		remove_child(_timer)
		_timer.queue_free()
		return # Everything was fine
	
	if _connects_attempted <= CONNECT_ATTEMPTS:
		_client_joined_world(player_id) # Just try again
		return