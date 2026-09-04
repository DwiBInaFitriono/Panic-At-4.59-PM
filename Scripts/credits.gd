extends Control

const NORMAL_SPEED := 60.0
const FAST_SPEED := 180.0

@onready var scroll_container: VBoxContainer = $VBoxContainer
@onready var hint_label: Label = $CanvasLayer/MarginContainer/Label

var is_returning: bool = false
var total_height: float = 0.0
var _fade_rect: ColorRect = null

func _ready() -> void:
	_setup_fade_ui()
	hint_label.text = "[ESC] Menu Utama  |  [SPASI] Percepat"
	hint_label.add_theme_font_size_override("font_size", 14)
	hint_label.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9, 0.7))
	await get_tree().process_frame
	await get_tree().process_frame
	total_height = scroll_container.get_combined_minimum_size().y
	scroll_container.position.y = 720.0

func _setup_fade_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "FadeCanvas"
	canvas.layer = 100
	add_child(canvas)

	_fade_rect = ColorRect.new()
	_fade_rect.name = "FadeRect"
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_rect.color = Color.BLACK
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.modulate.a = 1.0
	canvas.add_child(_fade_rect)

	var tween := create_tween()
	tween.tween_property(_fade_rect, "modulate:a", 0.0, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _process(delta: float) -> void:
	if is_returning:
		return

	var is_fast := Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_DOWN) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var speed := FAST_SPEED if is_fast else NORMAL_SPEED
	scroll_container.position.y -= speed * delta

	if scroll_container.position.y < -(total_height + 100.0):
		_return_to_main_menu()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_return_to_main_menu()

func _return_to_main_menu() -> void:
	if is_returning:
		return
	is_returning = true
	var tween := create_tween()
	tween.tween_property(_fade_rect, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")
