extends Node

const SERVER_TIMEOUT = 1 # Max time to wait for server to respond
const CONNECT_ATTEMPTS = 3 # Max amount of tries to get game state before taking over map
var _connects_attempted = 0

var owner_id = 1 # should get this value from network autoload script

var original_state = {}
var updated_state = {}

var _timer # Timer object reference to keep track of server timeout
var _got_state = false # whether a client got the state of the server yet or not

signal got_state

func _ready() -> void:
	call_deferred("_prepare")


func _prepare() -> void:
	network_debugger.write_log("Is network active ?" + str(network.is_active))
	
	if network.is_scene_owner():
		entered_new_scene_as_owner()
	else:
		client_joined_scene()


func entered_new_scene_as_owner():
	owner_id = network.current_player_id
	_prepare_data()
	# Connect self to stuff
	#keep track of ALL scene changes
	_got_state = true
	emit_signal("got_state")
	network_debugger.write_log("Initialized state as scene owner")


func _prepare_data(): # Called on _ready
	pass # Do eventual caching/encoding for optimalizations, for now, does nothing as we just return data as is


func left_scene_as_owner():
	# Assign new master chosen from peers (next in line), but send it to all peers.
	# If the new owner is already gone, the next in line attempts to become the owner, and so on
	var peers = network.map_peers
	if peers.count() > 0:
		var new_owner_id = peers[0]
		
		for peer in peers:
			rpc_id(peer, "_assign_new_owner", new_owner_id)
	pass
	
	# NOTE: Assuming we get these values properly from network, we shouldn't even have to do this call.


remote func _send_state_to_peer():
	# We can get the sender id from this handy method, instead of sending it along again
	rpc_id(get_tree().get_rpc_sender_id(), "_get_state_from_owner", updated_state)


remote func _get_state_from_owner(state):
	updated_state = state
	_got_state = true
	emit_signal("got_state")
	network_debugger.write_log("Got state from scene owner")
	


func client_joined_scene():
	owner_id = network.get_current_map_owner()
	# Fadein should be started, and wait
	rpc_id(owner_id, "_send_state_to_peer")
	
	_timer = Timer.new()
	_timer.set_wait_time(SERVER_TIMEOUT)
	_timer.set_one_shot(true)
	_timer.connect("timeout", self, "_on_server_timeout") 
	add_child(_timer)
	_timer.start()


func _on_server_timeout():
	_connects_attempted += 1
	if _got_state:
		remove_child(_timer)
		_timer.queue_free()
		return # Everything was fine
	
	if _connects_attempted <= CONNECT_ATTEMPTS:
		client_joined_scene() # Just try again
		return
	# If we get here, the server timed out. We are the server now? So we keep track of the changes from now on.
	# Or, if there's other peers, the second in line becomes owner
	_timer.queue_free()
	_assign_new_owner(network.current_player_id)
	for peer in network.map_peers:
		rpc_id(peer, "_assign_new_owner", network.current_player_id)


remote func _assign_new_owner(new_owner_id):
	owner_id = new_owner_id 
