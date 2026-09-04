extends Node2D

const DIALOG_SCENE := preload("res://Scenes/dialog.tscn")
const CREDITS_SCENE := "res://Scenes/credits.tscn"

var fade_rect: ColorRect = null

func _ready() -> void:
	_setup_fade_ui()
	_show_ending_dialog()

func _setup_fade_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "FadeCanvas"
	canvas.layer = 100
	add_child(canvas)

	fade_rect = ColorRect.new()
	fade_rect.name = "FadeRect"
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_rect.color = Color.BLACK
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_rect.modulate.a = 1.0
	canvas.add_child(fade_rect)

func _show_ending_dialog() -> void:
	var tween_in := create_tween()
	tween_in.tween_property(fade_rect, "modulate:a", 0.0, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

	var dialog = DIALOG_SCENE.instantiate()
	add_child(dialog)
	var text := "Kamu lolos dari pintu utama setelah memindai ID Card.\n\nKamu tiba di rumah tepat waktu dan bisa menonton pertandingan Piala Dunia malam ini."
	dialog.setup_dialog("ENDING 1", "Rute Normal / Lobby", text, "player", "[SPASI] Lanjut ke Credits")
	await dialog.dialog_finished

	var tween_out := create_tween()
	tween_out.tween_property(fade_rect, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await tween_out.finished
	get_tree().change_scene_to_file(CREDITS_SCENE)
