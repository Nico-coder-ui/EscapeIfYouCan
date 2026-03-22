extends Camera3D

@export var mouse_sensitivity := 0.3
@export var pitch_min := -80.0
@export var pitch_max := 80.0

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event):
	if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		return

	if event is InputEventMouseMotion:
		get_parent().rotate_y(deg_to_rad(-event.relative.x * mouse_sensitivity))

		rotation.x -= deg_to_rad(event.relative.y * mouse_sensitivity)
		rotation.x = clamp(rotation.x, deg_to_rad(pitch_min), deg_to_rad(pitch_max))
