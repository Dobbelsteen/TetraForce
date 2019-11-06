extends Node2D

class_name Item

var TYPE = null
var input = null

export(float, 0, 20, 0.5) var DAMAGE = 0.5
export(int, 1, 20) var MAX_AMOUNT = 1
export(bool) var delete_on_hit = false

func _ready():
	TYPE = get_parent().TYPE
	add_to_group("item")
	set_physics_process(false)

remote func hit():
	if delete_on_hit:
		delete()
		for peer in world_state.local_peers:
			rpc_id(peer, "delete")

remote func delete():
	queue_free()
