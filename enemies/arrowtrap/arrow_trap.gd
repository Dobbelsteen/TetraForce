extends Entity

export (float) var timer: float = 3
export (String) var direction: String
var shoot_timer: int = 0

func _init() -> void:
	TYPE = "TRAP"

func _ready() -> void:
	shoot_timer = timer
	spritedir = direction
	if ["Left", "Up", "Right", "Down"].has(spritedir):
		$AnimatedSprite.set_animation(spritedir.to_lower())
	hitbox.queue_free()

func _physics_process(delta: float) -> void:
	if !world_state.is_map_owner:
		return
	
	if shoot_timer >= 0:
		shoot_timer -= delta
	else:
		use_item("res://items/arrow.tscn", "A")
		for peer in world_state.local_peers:
			rpc_id(peer, "use_item", "res://items/arrow.tscn", "A")
		shoot_timer = timer
