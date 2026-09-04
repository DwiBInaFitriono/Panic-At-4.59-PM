extends Area2D

const BALCONY_SCENE := "res://Scenes/Ending/ending_2.tscn"

var _is_transitioning: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and not _is_transitioning:
		_is_transitioning = true
		var main_node = get_tree().root.get_node_or_null("Main")
		if main_node and "fade_rect" in main_node and main_node.fade_rect != null:
			var tween := create_tween()
			tween.tween_property(main_node.fade_rect, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
			await tween.finished
		get_tree().change_scene_to_file(BALCONY_SCENE)
