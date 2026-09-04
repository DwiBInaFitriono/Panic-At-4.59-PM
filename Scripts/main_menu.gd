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

# Inisialisasi tombol menu utama dan pengaturan opsi
func _ready() -> void:
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

# Memulai permainan dan berpindah ke scene utama
func _on_play_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/main.tscn")

# Berpindah ke scene credits permainan
func _on_credits_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/credits.tscn")

# Membuka panel menu pengaturan opsi
func _on_options_button_pressed() -> void:
	options_panel.visible = true

# Menutup panel menu pengaturan opsi
func _on_back_button_pressed() -> void:
	options_panel.visible = false

# Mengatur volume audio bus utama
func _on_volume_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(value))

# Mengalihkan mode tampilan layar penuh atau jendela
func _on_fullscreen_toggled(toggled_on: bool) -> void:
	if toggled_on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

# Keluar dari aplikasi permainan
func _on_quit_button_pressed() -> void:
	get_tree().quit()
