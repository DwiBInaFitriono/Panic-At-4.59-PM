extends Node2D

const LAST_LEVEL := 3
const HOLD_DURATION := 3.0
const CARD_SCAN_SCENE := preload("res://Scenes/card_scan_minigame.tscn")
const ENDING_SCENE := "res://Scenes/Ending/ending_1.tscn"

var level: int = 1
var current_level_root: Node = null

var is_player_at_exit: bool = false
var current_interactable_area: String = ""
var is_card_scanned: bool = false
var is_transitioning: bool = false
var is_minigame_open: bool = false
var hold_timer: float = 0.0

var exit_label: Label = null
var fade_rect: ColorRect = null

# Inisialisasi tampilan UI pintu keluar dan memuat level pertama
func _ready() -> void:
	_setup_exit_ui()
	current_level_root = get_node_or_null("Roots Levels")
	_load_level(level)

# Menyiapkan UI petunjuk teks pintu keluar bergaya pixel art dan layar transisi fade
func _setup_exit_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "ExitPromptCanvas"
	canvas.layer = 100
	add_child(canvas)

	exit_label = Label.new()
	exit_label.name = "ExitPromptLabel"
	exit_label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	exit_label.anchor_left = 0.5
	exit_label.anchor_right = 0.5
	exit_label.anchor_top = 0.86
	exit_label.anchor_bottom = 0.86
	exit_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	exit_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	exit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	exit_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	exit_label.add_theme_font_size_override("font_size", 22)
	exit_label.add_theme_color_override("font_color", Color(0.20, 0.95, 0.50, 1.0))
	exit_label.add_theme_constant_override("outline_size", 4)
	exit_label.add_theme_color_override("font_outline_color", Color.BLACK)
	exit_label.visible = false
	canvas.add_child(exit_label)

	fade_rect = ColorRect.new()
	fade_rect.name = "FadeRect"
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_rect.color = Color.BLACK
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_rect.modulate.a = 0.0
	canvas.add_child(fade_rect)

# Menangani penekanan tombol E untuk interaksi scanner kartu atau pintu keluar level 3
func _unhandled_input(event: InputEvent) -> void:
	if is_transitioning or not is_player_at_exit or is_minigame_open:
		return
	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == KEY_E or event.physical_keycode == KEY_E:
			if current_interactable_area == "card_scan" and not is_card_scanned:
				_open_card_minigame()
			elif current_interactable_area == "door_keluar" and is_card_scanned:
				_trigger_ending_transition()

# Memeriksa penahanan atau penekanan tombol E saat berada di area interaktif
func _process(delta: float) -> void:
	if is_transitioning or not is_player_at_exit or is_minigame_open:
		return

	if current_interactable_area == "card_scan" and not is_card_scanned:
		if Input.is_key_pressed(KEY_E):
			_open_card_minigame()
			return

	if current_interactable_area == "door_keluar" and is_card_scanned:
		if Input.is_key_pressed(KEY_E):
			_trigger_ending_transition()
			return

	if current_interactable_area == "exit_door":
		var is_pressing_e := Input.is_key_pressed(KEY_E)
		if is_pressing_e:
			hold_timer += delta
			_update_exit_ui(true)
			if hold_timer >= HOLD_DURATION:
				_trigger_level_transition()
		else:
			if hold_timer > 0.0:
				hold_timer = 0.0
			_update_exit_ui(false)

# Memperbarui teks petunjuk pixel saat berada di area interaktif
func _update_exit_ui(is_holding: bool) -> void:
	if exit_label == null or is_minigame_open or not is_player_at_exit:
		return
	exit_label.visible = true

	if current_interactable_area == "card_scan":
		if not is_card_scanned:
			exit_label.text = "> [E] PINDAI KARTU AKSES"
			exit_label.add_theme_color_override("font_color", Color(0.20, 0.95, 0.50, 1.0))
		else:
			exit_label.text = "KARTU SUDAH DIPINDAI - MENUJU PINTU KELUAR"
			exit_label.add_theme_color_override("font_color", Color(0.35, 0.85, 1.0, 1.0))
	elif current_interactable_area == "door_keluar":
		if not is_card_scanned:
			exit_label.text = "PINTU TERKUNCI! PINDAI KARTU TERLEBIH DAHULU"
			exit_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35, 1.0))
		else:
			exit_label.text = "> [E] KELUAR KANTOR"
			exit_label.add_theme_color_override("font_color", Color(0.20, 0.95, 0.50, 1.0))
	elif current_interactable_area == "exit_door":
		if is_holding and hold_timer > 0.0:
			var remaining := maxf(0.0, HOLD_DURATION - hold_timer)
			exit_label.text = "MEMBUKA PINTU... [ %.1fs ]" % remaining
			exit_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35, 1.0))
		else:
			exit_label.text = "[E] TAHAN UNTUK BUKA PINTU"
			exit_label.add_theme_color_override("font_color", Color(0.20, 0.95, 0.50, 1.0))

# Membuka minigame pemindaian kartu akses pada level 3
func _open_card_minigame() -> void:
	if is_minigame_open:
		return
	is_minigame_open = true
	if exit_label:
		exit_label.visible = false

	if current_level_root:
		current_level_root.process_mode = Node.PROCESS_MODE_DISABLED

	var minigame = CARD_SCAN_SCENE.instantiate()
	add_child(minigame)
	minigame.scan_completed.connect(_on_card_scan_completed)
	minigame.scan_canceled.connect(_on_card_scan_canceled)

# Menangani saat pemindaian kartu berhasil diselesaikan
func _on_card_scan_completed() -> void:
	is_minigame_open = false
	is_card_scanned = true
	if current_level_root:
		current_level_root.process_mode = Node.PROCESS_MODE_INHERIT
	if exit_label:
		exit_label.visible = true
		exit_label.text = "AKSES DITERIMA! MENUJU PINTU KELUAR"
		exit_label.add_theme_color_override("font_color", Color(0.20, 0.95, 0.50, 1.0))

# Menangani saat pemindaian kartu dibatalkan oleh pemain
func _on_card_scan_canceled() -> void:
	is_minigame_open = false
	if current_level_root:
		current_level_root.process_mode = Node.PROCESS_MODE_INHERIT
	if is_player_at_exit:
		_update_exit_ui(false)

# Menjalankan transisi layar fade out dan berpindah ke level berikutnya
func _trigger_level_transition() -> void:
	if is_transitioning:
		return
	is_transitioning = true
	is_player_at_exit = false
	is_minigame_open = false
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

# Menjalankan transisi layar fade out dan berpindah ke scene ending
func _trigger_ending_transition() -> void:
	if is_transitioning:
		return
	is_transitioning = true
	is_player_at_exit = false
	if exit_label:
		exit_label.visible = false

	var tween_out := create_tween()
	tween_out.tween_property(fade_rect, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await tween_out.finished

	get_tree().change_scene_to_file(ENDING_SCENE)

# Memuat scene level berdasarkan nomor level yang diminta
func _load_level(level_number: int) -> void:
	if level_number > LAST_LEVEL:
		_on_game_complete()
		return
	if current_level_root:
		current_level_root.queue_free()
	is_player_at_exit = false
	is_minigame_open = false
	hold_timer = 0.0
	if exit_label:
		exit_label.visible = false

	var level_path = "res://Scenes/Levels/levels_%s.tscn" % level_number
	current_level_root = load(level_path).instantiate()
	add_child(current_level_root)
	current_level_root.name = "Roots Levels"
	_setup_level(current_level_root)

# Menghubungkan sinyal deteksi pemain pada area interaktif level
func _setup_level(level_root: Node) -> void:
	is_player_at_exit = false
	current_interactable_area = ""
	is_card_scanned = false
	hold_timer = 0.0
	if exit_label:
		exit_label.visible = false

	var e1 = level_root.get_node_or_null("Exit")
	if e1 is Area2D:
		e1.body_entered.connect(func(body: Node2D) -> void: _on_interactive_body_entered(body, "exit_door"))
		e1.body_exited.connect(func(body: Node2D) -> void: _on_interactive_body_exited(body, "exit_door"))

	var e2 = level_root.get_node_or_null("AreaPintuKeluar")
	if e2 is Area2D:
		e2.body_entered.connect(func(body: Node2D) -> void: _on_interactive_body_entered(body, "door_keluar"))
		e2.body_exited.connect(func(body: Node2D) -> void: _on_interactive_body_exited(body, "door_keluar"))

	var e3 = level_root.get_node_or_null("CardScan")
	if e3 is Area2D:
		e3.body_entered.connect(func(body: Node2D) -> void: _on_interactive_body_entered(body, "card_scan"))
		e3.body_exited.connect(func(body: Node2D) -> void: _on_interactive_body_exited(body, "card_scan"))

# Menangani saat pemain mulai memasuki area interaktif tertentu
func _on_interactive_body_entered(body: Node2D, area_type: String) -> void:
	if is_transitioning or not body.is_in_group("player"):
		return
	is_player_at_exit = true
	current_interactable_area = area_type
	hold_timer = 0.0
	_update_exit_ui(false)
	if area_type == "door_keluar" and is_card_scanned:
		_trigger_ending_transition()

# Menangani saat pemain melangkah keluar dari area interaktif tertentu
func _on_interactive_body_exited(body: Node2D, area_type: String) -> void:
	if not body.is_in_group("player"):
		return
	if current_interactable_area == area_type:
		is_player_at_exit = false
		current_interactable_area = ""
		hold_timer = 0.0
		if exit_label:
			exit_label.visible = false

# Berpindah ke scene ending saat seluruh permainan selesai
func _on_game_complete() -> void:
	get_tree().change_scene_to_file(ENDING_SCENE)
