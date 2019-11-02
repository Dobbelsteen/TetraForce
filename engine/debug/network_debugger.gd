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
	logger.text += "\n\n>>> MSG: " + str(message) + "\n"

func _write_to_log():
	var new_log = ""
	new_log += "\nMy network ID: " + str(network.current_player_id)	
	new_log += "\nIs network active? " + str(network.is_active)
	
	if network.is_active:
		new_log += "\nCurrent map: " + str(network.current_map.name)
		new_log += "\nIs scene owner? " + str(network.is_scene_owner())
		
		new_log += "\nActive maps:"
		
		var active_maps = network.active_maps
		for p in active_maps:
			new_log += str(p) + ":" + str(active_maps[p]) + ", "
	
		new_log += "\nActive players:"
	
		for p in network.current_players:
			new_log += str(p) + ", "
			
		new_log += "\nActive map peers:"
		
		for p in network.map_peers:
			new_log += str(p) + ", "
			
	new_log += "\nActive map owners:"
	var map_owners = network.map_owners
	for p in map_owners:
		new_log += str(p) + ":" + str(map_owners[p]) + ", "
	
	new_log += "\n==== END OF LOG ====="
	logger.text += new_log

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