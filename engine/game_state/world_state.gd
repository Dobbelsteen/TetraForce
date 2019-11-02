extends Node

const SERVER_TIMEOUT = 2 # Max time to wait for server to respond
const CONNECT_ATTEMPTS = 10 # Max amount of tries to get game state before taking over map
var _connects_attempted = 0

var owner_id = 1 # The host has absolute authority over the world state

var original_state = {}
var updated_state = {}

var _timer # Timer object reference to keep track of server timeout
var _got_world_state = false # whether a client got the state of the server yet or not

signal got_world_state


func prepare_world_state() -> void:
	if network.current_player_id == 1:
		entered_world_as_owner()
	else:
		client_joined_world()


func entered_world_as_owner():
	_prepare_data()
	# Connect self to stuff
	#keep track of ALL scene changes
	_got_world_state = true
	emit_signal("got_world_state")
	network_debugger.write_log("Initialized world as world owner")


func _prepare_data(): # Called on _ready
	pass # Do eventual caching/encoding for optimalizations, for now, does nothing as we just return data as is


remote func _send_world_state_to_peer():
	# We can get the sender id from this handy method, instead of sending it along again
	network_debugger.write_log("Sending world state to " + str(get_tree().get_rpc_sender_id()))
	rpc_id(get_tree().get_rpc_sender_id(), "_get_world_state_from_owner", updated_state)


remote func _get_world_state_from_owner(state):
	updated_state = state
	_got_world_state = true
	emit_signal("got_world_state")
	network_debugger.write_log("Got world state from server")


func client_joined_world():
	# Fadein should be started, and wait
	rpc_id(1, "_send_world_state_to_peer")
	
	_timer = Timer.new()
	_timer.set_wait_time(SERVER_TIMEOUT)
	_timer.set_one_shot(true)
	_timer.connect("timeout", self, "_on_server_timeout") 
	add_child(_timer)
	_timer.start()


func _on_server_timeout():
	_connects_attempted += 1
	if _got_world_state:
		remove_child(_timer)
		_timer.queue_free()
		return # Everything was fine
	
	if _connects_attempted <= CONNECT_ATTEMPTS:
		client_joined_world() # Just try again
		return
