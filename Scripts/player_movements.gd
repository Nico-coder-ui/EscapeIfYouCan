extends CharacterBody3D

@export var speed := 5.0
@export var gravity := 9.8

@onready var anim := $AnimationPlayer
@onready var camera := $Camera3D

func _physics_process(delta):
	# Gravité
	if not is_on_floor():
		velocity.y -= gravity * delta

	var direction := Vector3.ZERO
	var cam_basis: Basis = camera.global_transform.basis

	if Input.is_action_pressed("move_forward"):
		direction -= cam_basis.z
	if Input.is_action_pressed("move_back"):
		direction += cam_basis.z
	if Input.is_action_pressed("move_left"):
		direction -= cam_basis.x
	if Input.is_action_pressed("move_right"):
		direction += cam_basis.x

	direction.y = 0
	direction = direction.normalized()

	if direction != Vector3.ZERO:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		if anim.current_animation != "Walk":
			anim.play("Walk")
	else:
		velocity.x = 0
		velocity.z = 0
		if anim.current_animation != "":
			anim.play("RESET")

	move_and_slide()
