extends Control

signal dialog_finished

@onready var dialoque_panel: PanelContainer = $CanvasLayer/Control/DialoquePanel
@onready var player_avatar_frame: PanelContainer = $CanvasLayer/Control/DialoquePanel/MarginContainer/HBoxContainer/PlayerAvatarFrame
@onready var player_avatar_texture: TextureRect = $CanvasLayer/Control/DialoquePanel/MarginContainer/HBoxContainer/PlayerAvatarFrame/AvatarTexture
@onready var boss_avatar_frame: PanelContainer = $CanvasLayer/Control/DialoquePanel/MarginContainer/HBoxContainer/BossavatarFrame
@onready var boss_avatar_texture: TextureRect = $CanvasLayer/Control/DialoquePanel/MarginContainer/HBoxContainer/BossavatarFrame/AvatarTexture
@onready var speaker_name_label: Label = $CanvasLayer/Control/DialoquePanel/MarginContainer/HBoxContainer/ContentVbox/NameplateContainer/SpeakerNameLabel
@onready var speaker_title_label: Label = $CanvasLayer/Control/DialoquePanel/MarginContainer/HBoxContainer/ContentVbox/NameplateContainer/SpeakerTitleLabel
@onready var dialoque_text: RichTextLabel = $CanvasLayer/Control/DialoquePanel/MarginContainer/HBoxContainer/ContentVbox/DialoqueText
@onready var control_hint: Label = $CanvasLayer/Control/DialoquePanel/MarginContainer/HBoxContainer/ContentVbox/footerHbox/controlHint
@onready var continue_indicator: Label = $CanvasLayer/Control/DialoquePanel/MarginContainer/HBoxContainer/ContentVbox/footerHbox/ContinueIndicator

var _is_typing: bool = false
var _typewriter_tween: Tween = null
var _indicator_tween: Tween = null
var _is_closing: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func setup_dialog(speaker_name: String, speaker_title: String, text_content: String, avatar: String = "none", hint: String = "[SPASI / ENTER / E] Lanjut") -> void:
	modulate.a = 0.0
	var fade_in := create_tween()
	fade_in.tween_property(self, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	speaker_name_label.text = speaker_name
	speaker_title_label.text = " - " + speaker_title if speaker_title != "" else ""
	control_hint.text = hint

	if avatar == "player":
		player_avatar_frame.visible = true
		boss_avatar_frame.visible = false
		var atlas := AtlasTexture.new()
		atlas.atlas = preload("res://Assets/Players/player_idle.png")
		atlas.region = Rect2(0, 0, 32, 32)
		player_avatar_texture.texture = atlas
	elif avatar == "boss":
		player_avatar_frame.visible = false
		boss_avatar_frame.visible = true
		var atlas := AtlasTexture.new()
		atlas.atlas = preload("res://Assets/Bosses/boss_idle_l.png")
		atlas.region = Rect2(0, 0, 32, 32)
		boss_avatar_texture.texture = atlas
	else:
		player_avatar_frame.visible = false
		boss_avatar_frame.visible = false

	continue_indicator.visible = false
	dialoque_text.text = text_content
	dialoque_text.visible_characters = 0
	_is_typing = true

	var total_chars := dialoque_text.get_total_character_count()
	var duration := maxf(0.8, float(total_chars) / 38.0)

	if _typewriter_tween:
		_typewriter_tween.kill()
	_typewriter_tween = create_tween()
	_typewriter_tween.tween_property(dialoque_text, "visible_characters", total_chars, duration)
	_typewriter_tween.finished.connect(_on_typewriter_finished)

func _unhandled_input(event: InputEvent) -> void:
	if _is_closing:
		return
	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER or event.keycode == KEY_E:
			get_viewport().set_input_as_handled()
			_advance_dialog()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		_advance_dialog()

func _advance_dialog() -> void:
	if _is_typing:
		if _typewriter_tween:
			_typewriter_tween.kill()
		_on_typewriter_finished()
	else:
		_close_dialog()

func _on_typewriter_finished() -> void:
	_is_typing = false
	dialoque_text.visible_characters = -1
	continue_indicator.visible = true
	if _indicator_tween:
		_indicator_tween.kill()
	_indicator_tween = create_tween().set_loops()
	_indicator_tween.tween_property(continue_indicator, "modulate:a", 0.2, 0.4)
	_indicator_tween.tween_property(continue_indicator, "modulate:a", 1.0, 0.4)

func _close_dialog() -> void:
	if _is_closing:
		return
	_is_closing = true
	if _indicator_tween:
		_indicator_tween.kill()
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	await tween.finished
	dialog_finished.emit()
	queue_free()
