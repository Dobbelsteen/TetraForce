extends Node

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

var rooms = {} #{Vector2: Room}

func _ready():
	set_process(false)

func initialize():
	if world_state.is_world_owner:
		player_data[1] = my_player_data
	# Store this value for easier access later
	current_player_id = world_state.player_id
	#if !get_tree().is_network_server():
	if world_state.player_id != 1:
		rpc_id(1, "_receive_my_player_data", my_player_data)


func get_current_map_owner():
	return world_state.map_owners[world_state.current_map.name]

func is_scene_owner():
	return world_state.is_map_owner

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

	
func clear(): # TODO: Move this to world state maybe, or at least the call to it
	if is_instance_valid(world_state.local_map):
		world_state.local_map.free()

	active_maps.clear()
	current_players.clear()
	map_owners.clear()
	map_peers.clear()
	player_data.clear()

remote func _receive_all_player_data(received_player_data):
	player_data = received_player_data


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


func get_room_screen(pos: Vector2) -> Vector2:
	return Vector2(floor(pos.x / 16 / 16), floor(pos.y / 9 / 16))

func get_room(pos) -> Room :
	var screen = get_room_screen(pos)
	if rooms.has(screen) :
		return rooms[screen]

	else :
		# create room
		var r = Room.new()
		r.tile_rect.position = screen * Vector2(16, 9)

		r.connect("player_entered", self, "_on_room_player_entered", [r])
		r.connect("player_exited", self, "_on_room_player_exited", [r])
		r.connect("enemies_defeated", self, "_on_room_enemies_defeated", [r])
		r.connect("empty", self, "_on_room_empty", [r])

		rooms[screen] = r
		return r

func _on_room_player_entered(room):
	print(room, "player_entered")

func _on_room_player_exited(room):
	print(room, "player_exited")

func _on_room_enemies_defeated(room):
	print(room, "enemies_defeated")

func _on_room_empty(room):
	# free the room once it's clear
	print(room.get_class())
	rooms.erase(room)