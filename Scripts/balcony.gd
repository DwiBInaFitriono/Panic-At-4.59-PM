extends Area2D

const BALCONY_SCENE := "res://Scenes/Levels/levels_balcony.tscn"

# Inisialisasi dan menghubungkan sinyal saat pemain masuk area
func _ready() -> void:
	body_entered.connect(_on_body_entered)

# Berpindah ke scene balkon saat pemain memasuki area ini
func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		get_tree().change_scene_to_file(BALCONY_SCENE)
