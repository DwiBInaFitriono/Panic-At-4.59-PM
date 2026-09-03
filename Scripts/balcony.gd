extends Area2D

const BALCONY_SCENE := "res://Scenes/Levels/levels_balcony.tscn"


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	pass


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		get_tree().change_scene_to_file(BALCONY_SCENE)
