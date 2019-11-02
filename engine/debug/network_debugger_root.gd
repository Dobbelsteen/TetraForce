extends CanvasLayer

onready var network_debugger = $NetworkDebugger

func force_write_to_log():
	network_debugger._write_to_log()
func write_log(message):
	network_debugger.write_log(message)