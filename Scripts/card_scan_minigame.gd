extends CanvasLayer

signal scan_completed
signal scan_canceled

const SCAN_DURATION := 5.0

@onready var card_window: Panel = $CardWindow
@onready var close_button: Button = $CardWindow/HeaderBar/CloseButton
@onready var scanner_frame: Panel = $CardWindow/ScannerFrame
@onready var scanner_target: TextureRect = $CardWindow/ScannerFrame/ScannerTarget
@onready var laser_line: ColorRect = $CardWindow/ScannerFrame/ScannerTarget/LaserLine
@onready var key_card: TextureRect = $CardWindow/KeyCard
@onready var status_label: Label = $CardWindow/StatusPanel/StatusLabel

var home_global_position: Vector2 = Vector2.ZERO
var is_dragging: bool = false
var is_scanning: bool = false
var is_completed: bool = false
var drag_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	await get_tree().process_frame
	home_global_position = key_card.global_position
	laser_line.visible = false
	laser_line.reparent(card_window)
	laser_line.set_anchors_preset(Control.PRESET_TOP_LEFT)
	laser_line.size = Vector2(scanner_target.size.x, 4.0)
	key_card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	key_card.gui_input.connect(_on_key_card_gui_input)
	close_button.pressed.connect(_on_close_button_pressed)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_cancel_minigame()
		return

	if not is_dragging or is_scanning or is_completed:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		is_dragging = false
		key_card.modulate = Color.WHITE
		_check_card_drop()
	elif event is InputEventMouseMotion:
		key_card.global_position = get_viewport().get_mouse_position() + drag_offset

func _on_key_card_gui_input(event: InputEvent) -> void:
	if is_scanning or is_completed:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if home_global_position == Vector2.ZERO:
			home_global_position = key_card.global_position
		is_dragging = true
		drag_offset = key_card.global_position - get_viewport().get_mouse_position()
		key_card.modulate = Color(1.15, 1.15, 1.15)

func _check_card_drop() -> void:
	var scanner_rect := scanner_target.get_global_rect()
	var card_rect := key_card.get_global_rect()

	var is_overlapping := scanner_rect.intersects(card_rect)
	var is_close := scanner_rect.get_center().distance_to(card_rect.get_center()) < 140.0

	if is_overlapping and is_close:
		_start_scan()
	else:
		_reset_card_position()

func _start_scan() -> void:
	is_scanning = true
	var target_global_pos := scanner_target.global_position + (scanner_target.size - key_card.size) * 0.5

	var snap_tween := create_tween()
	snap_tween.tween_property(key_card, "global_position", target_global_pos, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await snap_tween.finished

	status_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35, 1.0))

	laser_line.visible = true
	var start_y := scanner_target.global_position.y
	var end_y := start_y + scanner_target.size.y - 4.0
	laser_line.global_position = Vector2(scanner_target.global_position.x, start_y)

	var laser_tween := create_tween().set_loops()
	laser_tween.tween_property(laser_line, "global_position:y", end_y, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	laser_tween.tween_property(laser_line, "global_position:y", start_y, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var elapsed := 0.0
	while elapsed < SCAN_DURATION:
		if not is_inside_tree() or is_queued_for_deletion():
			return
		var remaining := maxf(0.0, SCAN_DURATION - elapsed)
		status_label.text = "> MEMINDAI KARTU AKSES... [ %.1fs ]" % remaining
		await get_tree().process_frame
		elapsed += get_process_delta_time()

	laser_tween.kill()
	laser_line.visible = false
	is_completed = true

	status_label.text = "> AKSES DITERIMA // PINTU TERBUKA"
	status_label.add_theme_color_override("font_color", Color(0.20, 0.95, 0.50, 1.0))

	await get_tree().create_timer(0.6).timeout
	if not is_inside_tree() or is_queued_for_deletion():
		return
	scan_completed.emit()

	var close_tween := create_tween()
	close_tween.tween_property(card_window, "modulate:a", 0.0, 0.2)
	await close_tween.finished
	queue_free()

func _reset_card_position() -> void:
	status_label.text = "> POSISI TIDAK TEPAT // COBA LAGI"
	status_label.add_theme_color_override("font_color", Color(0.95, 0.35, 0.35, 1.0))

	var return_tween := create_tween()
	return_tween.tween_property(key_card, "global_position", home_global_position, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await return_tween.finished

	await get_tree().create_timer(1.0).timeout
	if not is_scanning and not is_completed:
		status_label.text = "> TARIK KARTU KE KOTAK SENSOR SCANNER [ESC untuk Batal]"
		status_label.add_theme_color_override("font_color", Color(0.20, 0.95, 0.50, 1.0))

func _cancel_minigame() -> void:
	if is_completed:
		return
	scan_canceled.emit()
	queue_free()

func _on_close_button_pressed() -> void:
	_cancel_minigame()
