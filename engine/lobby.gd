
extends Control

const DEFAULT_PORT: int = 4564 # some random number, pick your port properly
const MAX_PEERS: int = 15 # Maximum amount of players

var map: String = "res://maps/overworld.tmx"
onready var host = settings.get_pref("host_address")

#### Network callbacks from SceneTree ####
func create_level() -> void:
	network.initialize()
	var level = load(map).instance()
	get_tree().get_root().add_child(level)
	music.play(preload("res://music/Overworldmaybe.ogg"))
	hide()

# callback from SceneTree
func _player_connected(id: int):
	return
	#someone connected, start the game!
	create_level()
	hide()

# callback from SceneTree, only for clients (not server)
func _connected_ok() -> void:
	create_level()
	world_state.disconnect("got_world_state", self, "_connected_ok")	
	
# callback from SceneTree, only for clients (not server)	
func _connected_fail() -> void:
	_set_status("Couldn't connect",false)
	
	get_tree().set_network_peer(null) #remove peer
	
	get_node("panel/join").set_disabled(false)
	get_node("panel/host").set_disabled(false)

func _server_disconnected() -> void:
	_end_game("Server disconnected")
	
##### Game creation functions ######

func _end_game(with_error: String = "") -> void:
	 # TODO: Move clear() to world state maybe
	network.clear() # handle clearing out the network immediately (this is why we connected deferred above)
	show()
	
	get_tree().set_network_peer(null) #remove peer
	
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	get_node("panel/join").set_disabled(false)
	get_node("panel/host").set_disabled(false)
	
	_set_status(with_error, false)

func _set_status(text: String, isok: bool) -> void:
	#simple way to show status		
	if (isok):
		get_node("panel/status_ok").set_text(text)
		get_node("panel/status_fail").set_text("")
	else:
		get_node("panel/status_ok").set_text("")
		get_node("panel/status_fail").set_text(text)

func check_host_address(ip: String) -> String:
	if ip.length() == 0:
		ip = settings.default_host
	
	if (not ip.is_valid_ip_address()):
		_set_status("IP address is invalid", false)
		return ""
	
	settings.set_pref("host_address", ip)
	
	return ip

func _on_host_pressed() -> void:
	network.my_player_data.name = $characterselect.player_name
	
	var ip: String = get_node("panel/address").get_text()
	
	if ip.length() == 0:
		ip = settings.default_host
	
	var host: NetworkedMultiplayerENet = NetworkedMultiplayerENet.new()
	var err: int = host.create_server(DEFAULT_PORT, MAX_PEERS) # max: 1 peer, since it's a 2 players game
	if (err != OK):
		#is another server running?
		_set_status("Can't host, address in use.", false)
		return
	
	get_tree().set_network_peer(host)
	get_node("panel/join").set_disabled(true)
	get_node("panel/host").set_disabled(true)
	
	world_state.prepare_world_state(true)
	call_deferred("hide")

func _on_join_pressed() -> void:
	network.my_player_data.name = $characterselect.player_name
	
	var ip: String = check_host_address(get_node("panel/address").get_text())
	
	if ip == null:
		return
	
	get_node("panel/join").set_disabled(true)
	get_node("panel/host").set_disabled(true)
	
	#connect("client_connected_to_server", self, "_connected_ok")
	# Once we get the world state, we can create the actual level.
	world_state.connect("got_world_state", self, "_connected_ok")
	
	var host: NetworkedMultiplayerENet = NetworkedMultiplayerENet.new()
	host.set_compression_mode(NetworkedMultiplayerENet.COMPRESS_RANGE_CODER)
	host.create_client(ip, DEFAULT_PORT)
	get_tree().set_network_peer(host)
	
	world_state.prepare_world_state(false)
	
	_set_status("Connecting...",true)
	
### INITIALIZER ####
	
func _ready() -> void:
	$panel.grab_focus()
	
	$panel/address.text = host
	
	# connect all the callbacks related to networking
	# get_tree().connect("network_peer_connected",self,"_player_connected")
	get_tree().connect("connection_failed",self,"_connected_fail")
	get_tree().connect("server_disconnected",self,"_server_disconnected")
	
	get_tree().set_auto_accept_quit(false)
	
func _notification(n: int) -> void:
	if (n == MainLoop.NOTIFICATION_WM_QUIT_REQUEST):
		get_tree().set_network_peer(null)
		get_tree().quit()
