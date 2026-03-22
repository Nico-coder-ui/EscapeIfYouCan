extends Node

var step_counter: int = 0

var intro_text: String = "Texte d'introduction - Le début de l'histoire..."

var outro_text: String = "Texte de fin - Vous avez réussi à résoudre toutes les énigmes..."

var possible_riddles: Array[Dictionary] = [
	{"text": "Énigme 1 - Je suis toujours devant vous mais ne peut jamais être vu. Que suis-je ?", "password": "avenir"},
	{"text": "Énigme 2 - Plus je sèche, plus je suis mouillée. Que suis-je ?", "password": "serviette"},
	{"text": "Énigme 3 - J'ai des villes, mais pas de maisons. J'ai des forêts, mais pas d'arbres. J'ai de l'eau, mais pas de poissons. Que suis-je ?", "password": "carte"},
	{"text": "Énigme 4 - Je peux être craqué, fait, dit et joué. Que suis-je ?", "password": "blague"},
	{"text": "Énigme 5 - Je n'ai pas de vie, mais je peux mourir. Que suis-je ?", "password": "pile"},
]

var selected_riddles: Array[Dictionary] = []

const RIDDLES_COUNT: int = 5

var is_showing_outro: bool = false

var possible_page_positions: Array[Vector3] = [
	Vector3(-3.26, 4.79, -5.1),
	Vector3(-0.937, 4.896, -9.536),
	Vector3(0.151, 3.748, -9.938),
	Vector3(2.363, 3.764, -10.195),
	Vector3(-0.072, 3.737, -4.616),
]

const PAGES_COUNT: int = 5
const PAGE_ROTATION_Y: float = PI / 2.0
const PAGE_SCALE: Vector3 = Vector3(2, 2, 2)

var player: CharacterBody3D
var camera: Camera3D
var raycast: RayCast3D
var book_node: Node3D
var pages: Array[Node3D] = []

var ui_layer: CanvasLayer
var interaction_indicator: TextureRect
var text_overlay: ColorRect
var text_label: Label
var is_text_displayed: bool = false

var input_field: LineEdit
var validate_button: Button
var input_container: HBoxContainer
var error_label: Label

var pause_menu: ColorRect
var is_paused: bool = false

var current_target: Node3D = null

@export var interaction_distance: float = 2.5

const INTERACTION_LAYER: int = 2

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_select_riddles()
	_setup_references()
	_setup_ui()
	_setup_pause_menu()
	_setup_book()
	_spawn_pages()
	_update_interactables()

func _select_riddles():
	var shuffled = possible_riddles.duplicate()
	shuffled.shuffle()
	var count = mini(RIDDLES_COUNT, shuffled.size())
	for i in range(count):
		selected_riddles.append(shuffled[i])

func _setup_references():
	player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	if player:
		camera = player.get_node_or_null("Camera3D")
	else:
		var char = get_parent().get_node_or_null("CharacterBody3D")
		if char:
			player = char
			camera = char.get_node_or_null("Camera3D")

	if not camera:
		return

	raycast = RayCast3D.new()
	raycast.name = "InteractionRaycast"
	raycast.target_position = Vector3(0, 0, -interaction_distance)
	raycast.enabled = true
	raycast.collision_mask = 1 << (INTERACTION_LAYER - 1)
	raycast.collide_with_areas = false
	raycast.collide_with_bodies = true
	camera.add_child(raycast)

func _setup_ui():
	ui_layer = CanvasLayer.new()
	ui_layer.name = "GameUI"
	ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(ui_layer)

	interaction_indicator = TextureRect.new()
	interaction_indicator.name = "InteractionIndicator"
	interaction_indicator.texture = load("res://Assets/InterationIndicator.png")
	interaction_indicator.visible = false
	interaction_indicator.anchor_left = 0.5
	interaction_indicator.anchor_right = 0.5
	interaction_indicator.anchor_top = 0.5
	interaction_indicator.anchor_bottom = 0.5
	interaction_indicator.offset_left = -32
	interaction_indicator.offset_right = 32
	interaction_indicator.offset_top = 20
	interaction_indicator.offset_bottom = 84
	ui_layer.add_child(interaction_indicator)

	text_overlay = ColorRect.new()
	text_overlay.name = "TextOverlay"
	text_overlay.color = Color(0, 0, 0, 0.85)
	text_overlay.visible = false
	text_overlay.anchor_right = 1.0
	text_overlay.anchor_bottom = 1.0
	ui_layer.add_child(text_overlay)

	text_label = Label.new()
	text_label.name = "TextLabel"
	text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text_label.anchor_left = 0.1
	text_label.anchor_right = 0.9
	text_label.anchor_top = 0.2
	text_label.anchor_bottom = 0.6
	text_label.offset_left = 0
	text_label.offset_right = 0
	text_label.offset_top = 0
	text_label.offset_bottom = 0
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.add_theme_font_size_override("font_size", 32)
	text_label.add_theme_color_override("font_color", Color.WHITE)
	text_overlay.add_child(text_label)

	input_container = HBoxContainer.new()
	input_container.anchor_left = 0.3
	input_container.anchor_right = 0.7
	input_container.anchor_top = 0.75
	input_container.anchor_bottom = 0.85
	input_container.add_theme_constant_override("separation", 20)
	text_overlay.add_child(input_container)

	input_field = LineEdit.new()
	input_field.placeholder_text = "Entrez le mot..."
	input_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input_field.add_theme_font_size_override("font_size", 24)
	input_field.text_submitted.connect(_on_password_submitted)
	input_container.add_child(input_field)

	validate_button = Button.new()
	validate_button.text = "VALIDER"
	validate_button.custom_minimum_size = Vector2(120, 0)
	validate_button.add_theme_font_size_override("font_size", 20)
	validate_button.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 1))
	validate_button.add_theme_color_override("font_hover_color", Color(0.9, 0.2, 0.2, 1))
	validate_button.add_theme_color_override("font_pressed_color", Color(1, 0.3, 0.3, 1))
	validate_button.pressed.connect(_on_validate_pressed)
	input_container.add_child(validate_button)

	error_label = Label.new()
	error_label.text = "LE MONSTRE SE RAPPROCHE..."
	error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	error_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	error_label.anchor_left = 0.0
	error_label.anchor_right = 1.0
	error_label.anchor_top = 0.4
	error_label.anchor_bottom = 0.6
	error_label.add_theme_font_size_override("font_size", 64)
	error_label.add_theme_color_override("font_color", Color(0.8, 0.1, 0.1, 1))
	error_label.add_theme_color_override("font_shadow_color", Color(0.3, 0, 0, 0.8))
	error_label.add_theme_constant_override("shadow_offset_x", 3)
	error_label.add_theme_constant_override("shadow_offset_y", 3)
	error_label.visible = false
	ui_layer.add_child(error_label)

func _setup_pause_menu():
	pause_menu = ColorRect.new()
	pause_menu.name = "PauseMenu"
	pause_menu.color = Color(0.02, 0.02, 0.05, 0.95)
	pause_menu.visible = false
	pause_menu.anchor_right = 1.0
	pause_menu.anchor_bottom = 1.0
	ui_layer.add_child(pause_menu)

	var vbox = VBoxContainer.new()
	vbox.anchor_left = 0.5
	vbox.anchor_right = 0.5
	vbox.anchor_top = 0.5
	vbox.anchor_bottom = 0.5
	vbox.offset_left = -150
	vbox.offset_right = 150
	vbox.offset_top = -120
	vbox.offset_bottom = 120
	vbox.add_theme_constant_override("separation", 25)
	pause_menu.add_child(vbox)

	var title = Label.new()
	title.text = "PAUSE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(0.7, 0.1, 0.1, 1))
	title.add_theme_color_override("font_shadow_color", Color(0.3, 0, 0, 0.8))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 2)
	vbox.add_child(title)

	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 30)
	vbox.add_child(spacer)

	var continue_btn = Button.new()
	continue_btn.text = "CONTINUER"
	continue_btn.custom_minimum_size = Vector2(250, 50)
	continue_btn.flat = true
	continue_btn.add_theme_font_size_override("font_size", 24)
	continue_btn.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 1))
	continue_btn.add_theme_color_override("font_hover_color", Color(0.9, 0.2, 0.2, 1))
	continue_btn.add_theme_color_override("font_pressed_color", Color(1, 0.3, 0.3, 1))
	continue_btn.pressed.connect(_on_continue_pressed)
	vbox.add_child(continue_btn)

	var quit_btn = Button.new()
	quit_btn.text = "QUITTER"
	quit_btn.custom_minimum_size = Vector2(250, 50)
	quit_btn.flat = true
	quit_btn.add_theme_font_size_override("font_size", 24)
	quit_btn.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 1))
	quit_btn.add_theme_color_override("font_hover_color", Color(0.9, 0.2, 0.2, 1))
	quit_btn.add_theme_color_override("font_pressed_color", Color(1, 0.3, 0.3, 1))
	quit_btn.pressed.connect(_on_quit_pressed)
	vbox.add_child(quit_btn)

func _setup_book():
	var neighborhood = get_parent().get_node_or_null("neighborhood")
	if neighborhood:
		book_node = neighborhood.get_node_or_null("Bookglb")
		if book_node:
			book_node.add_to_group("interactable")
			book_node.add_to_group("book")
			_add_collision_to_object(book_node, Vector3(0.8, 1.2, 0.6), Vector3(0, 0.5, 0))

func _spawn_pages():
	var page_scene = load("res://Assets/PaperPage.glb")
	if not page_scene:
		return

	var shuffled_positions = possible_page_positions.duplicate()
	shuffled_positions.shuffle()

	var count = mini(PAGES_COUNT, shuffled_positions.size())
	for i in range(count):
		var page = page_scene.instantiate()
		page.name = "Page_" + str(i + 1)
		page.position = shuffled_positions[i]
		page.rotation.y = PAGE_ROTATION_Y
		page.scale = PAGE_SCALE
		page.add_to_group("interactable")
		page.add_to_group("page")
		page.visible = false
		get_parent().add_child(page)
		pages.append(page)
		_add_collision_to_object(page, Vector3(0.3, 0.05, 0.4))

func _add_collision_to_object(node: Node3D, box_size: Vector3, offset: Vector3 = Vector3.ZERO):
	var static_body = StaticBody3D.new()
	static_body.name = "InteractionBody"
	static_body.collision_layer = 1 << (INTERACTION_LAYER - 1)
	static_body.collision_mask = 0
	static_body.position = offset

	var collision = CollisionShape3D.new()
	collision.name = "CollisionShape"
	var shape = BoxShape3D.new()
	shape.size = box_size
	collision.shape = shape

	static_body.add_child(collision)
	node.add_child(static_body)

func _update_interactables():
	if book_node:
		book_node.visible = true

	for i in range(pages.size()):
		if pages[i] != null:
			var page_step = (i * 2) + 1
			pages[i].visible = (step_counter == page_step)

func _process(_delta):
	if is_text_displayed or is_paused:
		return
	_check_interaction_target()

func _check_interaction_target():
	if not raycast:
		return

	raycast.force_raycast_update()

	if raycast.is_colliding():
		var collider = raycast.get_collider()
		var target = _find_interactable_parent(collider)

		if target and _can_interact_with(target):
			current_target = target
			interaction_indicator.visible = true
		else:
			current_target = null
			interaction_indicator.visible = false
	else:
		current_target = null
		interaction_indicator.visible = false

func _find_interactable_parent(node: Node) -> Node3D:
	var current = node
	while current:
		if current.is_in_group("interactable"):
			return current as Node3D
		current = current.get_parent()
	return null

func _can_interact_with(target: Node3D) -> bool:
	if step_counter % 2 == 0:
		return target.is_in_group("book")
	else:
		if target.is_in_group("page"):
			var page_index = (step_counter - 1) / 2
			if page_index < pages.size() and pages[page_index] != null:
				return pages[page_index] == target
	return false

func _input(event):
	if is_text_displayed and event.is_action_pressed("ui_cancel"):
		if is_showing_outro:
			_close_outro()
		elif step_counter == 0:
			_close_text_success()
		else:
			_close_text_cancel()
		return

	if not is_text_displayed and event.is_action_pressed("ui_cancel"):
		if is_paused:
			_resume_game()
		else:
			_pause_game()
		return

	if event.is_action_pressed("interaction") and current_target and not is_text_displayed and not is_paused:
		_interact_with_target()

func _close_outro():
	text_overlay.visible = false
	is_text_displayed = false
	is_showing_outro = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	step_counter += 1
	_game_completed()

func _pause_game():
	is_paused = true
	get_tree().paused = true
	pause_menu.visible = true
	interaction_indicator.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _resume_game():
	is_paused = false
	get_tree().paused = false
	pause_menu.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _on_continue_pressed():
	_resume_game()

func _on_quit_pressed():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")

func _interact_with_target():
	if current_target.is_in_group("book"):
		_interact_book()
	elif current_target.is_in_group("page"):
		_interact_page()

func _interact_book():
	if step_counter == 0:
		_show_text(intro_text)
	else:
		var riddle_index = (step_counter / 2) - 1
		if riddle_index >= 0 and riddle_index < selected_riddles.size():
			_show_text(selected_riddles[riddle_index]["text"])

func _interact_page():
	if current_target:
		current_target.queue_free()
		var page_index = (step_counter - 1) / 2
		if page_index < pages.size():
			pages[page_index] = null

	step_counter += 1
	current_target = null
	interaction_indicator.visible = false
	_update_interactables()

func _show_text(text: String):
	text_label.text = text
	text_overlay.visible = true
	is_text_displayed = true
	interaction_indicator.visible = false
	input_field.text = ""
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if step_counter == 0 or is_showing_outro:
		input_container.visible = false
	else:
		input_container.visible = true
		input_field.grab_focus()

func _on_password_submitted(_text: String):
	_validate_password()

func _on_validate_pressed():
	_validate_password()

func _validate_password():
	var riddle_index = (step_counter / 2) - 1
	if riddle_index < 0 or riddle_index >= selected_riddles.size():
		return

	var entered = input_field.text.strip_edges().to_lower()
	var expected = selected_riddles[riddle_index]["password"].to_lower()

	if entered == expected:
		if step_counter == 10:
			_show_outro()
		else:
			_close_text_success()
	else:
		_show_error()

func _show_outro():
	text_overlay.visible = false
	is_showing_outro = true
	_show_text(outro_text)

func _show_error():
	input_field.text = ""
	error_label.modulate.a = 0.0
	error_label.visible = true

	var tween = create_tween()
	tween.tween_property(error_label, "modulate:a", 1.0, 1.0)
	tween.tween_property(error_label, "modulate:a", 0.0, 1.0)
	tween.tween_callback(func(): error_label.visible = false)

func _close_text_cancel():
	text_overlay.visible = false
	is_text_displayed = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _close_text_success():
	text_overlay.visible = false
	is_text_displayed = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	step_counter += 1
	_update_interactables()

func _game_completed():
	var door = get_tree().get_first_node_in_group("door_to_destroy")
	if not door:
		var neighborhood = get_parent().get_node_or_null("neighborhood")
		if neighborhood:
			door = neighborhood.get_node_or_null("DoorToDestroy")
	if door:
		door.queue_free()

	var winning_zone = get_tree().get_first_node_in_group("winning_zone")
	if not winning_zone:
		var neighborhood = get_parent().get_node_or_null("neighborhood")
		if neighborhood:
			winning_zone = neighborhood.get_node_or_null("WinningZone")
	if winning_zone and winning_zone is Area3D:
		winning_zone.body_entered.connect(_on_winning_zone_entered)

func _on_winning_zone_entered(body: Node3D):
	if body == player or body.is_in_group("player"):
		get_tree().quit()
