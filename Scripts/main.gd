extends Node2D

const LAST_LEVEL := 3
const HOLD_DURATION := 3.0

var level: int = 1
var current_level_root: Node = null

var is_player_at_exit: bool = false
var is_transitioning: bool = false
var hold_timer: float = 0.0

var exit_label: Label = null
var fade_rect: ColorRect = null

func _ready() -> void:
	_setup_exit_ui()
	current_level_root = get_node_or_null("Roots Levels")
	_load_level(level)

func _setup_exit_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "ExitPromptCanvas"
	canvas.layer = 100
	add_child(canvas)

	# Label Teks Petunjuk
	exit_label = Label.new()
	exit_label.name = "ExitLabel"
	exit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	exit_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	exit_label.anchor_left = 0.5
	exit_label.anchor_right = 0.5
	exit_label.anchor_top = 0.85
	exit_label.anchor_bottom = 0.85
	exit_label.offset_left = -250
	exit_label.offset_right = 250
	exit_label.offset_top = -25
	exit_label.offset_bottom = 25
	exit_label.add_theme_font_size_override("font_size", 22)
	exit_label.add_theme_color_override("font_color", Color.WHITE)
	exit_label.add_theme_color_override("font_outline_color", Color.BLACK)
	exit_label.add_theme_constant_override("outline_size", 6)
	exit_label.visible = false
	canvas.add_child(exit_label)

	fade_rect = ColorRect.new()
	fade_rect.name = "FadeRect"
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_rect.color = Color.BLACK
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_rect.modulate.a = 0.0
	canvas.add_child(fade_rect)

func _process(delta: float) -> void:
	if is_transitioning or not is_player_at_exit:
		return

	var is_pressing_e := Input.is_key_pressed(KEY_E)
	if is_pressing_e:
		hold_timer += delta
		_update_exit_label(true)
		if hold_timer >= HOLD_DURATION:
			_trigger_level_transition()
	else:
		if hold_timer > 0.0:
			hold_timer = 0.0
			_update_exit_label(false)

func _update_exit_label(is_holding: bool) -> void:
	if exit_label == null:
		return
	exit_label.visible = true

	if is_holding and hold_timer > 0.0:
		var remaining := maxf(0.0, HOLD_DURATION - hold_timer)
		exit_label.text = "Membuka Pintu... (%.1fs)" % remaining
		exit_label.add_theme_color_override("font_color", Color.YELLOW)
	else:
		exit_label.text = "Tahan [E] untuk Keluar"
		exit_label.add_theme_color_override("font_color", Color.WHITE)

func _trigger_level_transition() -> void:
	if is_transitioning:
		return
	is_transitioning = true
	is_player_at_exit = false
	hold_timer = 0.0

	if exit_label:
		exit_label.visible = false

	var tween_out := create_tween()
	tween_out.tween_property(fade_rect, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await tween_out.finished

	level += 1
	_load_level(level)

	await get_tree().process_frame

	var tween_in := create_tween()
	tween_in.tween_property(fade_rect, "modulate:a", 0.0, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await tween_in.finished

	is_transitioning = false

# LEVEL MANAGEMENT
func _load_level(level_number: int) -> void:
	if level_number > LAST_LEVEL:
		_on_game_complete()
		return
	if current_level_root:
		current_level_root.queue_free()
	is_player_at_exit = false
	hold_timer = 0.0
	if exit_label:
		exit_label.visible = false

	var level_path = "res://Scenes/Levels/levels_%s.tscn" % level_number
	current_level_root = load(level_path).instantiate()
	add_child(current_level_root)
	current_level_root.name = "Roots Levels"
	_setup_level(current_level_root)

func _setup_level(level_root: Node) -> void:
	var exit = level_root.get_node_or_null("Exit")
	if exit:
		if not exit.body_entered.is_connected(_on_exit_body_entered):
			exit.body_entered.connect(_on_exit_body_entered)
		if not exit.body_exited.is_connected(_on_exit_body_exited):
			exit.body_exited.connect(_on_exit_body_exited)

# SIGNAL HANDLERS
func _on_exit_body_entered(body: Node2D) -> void:
	if is_transitioning:
		return
	if body.is_in_group("player"):
		is_player_at_exit = true
		hold_timer = 0.0
		if exit_label:
			exit_label.modulate.a = 1.0
		_update_exit_label(false)

func _on_exit_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		is_player_at_exit = false
		hold_timer = 0.0
		if exit_label and exit_label.visible and not is_transitioning:
			var tween := create_tween()
			tween.tween_property(exit_label, "modulate:a", 0.0, 0.2)
			tween.tween_callback(func():
				if is_instance_valid(exit_label) and not is_player_at_exit:
					exit_label.visible = false
					exit_label.modulate.a = 1.0
			)

func _on_game_complete() -> void:
	print("GAME COMPLETE")
	get_tree().quit()
