extends Node2D

var level: int = 1
var current_level_root: Node = null

func _ready() -> void:
	current_level_root = get_node("Roots Levels")
	_load_level(level)

#LEVEL MANAGEMENT
func _load_level(level_number: int) -> void:
	if current_level_root:
		current_level_root.queue_free()
	var level_path = "res://Scenes/Levels/levels_%s.tscn" % level_number
	current_level_root = load(level_path).instantiate()
	add_child(current_level_root)
	current_level_root.name = "Roots Levels"
	_setup_level(current_level_root)

func _setup_level(level_root: Node) -> void:
	var exit = level_root.get_node_or_null("Exit")
	if exit:
		exit.body_entered.connect(_on_exit_body_entered)

# SIGNAL HANDLERS
func _on_exit_body_entered(body: Node2D) -> void:
	if body.name == "Players":
		level += 1
		call_deferred("_load_level", level)
