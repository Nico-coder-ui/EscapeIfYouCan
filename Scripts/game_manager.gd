extends Node

# Compteur d'étapes du jeu
var step_counter: int = 0

# Textes associés à chaque étape paire (livre)
var book_texts: Array[String] = [
	"Texte 1 - Le début de l'histoire...",  # step 0
	"Texte 2 - La suite...",                 # step 2
	"Texte 3 - L'intrigue se corse...",      # step 4
	"Texte 4 - Un rebondissement...",        # step 6
	"Texte 5 - Presque la fin...",           # step 8
	"Texte 6 - La conclusion.",              # step 10
]

# Positions des 5 feuilles
var page_positions: Array[Vector3] = [
	Vector3(-3.26, 4.79, -5.1),    # Page 1 (step 1)
	Vector3(-0.937, 4.896, -9.536), # Page 2 (step 3)
	Vector3(0.151, 3.748, -9.938), # Page 3 (step 5)
	Vector3(2.363, 3.764, -10.195), # Page 4 (step 7)
	Vector3(-0.072, 3.737, -4.616), # Page 5 (step 9)
]

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

var current_target: Node3D = null

@export var interaction_distance: float = 3.0

const INTERACTION_LAYER: int = 2

func _ready():
	await get_tree().process_frame

	_setup_references()
	_setup_ui()
	_setup_book()
	_spawn_pages()
	_update_interactables()

	print("[GameManager] Initialisé - Camera: ", camera != null, " | Raycast: ", raycast != null, " | Book: ", book_node != null)

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
		push_error("[GameManager] Camera non trouvée!")
		return

	raycast = RayCast3D.new()
	raycast.name = "InteractionRaycast"
	raycast.target_position = Vector3(0, 0, -interaction_distance)
	raycast.enabled = true
	raycast.collision_mask = 1 << (INTERACTION_LAYER - 1)
	raycast.collide_with_areas = false
	raycast.collide_with_bodies = true
	camera.add_child(raycast)

	print("[GameManager] Raycast créé avec mask: ", raycast.collision_mask)

func _setup_ui():
	ui_layer = CanvasLayer.new()
	ui_layer.name = "GameUI"
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
	text_label.anchor_top = 0.3
	text_label.anchor_bottom = 0.7
	text_label.offset_left = 0
	text_label.offset_right = 0
	text_label.offset_top = 0
	text_label.offset_bottom = 0
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.add_theme_font_size_override("font_size", 32)
	text_label.add_theme_color_override("font_color", Color.WHITE)
	text_overlay.add_child(text_label)

func _setup_book():
	var neighborhood = get_parent().get_node_or_null("neighborhood")
	if neighborhood:
		book_node = neighborhood.get_node_or_null("Bookglb")
		if book_node:
			book_node.add_to_group("interactable")
			book_node.add_to_group("book")
			_add_collision_to_object(book_node, Vector3(0.8, 1.2, 0.6), Vector3(0, 0.5, 0))
			print("[GameManager] Livre trouvé et configuré à: ", book_node.global_position)
		else:
			push_error("[GameManager] Bookglb non trouvé dans neighborhood!")
	else:
		push_error("[GameManager] neighborhood non trouvé!")

func _spawn_pages():
	var page_scene = load("res://Assets/PaperPage.glb")
	if not page_scene:
		push_error("[GameManager] Impossible de charger PaperPage.glb")
		return

	for i in range(page_positions.size()):
		var page = page_scene.instantiate()
		page.name = "Page_" + str(i + 1)
		page.position = page_positions[i]
		page.rotation.y = PAGE_ROTATION_Y
		page.scale = PAGE_SCALE
		page.add_to_group("interactable")
		page.add_to_group("page")
		page.visible = false
		get_parent().add_child(page)
		pages.append(page)
		_add_collision_to_object(page, Vector3(0.3, 0.05, 0.4))

	print("[GameManager] ", pages.size(), " pages créées")

func _add_collision_to_object(node: Node3D, box_size: Vector3, offset: Vector3 = Vector3.ZERO):
	var static_body = StaticBody3D.new()
	static_body.name = "InteractionBody"
	static_body.collision_layer = 1 << (INTERACTION_LAYER - 1)
	static_body.collision_mask = 0  # Ne détecte rien lui-même
	static_body.position = offset  # Décalage de position

	var collision = CollisionShape3D.new()
	collision.name = "CollisionShape"
	var shape = BoxShape3D.new()
	shape.size = box_size
	collision.shape = shape

	static_body.add_child(collision)
	node.add_child(static_body)

	print("[GameManager] Collision ajoutée à ", node.name, " (layer: ", static_body.collision_layer, ", size: ", box_size, ")")

func _update_interactables():
	# Le livre est toujours visible
	if book_node:
		book_node.visible = true

	# Les pages : seule la page correspondante à l'étape impaire est visible
	for i in range(pages.size()):
		if pages[i] != null:
			var page_step = (i * 2) + 1  # Steps 1, 3, 5, 7, 9
			pages[i].visible = (step_counter == page_step)

func _process(_delta):
	if is_text_displayed:
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
	# Remonte l'arbre pour trouver un noeud interactable
	var current = node
	while current:
		if current.is_in_group("interactable"):
			return current as Node3D
		current = current.get_parent()
	return null

func _can_interact_with(target: Node3D) -> bool:
	if step_counter % 2 == 0:
		# Étape paire : on interagit avec le livre
		return target.is_in_group("book")
	else:
		# Étape impaire : on interagit avec la page correspondante
		if target.is_in_group("page"):
			var page_index = (step_counter - 1) / 2
			if page_index < pages.size() and pages[page_index] != null:
				return pages[page_index] == target
	return false

func _input(event):
	# Fermer le texte avec Échap
	if is_text_displayed and event.is_action_pressed("ui_cancel"):
		_close_text()
		return

	# Interagir avec E
	if event.is_action_pressed("interaction") and current_target and not is_text_displayed:
		_interact_with_target()

func _interact_with_target():
	if current_target.is_in_group("book"):
		_interact_book()
	elif current_target.is_in_group("page"):
		_interact_page()

func _interact_book():
	var text_index = step_counter / 2
	if text_index < book_texts.size():
		_show_text(book_texts[text_index])

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
	print("[GameManager] Page ramassée, step: ", step_counter)

func _show_text(text: String):
	text_label.text = text
	text_overlay.visible = true
	is_text_displayed = true
	interaction_indicator.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	print("[GameManager] Affichage texte step: ", step_counter)

func _close_text():
	text_overlay.visible = false
	is_text_displayed = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	step_counter += 1
	_update_interactables()
	print("[GameManager] Texte fermé, step: ", step_counter)

	if step_counter > 10:
		_game_completed()

func _game_completed():
	print("[GameManager] Jeu terminé ! Ouverture de la porte...")

	# Détruire la porte pour permettre au joueur de sortir
	var door = get_tree().get_first_node_in_group("door_to_destroy")
	if not door:
		# Chercher dans neighborhood
		var neighborhood = get_parent().get_node_or_null("neighborhood")
		if neighborhood:
			door = neighborhood.get_node_or_null("DoorToDestroy")
	if door:
		door.queue_free()
		print("[GameManager] Porte détruite")
	else:
		push_error("[GameManager] DoorToDestroy non trouvé!")

	# Connecter la zone de victoire
	var winning_zone = get_tree().get_first_node_in_group("winning_zone")
	if not winning_zone:
		var neighborhood = get_parent().get_node_or_null("neighborhood")
		if neighborhood:
			winning_zone = neighborhood.get_node_or_null("WinningZone")
	if winning_zone and winning_zone is Area3D:
		winning_zone.body_entered.connect(_on_winning_zone_entered)
		print("[GameManager] Zone de victoire connectée")
	else:
		push_error("[GameManager] WinningZone non trouvé!")

func _on_winning_zone_entered(body: Node3D):
	if body == player or body.is_in_group("player"):
		print("[GameManager] Victoire ! Le joueur s'est échappé !")
		get_tree().quit()
