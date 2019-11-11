extends Camera2D

const SCROLL_SPEED: float = 0.5

var target: Node
var target_grid_pos: Vector2 = Vector2(0,0)
var last_target_grid_pos: Vector2 = Vector2(0,0)
var camera_rect: Rect2 = Rect2()

var current_lighting: String = ""

signal screen_change
signal screen_change_started
signal screen_change_completed
signal lighting_mode_changed

var player_cam

func _ready() -> void:
	set_process(false)

func initialize(node: Node) -> void:
	target = node
	position = global.get_grid_pos(target.position) * global.SCREEN_SIZE
	$Tween.connect("tween_started", self, "screen_change_started")
	$Tween.connect("tween_completed", self, "screen_change_completed")
	current = true
	
	set_process(true)
	update_lighting(global.get_grid_pos(target.position))

func _process(delta: float) -> void: # TODO: Probably don't have to do this in process
	if !is_instance_valid(target):
		return
		
	if player_cam:
		return # Player cam is taking care of it
		
	target_grid_pos = global.get_grid_pos(target.position)
	
	camera_rect = Rect2(position, global.SCREEN_SIZE)
	
	if $Tween.is_active():
		emit_signal("screen_change")
	
	if !$Tween.is_active() && !camera_rect.has_point(target.position):
		scroll_camera()
	
	last_target_grid_pos = target_grid_pos

func scroll_camera() -> void:
	$Tween.interpolate_property(self, "position", last_target_grid_pos * global.SCREEN_SIZE, target_grid_pos * global.SCREEN_SIZE, SCROLL_SPEED, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
	$Tween.start()
	
	update_lighting(target_grid_pos)
	
func update_lighting(target_grid_pos: Vector2) -> void:
	var grid_pos: Vector2 = global.get_grid_pos(target.position)
	var node_name: String = "room%s%s" % [grid_pos.x, grid_pos.y]
	
	var node: Node = get_parent().get_node_or_null(node_name)
	
	if node == null:
		return
	
	var light_data = node.get_meta("light_data")
	if current_lighting == light_data:
		return
	
	var targetColor: Color = Color(0, 0, 0, 1.0)
	var targetEnergy = 1
	var delay: float = 0.0
	
	if current_lighting == "dark":
		delay = 0.3
		
	if light_data == "dark":
		targetColor = Color(0, 0, 0, 1.0)
	elif light_data == "dusk":
		targetColor = Color(0.1, 0.0, 0.5, 1.0)
	elif light_data == "dawn":
		targetColor = Color(0.98, 0.482, 0.384, 1.0)
	else:
		targetColor = Color(1.0, 1.0, 1.0, 1.0)
		light_data = "day"
		targetEnergy = 0
		 
	$ModulateTween.interpolate_property($CanvasModulate, "color", $CanvasModulate.color, targetColor, 0.2, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT, delay)
	$ModulateTween.start()
	
	current_lighting = light_data
		  
	emit_signal("lighting_mode_changed", targetEnergy)

func screen_change_started(object, nodepath: String) -> void:
	emit_signal("screen_change_started")

func screen_change_completed(object, nodepath: String) -> void:
	emit_signal("screen_change_completed")

# Attach a predefined personal camera to the target (being the current player, or so it should be)
func unlock_camera(limits):
	if !limits:
		return # Just in case
	if $Tween.is_active():
		# Wait for current tween to complete before unlocking camera to avoid (almost all) spazzing
		yield($Tween, "tween_completed")

	# Create and configure new camera to attach to the player
	player_cam = Camera2D.new()
	player_cam.current = true # Make camera active
	# Make it snappy, the camera that is
	player_cam.drag_margin_h_enabled = false 
	player_cam.drag_margin_v_enabled = false
	player_cam.limit_left = limits.left
	player_cam.limit_top = limits.top
	player_cam.limit_right = limits.right
	player_cam.limit_bottom = limits.bottom

	target.add_child(player_cam)

# Put camera back in default position, locked to a screen
func lock_camera():
	make_current()
	target.remove_child(player_cam)
	player_cam.queue_free()
	player_cam = null
