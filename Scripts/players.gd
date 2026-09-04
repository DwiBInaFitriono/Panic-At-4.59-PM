extends CharacterBody2D

signal noise_emitted(pos: Vector2, loudness: float)

const WALK_SPEED := 100.0
const RUN_SPEED := 180.0
const ACCELERATION := 1200.0
const FRICTION := 1000.0

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

var last_dir: Vector2 = Vector2.DOWN

# Mengatur pergerakan pemain, akselerasi, sprint, dan pemancaran suara langkah
func _physics_process(delta: float) -> void:  
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")

	var is_running := Input.is_action_pressed("sprint")
	var target_speed := RUN_SPEED if is_running else WALK_SPEED

	if direction != Vector2.ZERO:
		velocity = velocity.move_toward(direction * target_speed, ACCELERATION * delta)
		last_dir = direction
		_play_animation("Walk" if not is_running else "Run", direction)
		if is_running:
			noise_emitted.emit(global_position, 280.0)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)
		_play_animation("Idle", last_dir)

	move_and_slide()

# Memainkan animasi karakter berdasarkan status aksi dan arah hadap
func _play_animation(state: String, dir: Vector2) -> void:
	var anim_name := state + _get_direction_suffix(dir)

	if anim.sprite_frames.has_animation(anim_name) and anim.animation != anim_name:
		anim.play(anim_name)

# Mengonversi vektor arah menjadi teks akhiran nama animasi
func _get_direction_suffix(dir: Vector2) -> String:
	var suffix := ""
	if dir.y < 0.0:
		suffix += "_up"
	elif dir.y > 0.0:
		suffix += "_down"
	if dir.x < 0.0:
		suffix += "_L"
	elif dir.x > 0.0:
		suffix += "_R"

	return suffix if suffix != "" else "_down"
