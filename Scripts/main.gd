extends Node2D

const LAST_LEVEL := 3
const HOLD_DURATION := 3.0
const CARD_SCAN_SCENE := preload("res://Scenes/card_scan_minigame.tscn")
const DIALOG_SCENE := preload("res://Scenes/dialog.tscn")
const ENDING_SCENE := "res://Scenes/Ending/ending_1.tscn"

var level: int = 1
var current_level_root: Node = null

var is_player_at_exit: bool = false
var current_interactable_area: String = ""
var has_level_key: bool = false
var is_card_scanned: bool = false
var is_transitioning: bool = false
var is_minigame_open: bool = false
var has_seen_intro: bool = false
var hold_timer: float = 0.0

var exit_label: Label = null
var caught_label: Label = null
var fade_rect: ColorRect = null
var objective_container: VBoxContainer = null
var objective_header: Label = null
var objective_text: Label = null
var objective_clue: Label = null

func _ready() -> void:
	_setup_exit_ui()
	current_level_root = get_node_or_null("Roots Levels")
	_load_level(level)
	_show_intro_dialog()

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

	caught_label = Label.new()
	caught_label.name = "CaughtLabel"
	caught_label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	caught_label.anchor_left = 0.5
	caught_label.anchor_right = 0.5
	caught_label.anchor_top = 0.45
	caught_label.anchor_bottom = 0.45
	caught_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	caught_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	caught_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caught_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caught_label.add_theme_font_size_override("font_size", 36)
	caught_label.add_theme_color_override("font_color", Color(1.0, 0.25, 0.25, 1.0))
	caught_label.add_theme_constant_override("outline_size", 6)
	caught_label.add_theme_color_override("font_outline_color", Color.BLACK)
	caught_label.visible = false
	canvas.add_child(caught_label)

	objective_container = VBoxContainer.new()
	objective_container.name = "ObjectiveContainer"
	objective_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	objective_container.anchor_left = 1.0
	objective_container.anchor_right = 1.0
	objective_container.anchor_top = 0.0
	objective_container.anchor_bottom = 0.0
	objective_container.offset_right = -24
	objective_container.offset_top = 20
	objective_container.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	objective_container.grow_vertical = Control.GROW_DIRECTION_END
	objective_container.add_theme_constant_override("separation", 3)

	objective_header = Label.new()
	objective_header.name = "ObjectiveHeader"
	objective_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	objective_header.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	objective_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	objective_header.add_theme_font_size_override("font_size", 16)
	objective_header.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35, 1.0))
	objective_header.add_theme_constant_override("outline_size", 4)
	objective_header.add_theme_color_override("font_outline_color", Color.BLACK)
	objective_container.add_child(objective_header)

	objective_text = Label.new()
	objective_text.name = "ObjectiveText"
	objective_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	objective_text.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	objective_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	objective_text.add_theme_font_size_override("font_size", 18)
	objective_text.add_theme_color_override("font_color", Color(0.20, 0.95, 0.50, 1.0))
	objective_text.add_theme_constant_override("outline_size", 4)
	objective_text.add_theme_color_override("font_outline_color", Color.BLACK)
	objective_container.add_child(objective_text)

	objective_clue = Label.new()
	objective_clue.name = "ObjectiveClue"
	objective_clue.mouse_filter = Control.MOUSE_FILTER_IGNORE
	objective_clue.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	objective_clue.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	objective_clue.add_theme_font_size_override("font_size", 14)
	objective_clue.add_theme_color_override("font_color", Color(0.75, 0.90, 1.0, 0.95))
	objective_clue.add_theme_constant_override("outline_size", 4)
	objective_clue.add_theme_color_override("font_outline_color", Color.BLACK)
	objective_container.add_child(objective_clue)

	objective_container.visible = false
	canvas.add_child(objective_container)

	fade_rect = ColorRect.new()
	fade_rect.name = "FadeRect"
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_rect.color = Color.BLACK
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_rect.modulate.a = 1.0
	canvas.add_child(fade_rect)
	is_transitioning = true

func _unhandled_input(event: InputEvent) -> void:
	if is_transitioning or not is_player_at_exit or is_minigame_open:
		return
	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == KEY_E or event.physical_keycode == KEY_E:
			if current_interactable_area == "area_kunci":
				_collect_level_key()
			elif current_interactable_area == "card_scan" and not is_card_scanned:
				_open_card_minigame()
			elif current_interactable_area == "door_keluar" and is_card_scanned:
				_trigger_ending_transition()

func _process(delta: float) -> void:
	if is_transitioning or not is_player_at_exit or is_minigame_open:
		return

	if current_interactable_area == "area_kunci":
		if Input.is_key_pressed(KEY_E):
			_collect_level_key()
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
		if not has_level_key:
			hold_timer = 0.0
			_update_exit_ui(false)
			return
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

func _update_exit_ui(is_holding: bool) -> void:
	if exit_label == null or is_minigame_open or not is_player_at_exit:
		return
	exit_label.visible = true

	if current_interactable_area == "area_kunci":
		exit_label.text = "> [E] AMBIL KUNCI PINTU"
		exit_label.add_theme_color_override("font_color", Color(0.20, 0.95, 0.50, 1.0))
	elif current_interactable_area == "card_scan":
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
		if not has_level_key:
			exit_label.text = "PINTU TERKUNCI! CARI KUNCI TERLEBIH DAHULU"
			exit_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35, 1.0))
		elif is_holding and hold_timer > 0.0:
			var remaining := maxf(0.0, HOLD_DURATION - hold_timer)
			exit_label.text = "MEMBUKA PINTU... [ %.1fs ]" % remaining
			exit_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35, 1.0))
		else:
			exit_label.text = "[E] TAHAN UNTUK BUKA PINTU"
			exit_label.add_theme_color_override("font_color", Color(0.20, 0.95, 0.50, 1.0))

func _collect_level_key() -> void:
	has_level_key = true
	is_player_at_exit = false
	current_interactable_area = ""
	_update_objective_ui()
	if current_level_root:
		var key_node = current_level_root.get_node_or_null("AreaKunci")
		if key_node:
			key_node.queue_free()
	if exit_label:
		exit_label.visible = true
		exit_label.text = "KUNCI DIPEROLEH! MENUJU PINTU KELUAR"
		exit_label.add_theme_color_override("font_color", Color(0.20, 0.95, 0.50, 1.0))
		var tween := create_tween()
		tween.tween_interval(2.5)
		tween.tween_callback(func() -> void:
			if not is_player_at_exit and exit_label and exit_label.text.begins_with("KUNCI DIPEROLEH"):
				exit_label.visible = false
		)

func _open_card_minigame() -> void:
	if is_minigame_open:
		return
	is_minigame_open = true
	if exit_label:
		exit_label.visible = false
	if objective_container:
		objective_container.visible = false

	if current_level_root:
		current_level_root.process_mode = Node.PROCESS_MODE_DISABLED

	var minigame = CARD_SCAN_SCENE.instantiate()
	add_child(minigame)
	minigame.scan_completed.connect(_on_card_scan_completed)
	minigame.scan_canceled.connect(_on_card_scan_canceled)

func _on_card_scan_completed() -> void:
	is_minigame_open = false
	is_card_scanned = true
	_update_objective_ui()
	if current_level_root:
		current_level_root.process_mode = Node.PROCESS_MODE_INHERIT
	if exit_label:
		exit_label.visible = true
		exit_label.text = "AKSES DITERIMA! MENUJU PINTU KELUAR"
		exit_label.add_theme_color_override("font_color", Color(0.20, 0.95, 0.50, 1.0))
	if objective_container:
		objective_container.visible = true

func _on_card_scan_canceled() -> void:
	is_minigame_open = false
	if current_level_root:
		current_level_root.process_mode = Node.PROCESS_MODE_INHERIT
	if is_player_at_exit:
		_update_exit_ui(false)
	if objective_container:
		objective_container.visible = true

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

func _trigger_ending_transition() -> void:
	if is_transitioning:
		return
	is_transitioning = true
	is_player_at_exit = false
	if exit_label:
		exit_label.visible = false
	if objective_container:
		objective_container.visible = false

	var tween_out := create_tween()
	tween_out.tween_property(fade_rect, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await tween_out.finished

	get_tree().change_scene_to_file(ENDING_SCENE)

func _load_level(level_number: int) -> void:
	if level_number > LAST_LEVEL:
		_on_game_complete()
		return
	if level_number == 1:
		has_level_key = false
	if level_number == 3:
		is_card_scanned = false
	if current_level_root:
		remove_child(current_level_root)
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
	if not has_seen_intro:
		current_level_root.process_mode = Node.PROCESS_MODE_DISABLED
	_setup_level(current_level_root)
	_update_objective_ui()

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

	var e4 = level_root.get_node_or_null("AreaKunci")
	if e4 is Area2D:
		e4.body_entered.connect(func(body: Node2D) -> void: _on_interactive_body_entered(body, "area_kunci"))
		e4.body_exited.connect(func(body: Node2D) -> void: _on_interactive_body_exited(body, "area_kunci"))

func _on_interactive_body_entered(body: Node2D, area_type: String) -> void:
	if is_transitioning or not body.is_in_group("player"):
		return
	is_player_at_exit = true
	current_interactable_area = area_type
	hold_timer = 0.0
	_update_exit_ui(false)
	if area_type == "door_keluar" and is_card_scanned:
		_trigger_ending_transition()

func _on_interactive_body_exited(body: Node2D, area_type: String) -> void:
	if not body.is_in_group("player"):
		return
	if current_interactable_area == area_type:
		is_player_at_exit = false
		current_interactable_area = ""
		hold_timer = 0.0
		if exit_label:
			exit_label.visible = false

func _on_game_complete() -> void:
	get_tree().change_scene_to_file(ENDING_SCENE)

func on_player_caught() -> void:
	if is_transitioning:
		return
	is_transitioning = true
	is_player_at_exit = false
	current_interactable_area = ""
	is_minigame_open = false
	hold_timer = 0.0

	if current_level_root:
		current_level_root.process_mode = Node.PROCESS_MODE_DISABLED

	if exit_label:
		exit_label.visible = false
	if objective_container:
		objective_container.visible = false

	var tween_out := create_tween()
	tween_out.tween_property(fade_rect, "modulate:a", 1.0, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await tween_out.finished

	var dialog = DIALOG_SCENE.instantiate()
	add_child(dialog)
	var caught_text := "[color=#ff6b6b]Bos menangkapmu.[/color]\n\nKamu harus lembur malam ini."
	dialog.setup_dialog("SI BOS", "Tertangkap!", caught_text, "boss", "[SPASI / ENTER / E] Coba Lagi (Respawn)")
	await dialog.dialog_finished

	_load_level(level)

	await get_tree().process_frame

	var tween_in := create_tween()
	tween_in.tween_property(fade_rect, "modulate:a", 0.0, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await tween_in.finished

	if objective_container:
		objective_container.visible = true
	if current_level_root:
		current_level_root.process_mode = Node.PROCESS_MODE_INHERIT

	is_transitioning = false

func _show_intro_dialog() -> void:
	if has_seen_intro:
		return
	has_seen_intro = true
	is_transitioning = true
	if current_level_root:
		current_level_root.process_mode = Node.PROCESS_MODE_DISABLED
	var dialog = DIALOG_SCENE.instantiate()
	add_child(dialog)
	var intro_text := "Jam kerja sudah selesai dan pertandingan Piala Dunia segera mulai.\n\nBos sedang berpatroli mencari karyawan untuk lembur. Keluar dari kantor tanpa terlihat olehnya."
	dialog.setup_dialog("PENGANTAR", "Pukul 16:59", intro_text, "player", "[SPASI / ENTER / E] Mulai Permainan")
	await dialog.dialog_finished

	var tween := create_tween()
	tween.tween_property(fade_rect, "modulate:a", 0.0, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await tween.finished

	if objective_container:
		objective_container.visible = true
	if current_level_root:
		current_level_root.process_mode = Node.PROCESS_MODE_INHERIT
	is_transitioning = false

func _update_objective_ui() -> void:
	if objective_header == null or objective_text == null or objective_clue == null:
		return
	objective_header.text = "OBJECTIVE [ LEVEL %s ]" % level
	var new_text := ""
	var new_clue := ""
	if level == 1:
		if not has_level_key:
			new_text = "> Cari kunci pintu kantor"
			new_clue = "Clue: Kunci berada di sudut ruangan kanan atas"
		else:
			new_text = "> Buka pintu keluar kantor"
			new_clue = "Clue: Pintu keluar berada di sebelah kiri atas"
	elif level == 2:
		new_text = "> Menuju dan buka pintu keluar"
		new_clue = "Clue: Pintu keluar berada di sudut kanan bawah"
	elif level == 3:
		if not is_card_scanned:
			new_text = "> Pindai kartu akses di scanner"
			new_clue = "Clue: Alat scanner berada di tengah ruangan"
		else:
			new_text = "> Keluar lewat pintu utama"
			new_clue = "Clue: Pintu keluar utama berada di bagian bawah"
	else:
		new_text = "> Selesaikan misi kantor"
		new_clue = ""
	if objective_text.text != new_text:
		objective_text.text = new_text
		objective_text.modulate = Color(1.6, 1.6, 1.6, 1.0)
		var tween := create_tween()
		tween.tween_property(objective_text, "modulate", Color.WHITE, 0.5)
	objective_clue.text = new_clue
