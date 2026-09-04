extends Control

@onready var play_button: Button = $MarginContainer/VBoxContainer/VBoxContainer/Button
@onready var options_button: Button = $MarginContainer/VBoxContainer/VBoxContainer/Button2
@onready var credits_button: Button = $MarginContainer/VBoxContainer/VBoxContainer/Button3
@onready var quit_button: Button = $MarginContainer/VBoxContainer/VBoxContainer/Button4

@onready var options_panel: PanelContainer = $PanelContainer
@onready var options_title: Label = $PanelContainer/VBoxContainer/Label
@onready var volume_label: Label = $PanelContainer/VBoxContainer/Label2
@onready var volume_slider: HSlider = $PanelContainer/VBoxContainer/HSlider
@onready var fullscreen_checkbox: CheckBox = $PanelContainer/VBoxContainer/CheckBox
@onready var back_button: Button = $PanelContainer/VBoxContainer/Button

var _is_transitioning: bool = false
var _fade_rect: ColorRect = null

func _ready() -> void:
	_setup_fade_ui()
	options_panel.visible = false
	options_title.text = "PENGATURAN"
	volume_label.text = "Volume Suara"
	fullscreen_checkbox.text = "Layar Penuh (Fullscreen)"

	play_button.pressed.connect(_on_play_button_pressed)
	options_button.pressed.connect(_on_options_button_pressed)
	credits_button.pressed.connect(_on_credits_button_pressed)
	quit_button.pressed.connect(_on_quit_button_pressed)
	back_button.pressed.connect(_on_back_button_pressed)

	volume_slider.value = db_to_linear(AudioServer.get_bus_volume_db(0))
	volume_slider.value_changed.connect(_on_volume_changed)

	fullscreen_checkbox.button_pressed = (DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)
	fullscreen_checkbox.toggled.connect(_on_fullscreen_toggled)

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
	tween.tween_property(_fade_rect, "modulate:a", 0.0, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _on_play_button_pressed() -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	var tween := create_tween()
	tween.tween_property(_fade_rect, "modulate:a", 1.0, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	get_tree().change_scene_to_file("res://Scenes/main.tscn")

func _on_credits_button_pressed() -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	var tween := create_tween()
	tween.tween_property(_fade_rect, "modulate:a", 1.0, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	get_tree().change_scene_to_file("res://Scenes/credits.tscn")

func _on_options_button_pressed() -> void:
	if _is_transitioning:
		return
	options_panel.visible = true
	options_panel.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(options_panel, "modulate:a", 1.0, 0.2)

func _on_back_button_pressed() -> void:
	var tween := create_tween()
	tween.tween_property(options_panel, "modulate:a", 0.0, 0.15)
	await tween.finished
	options_panel.visible = false

func _on_volume_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(value))

func _on_fullscreen_toggled(toggled_on: bool) -> void:
	if toggled_on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _on_quit_button_pressed() -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	var tween := create_tween()
	tween.tween_property(_fade_rect, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	get_tree().quit()
