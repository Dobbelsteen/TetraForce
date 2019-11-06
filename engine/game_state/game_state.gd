extends Node

const SERVER_TIMEOUT = 1 # Max time to wait for server to respond
const CONNECT_ATTEMPTS = 3 # Max amount of tries to get game state before taking over map
var _connects_attempted = 0

var owner_id = 1 # should get this value from network autoload script

var original_state = {}
var updated_state = {}

var _timer # Timer object reference to keep track of server timeout
var got_state = false # whether a client got the state of the server yet or not

signal got_state
signal set_game_state(key, value)
signal get_game_state(key, value)

func _ready() -> void:
	call_deferred("_prepare") # Wait 1 tick to make sure data is properly set on world_state

func set_value(key: String, value):
	if !updated_state.has(key) || updated_state[key] != value: 
		updated_state[key] = value
		return # TODO: Check how we want to handle this crap. Whether we send it over network or not
		# Notify others of the change
		if world_state.player_id == 1:
			rpc('_remote_set_value', key, value)
		else:
			for player in world_state.players:
				if player != world_state.player_id:
					rpc_id(player, '_remote_set_value', key, value)
	
func get_value(key: String):
	# Wait until we get the world state values
	if !got_state:
		return null
	#	yield(self, "got_state")
	
	if updated_state.has(key):
		return [updated_state[key]] # Return as array to differentiate from 0 when 0 is the state value
	else:
		return null
	pass

func _prepare() -> void:
	if world_state.is_map_owner || !world_state.is_multiplayer:
		_owner_joined_scene()
	else:
		_client_joined_scene()


func _owner_joined_scene():
	owner_id = world_state.player_id
	_prepare_data()
	# Connect self to stuff
	#keep track of ALL scene changes
	got_state = true
	emit_signal("got_state")
	network_debugger.write_log("Initialized state as scene owner")


func _prepare_data(): # Called on _ready
	pass # Do eventual caching/encoding for optimalizations, for now, does nothing as we just return data as is


remote func _send_state_to_peer():
	network_debugger.write_log("Sending state to new player...")
	# We can get the sender id from this handy method, instead of sending it along again
	rpc_id(get_tree().get_rpc_sender_id(), "_get_state_from_owner", updated_state)

remote func _get_state_from_owner(state):
	updated_state = state
	got_state = true
	emit_signal("got_state")
	network_debugger.write_log("game_state=" + str(state))

func _client_joined_scene():
	owner_id = world_state.get_local_map_owner()
	network_debugger.write_log("Asking state from " + str(owner_id))
	
	rpc_id(owner_id, "_send_state_to_peer")
	_timer = Timer.new()
	_timer.set_wait_time(SERVER_TIMEOUT)
	_timer.set_one_shot(true)
	_timer.connect("timeout", self, "_on_server_timeout") 
	add_child(_timer)
	_timer.start()


func _on_server_timeout():
	_connects_attempted += 1
	if got_state:
		remove_child(_timer)
		_timer.queue_free()
		return # Everything was fine
	
	if _connects_attempted <= CONNECT_ATTEMPTS:
		_client_joined_scene() # Just try again
		return
	# If we get here, the server timed out. We are the server now? So we keep track of the changes from now on.
	# Or, if there's other peers, the second in line becomes owner
	_timer.queue_free()
	world_state.announce_map_change(world_state.local_map.name)
	# TODO: Proper handling of ownership change on timeout..
	#_assign_new_owner(world_state.player_id)
	#for peer in network.map_peers:
	#	rpc_id(peer, "_assign_new_owner", world_state.player_id)
