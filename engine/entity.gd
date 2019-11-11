extends KinematicBody2D

class_name Entity

# ATTRIBUTES
export(String, "ENEMY", "PLAYER", "TRAP") var TYPE: String = "ENEMY"
export(float, 0.5, 20, 0.5) var MAX_HEALTH: float = 1
export(int) var SPEED: int = 70
export(float, 0, 20, 0.5) var DAMAGE: float = 0.5
export(String, FILE) var HURT_SOUND: String = "res://enemies/enemy_hurt.wav"

# MOVEMENT
var movedir: Vector2 = Vector2(0,0)
var knockdir: Vector2 = Vector2(0,0)
var spritedir: String = "Down"
var last_movedir: Vector2 = Vector2(0,1)

# COMBAT
var health: float = MAX_HEALTH
signal health_changed
signal hitstun_end
var hitstun = 0

# NETWORK
puppet var puppet_pos
puppet var puppet_spritedir
puppet var puppet_anim

var state: String = "default"

var home_position: Vector2 = Vector2(0,0)

onready var anim: AnimationPlayer = $AnimationPlayer
onready var sprite: Sprite = $Sprite
var hitbox: Area2D # to be defined by create_hitbox()

onready var camera = get_parent().get_node("Camera")

var texture_default = null
var entity_shader = preload("res://engine/entity.shader")

var room : Room

var game_state # a reference to the game_state, not to be confused with world

func _ready() -> void:
	if has_node("AnimationPlayer"):
		anim = $AnimationPlayer
	texture_default = sprite.texture

	# Create default material if one does not exist...
	if !sprite.material:
		sprite.material = ShaderMaterial.new()
		sprite.material.set_shader(entity_shader)
	
	add_to_group("entity")
	health = MAX_HEALTH
	home_position = position
	create_hitbox()
	
	get_parent().connect("player_entered", self, "player_entered")
	
	room = network.get_room(position)
	room.add_entity(self)
	
	call_deferred("_init_own_state")


func _init_own_state():
	game_state = get_parent().game_state # Save a reference to the game_state. This only works for top level stuff.
	# TODO: Improve the way game_state is set.
	network_debugger.write_log("got state? " + str(game_state.got_state))
	if !game_state: return
	if !game_state.got_state:
		network_debugger.write_log("connecting... ")
		
		game_state.connect("got_state", self, "_get_state", [true])
	else:
		_get_state(false)

func _get_state(should_disconnect_signal: bool):
	network_debugger.write_log("setting state " + str(should_disconnect_signal))
	
	if should_disconnect_signal:
		game_state.disconnect("got_state", self, "_get_state")
	var own_state = game_state.get_value(self.name)
	network_debugger.write_log("got state " + str(own_state))
	
	if own_state:
		set_state(own_state) # Should be defined by Entities that inherit from Entity

func set_state(state: Array):
	pass

func create_hitbox() -> void:
	var new_hitbox = Area2D.new()
	add_child(new_hitbox)
	new_hitbox.name = "Hitbox"
	
	var new_collision = CollisionShape2D.new()
	new_hitbox.add_child(new_collision)
	
	var new_shape = RectangleShape2D.new()
	new_collision.shape = new_shape
	new_shape.extents = $CollisionShape2D.shape.extents + Vector2(1,1)
	
	hitbox = new_hitbox

func loop_network() -> void:
	# Probably don't want to be doing this every tick
	set_network_master(world_state.map_owners[world_state.local_map.name])
	if !world_state.is_map_owner:
		puppet_update()
	if position == Vector2(0,0):
		hide()
	else:
		show()

func puppet_update():
	pass

func is_scene_owner():
	return world_state.is_map_owner

func is_dead() -> bool:
	if health <= 0 && hitstun == 0:
		return true
	return false

func loop_movement() -> void:
	var motion: Vector2
	if hitstun == 0:
		motion = movedir.normalized() * SPEED
	else:
		motion = knockdir.normalized() * 125
	
	# This is optimal, but it doesn't sync players on initial connection.
	# if move_and_slide(motion) != Vector2.ZERO:
	# 	sync_property("puppet_pos", position)
	
	move_and_slide(motion)
	
	sync_property_unreliable("puppet_pos", position)
	
	if movedir != Vector2.ZERO:
		last_movedir = movedir

func loop_spritedir() -> void:
	var old_spritedir: String = spritedir
	
	match movedir:
		Vector2.LEFT:
			spritedir = "Left"
		Vector2.RIGHT:
			spritedir = "Right"
		Vector2.UP:
			spritedir = "Up"
		Vector2.DOWN:
			spritedir = "Down"
	
	if old_spritedir != spritedir:
		sync_property("puppet_spritedir", spritedir)
	
	var flip: bool = spritedir == "Left"
	if sprite.flip_h != flip:
		sprite.flip_h = flip
		
func loop_lightdir():
	var light_rot = 0
	
	match spritedir:
		"Left":
			light_rot = 90
		"Right":
			light_rot = 270
		"Up":
			light_rot = 180
		"Down":
			light_rot = 0
	
	$Light2D.rotation_degrees = light_rot

func loop_damage() -> void:
	sprite.texture = texture_default
	sprite.scale.x = 1
	
	if hitstun > 1:
		hitstun -= 1
		sync_function_unreliable("hurt_texture")
		hurt_texture()
	elif hitstun == 1:
		sync_function("default_texture")
		default_texture()
		emit_signal("hitstun_end")
		hitstun -= 1
	
	for area in hitbox.get_overlapping_areas():
		if area.name != "Hitbox":
			continue
		var body = area.get_parent()
		if !body.get_groups().has("entity") && !body.get_groups().has("item"):
			continue
		if hitstun == 0 && body.get("DAMAGE") > 0 && body.get("TYPE") != TYPE:
			update_health(-body.DAMAGE)
			hitstun = 10
			knockdir = global_position - body.global_position
			sfx.play(load(HURT_SOUND), .85, false)
			
			if body.has_method("hit"):
				for peer in world_state.local_peers:
					body.rpc_id(peer, "hit")
				body.hit()

func update_health(delta: float) -> void:
	health = max(min(health + delta, MAX_HEALTH), 0)
	emit_signal("health_changed")
	
	game_state.set_value(self.name, health)

sync func hurt_texture() -> void:
	sprite.material.set_shader_param("is_hurt", true)

sync func default_texture() -> void:
	sprite.material.set_shader_param("is_hurt", false)

func anim_switch(animation) -> void:
	var newanim: String = str(animation, spritedir)
	if ["Left","Right"].has(spritedir):
		newanim = str(animation, "Side")
	if anim.current_animation != newanim:
		sync_property("puppet_anim", newanim)
		anim.play(newanim)

sync func use_item(item: String, input) -> void:
	var newitem = load(item).instance()
	var itemgroup = str(item, name)
	newitem.add_to_group(itemgroup)
	newitem.add_to_group(name)
	add_child(newitem)
	
	# TODO: is this same as scene master.? .I ..gues.s it works 
	if is_network_master():
		newitem.set_network_master(get_tree().get_network_unique_id())
	
	if get_tree().get_nodes_in_group(itemgroup).size() > newitem.MAX_AMOUNT:
		newitem.delete()
		return
	
	newitem.input = input
	newitem.start()

func choose_subitem(possible_drops: Array, drop_chance: int) -> void:
	randomize()
	var will_drop = randi() % 100 + 1
	if will_drop <= drop_chance:
		var dropped: String = possible_drops[randi() % possible_drops.size()]
		var drop_choice = 0
		match dropped:
			"HEALTH":
				drop_choice = "res://droppables/heart.tscn"
			"RUPEE":
				drop_choice = "res://droppables/rupee.tscn"
		
		if typeof(drop_choice) != TYPE_INT:
			var subitem_name: String  = str(randi()) # we need to sync names to ensure the subitem can rpc to the same thing for others
			world_state.local_map.spawn_subitem(drop_choice, global_position, subitem_name) # has to be from game.gd bc the node might have been freed beforehand
			for peer in world_state.local_peers:
				world_state.local_map.rpc_id(peer, "spawn_subitem", drop_choice, global_position, subitem_name)

func send_chat_message(source, text: String) -> void:
	world_state.local_map.receive_chat_message(source, text)
	rpc("receive_chat_message", source, text)

remote func enemy_death() -> void:
	if world_state.is_map_owner:
		choose_subitem(["HEALTH", "RUPEE"], 100)
	room.remove_entity(self)
	var death_animation = preload("res://enemies/enemy_death.tscn").instance()
	death_animation.global_position = global_position
	get_parent().add_child(death_animation)
	
	set_dead()

remote func set_dead() -> void:
	hide()
	set_physics_process(false)
	set_process(false)
	home_position = Vector2(0,0)
	position = Vector2(0,0)
	health = -1

func rset_map(property: String, value) -> void:
	for peer in world_state.local_peers:
		rset_id(peer, property, value)

func rset_unreliable_map(property: String, value) -> void:
	for peer in world_state.local_peers:
		rset_unreliable_id(peer, property, value)

func sync_function(f):
	for peer in world_state.local_peers:
		rpc_id(peer, f)
		
func sync_function_unreliable(f):
	for peer in world_state.local_peers:
		rpc_unreliable_id(peer, f)
	
func sync_property(property: String, value) -> void:
	if !world_state.is_multiplayer: return
	
	if TYPE == "PLAYER":
		if !is_network_master(): 
			return
	else: 
		if !world_state.is_map_owner:
			return
	rset_map(property, value)

func sync_property_unreliable(property: String, value) -> void:
	if !world_state.is_multiplayer: return

	if TYPE == "PLAYER":
		if !is_network_master(): 
			return
	else: 
		if !world_state.is_map_owner:
			return
	rset_unreliable_map(property, value)

func player_entered(id: int) -> void:
	pass
	if world_state.is_map_owner && is_dead():
		rpc_id(id, "set_dead")
