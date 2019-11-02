extends Node

var GAMESTATE := 0
var CHECK_1 = 1
var CHECK_2 = 1 << 1
var CHECK_3 = 1 << 2
var CHECK_4 = 1 << 4
var CHECK_5 = 1 << 5
var CHECK_6 = 1 << 6
var CHECK_7 = 1 << 7
var CHECK_8 = 1 << 8
var CHECK_9 = 1 << 63 
"""
We can store up to 64 bits in a single variable. 
This means we can send 64 true/false flages, in a single byte, over the network, in a single int value.
Just think about that for a moment
"""
var ELEM_FIRE = 1
var ELEM_ICE = 1 << 1
var ELEM_ELECTRIC = 1 << 2
var ELEM_WATER = 1 << 3
var weakness_library = ["Basic", "Fire", "Ice", "Electric", "Water"]
export(int, FLAGS, "1", "2", "3", "4", "5", "6", "7", "8", "9", "10") var weakness

var EXAMPLE = CHECK_1 | CHECK_3 | CHECK_5


func _ready():
	weakness = ELEM_ELECTRIC | ELEM_FIRE
	
	print(are_bits_enabled(weakness, [ELEM_ICE, ELEM_ELECTRIC, ELEM_FIRE]))
	
	var mask = ELEM_FIRE
	
	
	if ELEM_ELECTRIC & weakness == ELEM_ELECTRIC:
		print('weak to electric')
	if ELEM_FIRE & weakness == ELEM_FIRE:
		print('weak to fire')
	if weakness & (ELEM_FIRE | ELEM_ELECTRIC):
		print("weak to both")
	if !(weakness & ELEM_WATER):
		print("not weak to water")
		print(~weakness)
		print(weakness)


func is_bit_enabled(mask, index):
    return mask & (1 << index) != 0

func enable_bit(mask, index):
    return mask | (1 << index)

func disable_bit(mask, index):
    return mask & ~(1 << index)

func are_bits_enabled(mask, indexes: Array):
	var compare_mask = 0
	for index in indexes:
			compare_mask = compare_mask | index
	return compare_mask & mask == compare_mask


export var server_timeout = 5 # Max time to wait for server to respond, after that, we're the server now

var owner_server_id = 1 # should get this value from network autoload script
var my_server_id = 123123132 # should get this value from network too

var original_state = {}
var updated_state = {}

var _timer # Timer object reference to keep track of server timeout
var _got_state = false # whether a client got the state of the server yet or not

signal got_state

func entered_new_scene_as_owner():
	_prepare_data()
	# Connect self to stuff
	#keep track of ALL scene changes
	pass


func left_scene_as_owner():
	# Assign new master chosen from peers (next in line), but send it to all peers.
	# If the new owner is already gone, the next in line attempts to become the owner, and so on
	pass

func _prepare_data(): # Called on _ready
	pass
	#precache dictionary, encode keys (if we make em variable)


remote func _send_state(client_id):
	rpc_id(client_id, "_get_state", updated_state)


remote func _get_state(state):
	updated_state = state
	_got_state = true
	emit_signal("state_updated")


func client_joined_scene():
	# Fadein should be started, and wait
	connect("got_state", self, "got_state")
	rpc_id(owner_server_id, "_send_state", my_server_id)
	
	_timer = Timer.new()
	_timer.set_wait_time(server_timeout)
	_timer.set_one_shot(true)
	_timer.connect("timeout",self,"_on_server_timeout") 
	add_child(_timer)
	_timer.start()

func _on_server_timeout():
	if _got_state:
		return # Everything was fine
	_assign_new_owner(my_server_id)
	# If we get here, the server timed out. We are the server now? So we keep track of the changes from now on.


func _assign_new_owner(new_server_id):
	pass # do stuff
	
