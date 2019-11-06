extends Control

onready var logger = $RichLogger

var time_to_log = 4
var timer = 0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	print("debugging...")
	hide()
	call_deferred("_write_to_log")
	get_tree().connect("network_peer_connected", self, "_player_connected")
	get_tree().connect("network_peer_disconnected", self, "_player_disconnected")

func _process(delta: float) -> void:
	timer += delta
	if timer > time_to_log:
		timer = 0
		_write_to_log()

func write_log(message):
	logger.text += "\n>>> MSG: " + str(message) + "\n"

func _write_to_log():
	var new_log = ""
	new_log += "\nMy network ID: " + str(world_state.player_id)	
	new_log += "\nIs Map owner ?: " + str(world_state.is_map_owner)	
	new_log += "\nIs World owner ?: " + str(world_state.is_world_owner)	
	new_log += "\nMy network ID: " + str(world_state.player_id)	
	
	
	new_log += "\nWorld state players:"
	var players = world_state.players
	for p in players:
		new_log += str(p) + ":" + str(world_state.players[p]) + ", "
	
	new_log += "\nWorld state map_owners:"
	var map_owners = world_state.map_owners
	for p in map_owners:
		new_log += str(p) + ":" + str(world_state.map_owners[p]) + ", "
	
	new_log += "\nWorld state local_peers:"
	var local_peers = world_state.local_peers
	for p in local_peers:
		new_log += str(p) + ", "
		
	new_log += "\n==== END OF LOG ====="
	logger.text += new_log
	return

func _player_connected(id):
	var new_log = "\nCONNECTED " + str(id)
	new_log += "\n==== END OF LOG ====="
	logger.text += new_log

func _player_disconnected(id):
	var new_log = "\nDISCONNECTED Player " + str(id)
	new_log += "\n==== END OF LOG ====="
	logger.text += new_log

func _input(event):
	if Input.is_action_just_pressed("TOGGLE_DEBUG"):
		if is_visible_in_tree():
			hide()
		else:
			show()
