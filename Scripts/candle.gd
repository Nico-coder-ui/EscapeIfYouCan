extends Node3D

@export var interval := 15.0
@export var light_drop_per_state := 0.02
@export var candle_base_path: String = "res://Assets/Candles/CandleState"
@onready var light := $OmniLight3D	

var _timer := 0.0
var _state: int = 1
var _had_default: bool = true
var _current: Node = null
var _extinguish_notified: bool = false

func _ready():
	_current = get_child(0)
	var name_str: String = name	
	if "-default" in name_str:
		_had_default = true
		name_str = name_str.replace("-default", "")
	var digits = name_str.replace("CandleState", "")
	if digits.is_valid_int():
		_state = int(digits)

func _process(delta):
	if light and light.visible:
		light.light_energy = 1.5 + sin(Time.get_ticks_msec() * 0.005) * 0.3
	_timer += delta
	if _timer >= interval:
		_timer = 0.0
		_advance()

func _advance():
	if _had_default:
		_had_default = false
		_load_state(_state)
		return
	if _state >= 16:
		if not _extinguish_notified:
			_extinguish_notified = true
			_notify_game_manager_candle_extinguished()
		light.visible = false
		return
	_state += 1
	_load_state(_state)

func _load_state(n: int):
	var path = candle_base_path + str(n) + ".glb"
	if not ResourceLoader.exists(path):
		print("Introuvable : ", path)
		return
	var new_node = load(path).instantiate()
	add_child(new_node)
	if _current:
		_current.queue_free()
	_current = new_node
	if light:
		light.position.y -= light_drop_per_state

func _notify_game_manager_candle_extinguished():
	var gm = get_tree().get_first_node_in_group("game_manager")
	if gm and gm.has_method("on_candle_extinguished"):
		gm.on_candle_extinguished()
