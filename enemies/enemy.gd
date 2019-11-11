extends Entity

class_name Enemy

func _ready() -> void:
	add_to_group("enemy")
	set_collision_layer_bit(0, 0)
	set_collision_mask_bit(0, 0)
	set_collision_layer_bit(1, 1)
	set_collision_mask_bit(1, 1)
	
	connect("hitstun_end", self, "check_for_death")

func set_state(state): # state is returned as [state], so var local_state = state[0]
	health = state[0]
	if health <= 0:
		queue_free() # Immediatly remove the enemy
		
func check_for_death() -> void:
	print("checking for death ", health)
	if health == 0 :
		enemy_death()
		for peer in world_state.local_peers:
			rpc_id(peer, "enemy_death")
