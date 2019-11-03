extends Node

const SERVER_TIMEOUT = 2 # Max time to wait for server to respond
const CONNECT_ATTEMPTS = 10 # Max amount of tries to get game state before taking over map
var _connects_attempted = 0

# Kinda have to hardcode these for now.
var START_SCENE = "res://maps/overworld.tscn"
var START_SCENE_NAME = "overworld"

var original_state = {}
var updated_state = {}

var is_world_owner = false
var is_map_owner = false # Precache whether or not the local player is the map owner of his/her map
var is_multiplayer = false

var player_id = -1
var players = {} # Dictionary of players + their map, eg. {1: "overworld", 1321564: "testmap"}
var map_owners = {} # Dictionary of maps + their owner, eg. {"overworld": 1, "testmap": 123123123}
var map_peers = {} # Dictionary of maps + their peers, eg {"overworld": [123,12], "testmap": []}
# map_peers does NOT include the map owner.

var _timer # Timer object reference to keep track of server timeout
var _got_world_state = false # whether a client got the state of the server yet or not

signal got_world_state


func prepare_world_state(is_owner) -> void:
	get_tree().connect("network_peer_disconnected", self, "_player_disconnected")
	is_world_owner = is_owner
	if is_world_owner:
		_owner_joined_world()
	else:
		_client_joined_world()


func _create_world():
	network.initialize()
	network.set_process(true)
	var start_scene = load(START_SCENE).instance()
	get_tree().get_root().add_child(start_scene)
	
	network_debugger.write_log(str(network.current_player_id) + " created the world")


func _owner_joined_world():
	# Connect self to stuff
	#keep track of ALL scene changes
	_got_world_state = true
	emit_signal("got_world_state")
	network_debugger.write_log("Initialized world as world owner")
	player_id = 1
	_add_player(1) # Add self to players
	_create_world()


func _add_player(id):
	_player_enters_map(id, START_SCENE_NAME)


func _player_disconnected(id):
	_remove_player_from_map(id, players[id])
	players.erase(id)
	
	if players.size() == 1:
		is_multiplayer = false


# Should be called by exits/teleports to annouce a player changing maps
func announce_map_change(map):
	network_debugger.write_log("Me, Player " + str(network.current_player_id) + " changed map to " + map)
	_player_enters_map(network.current_player_id, map)
	rpc("_notify_player_map_change", map)


remote func _notify_player_map_change(map):
	var sender = get_tree().get_rpc_sender_id()
	_player_enters_map(sender, map)
	network_debugger.write_log("Other Player " + str(sender) + " changed map to " + map)

# Called whenever a player enters/changes map
func _player_enters_map(id, map):
	var old_map = null
	if players.has(id):
		old_map = players[id]
		
	# Move to another map
	players[id] = map
	if map_owners.has(map):
		is_map_owner = false
		map_peers[map].append(id)
	else:
		is_map_owner = true
		map_owners[map] = id # Make this player the owner of the scene
		map_peers[map] = []
	
	# If this affects the local player, update peers
	if players[player_id] == map:
		network.map_peers = map_peers[map]
	
	# Remove player from previous map (if needed)
	_remove_player_from_map(id, old_map)


# Clean up removing a player from a map, and reassign owners if needed
func _remove_player_from_map(id, map):
	# Check if ownership of old map changes
	if map && map_owners[map] == id:
		if map_peers[map].empty():
			# Clear the entire map, no one's there
			map_owners.erase(map)
			map_peers.erase(map)
		else:
			var new_owner = map_peers[map][0] # new owner is the first of the current map peers
			map_owners[map] = new_owner # Assign new owner
			map_peers[map].erase(new_owner) # Remove new owner from peers
			
			if new_owner == player_id: # If new_owner is current player, make it owner
				is_map_owner = true
			# Do networking stuff for this guy to make him map owner of that scene
	elif map:
		# Just remove us from the peers
		map_peers[map].erase(id)
	# We were the map owner, check if there's any peers


func _client_joined_world():
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
	rpc_id(peer, "_get_world_state_from_owner", updated_state, players, map_owners, map_peers)


remote func _get_world_state_from_owner(state, player_list, map_owners_list, map_peers_list):
	updated_state = state
	players = player_list
	map_owners = map_owners_list
	map_peers = map_peers_list
	is_multiplayer = true
	_got_world_state = true
	emit_signal("got_world_state")
	network_debugger.write_log("Got world state from server")
	network_debugger.write_log(str(players))
	
	player_id = get_tree().get_network_unique_id()	
	_create_world()


func _on_server_timeout():
	_connects_attempted += 1
	if _got_world_state:
		remove_child(_timer)
		_timer.queue_free()
		return # Everything was fine
	
	if _connects_attempted <= CONNECT_ATTEMPTS:
		_client_joined_world() # Just try again
		return