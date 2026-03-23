extends Control

@onready var title: Label = $VBoxContainer/Title
@onready var play_button: Button = $VBoxContainer/PlayButton
@onready var quit_button: Button = $VBoxContainer/QuitButton
@onready var flicker_timer: Timer = $FlickerTimer
@onready var ambient_timer: Timer = $AmbientTimer
@onready var vignette: ColorRect = $VignetteOverlay
@onready var music_player: AudioStreamPlayer = $Music

var target_vignette_alpha: float = 0.0

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	play_button.pressed.connect(_on_play_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	flicker_timer.timeout.connect(_on_flicker)
	ambient_timer.timeout.connect(_on_ambient_event)
	music_player.finished.connect(_on_music_finished)

func _process(delta):
	var current_alpha = vignette.color.a
	vignette.color.a = lerp(current_alpha, target_vignette_alpha, delta * 2.0)
	if target_vignette_alpha > 0:
		target_vignette_alpha = lerp(target_vignette_alpha, 0.0, delta * 0.5)

func _on_play_pressed():
	get_tree().change_scene_to_file("res://Scenes/main_scene.tscn")

func _on_quit_pressed():
	get_tree().quit()

func _on_flicker():
	if randf() < 0.15:
		var intensity = randf_range(0.3, 0.8)
		title.modulate.a = intensity
		await get_tree().create_timer(randf_range(0.05, 0.15)).timeout
		title.modulate.a = 1.0
		if randf() < 0.3:
			await get_tree().create_timer(0.05).timeout
			title.modulate.a = randf_range(0.5, 0.9)
			await get_tree().create_timer(0.05).timeout
			title.modulate.a = 1.0

func _on_ambient_event():
	var event_type = randi() % 2
	match event_type:
		0:
			target_vignette_alpha = randf_range(0.2, 0.4)
		1:
			var offset = randf_range(-3, 3)
			title.position.x += offset
			await get_tree().create_timer(0.1).timeout
			title.position.x -= offset

	ambient_timer.wait_time = randf_range(2.0, 5.0)

func _on_music_finished():
	if music_player:
		music_player.play()
