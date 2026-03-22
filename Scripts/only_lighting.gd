extends Node

@onready var light := $OmniLight3D	

func _ready() -> void:
	pass

func _process(delta: float) -> void:
	if light and light.visible:
		light.light_energy = 1.5 + sin(Time.get_ticks_msec() * 0.005) * 0.3
