extends CharacterBody2D

enum State { PATROL, SUSPICIOUS, INVESTIGATING, CHASE }

@export var can_run: bool = true
@export var chase_speed: float = 205.0
@export var chase_speed_walk_only: float = 105.0
@export var roam_speed: float = 80.0
@export var suspicious_speed: float = 110.0

@export var vision_range: float = 220.0
@export var cone_angle: float = 45.0
@export var alert_buildup_speed: float = 1.5
@export var alert_decay_speed: float = 0.5
@export var hearing_range: float = 200.0

@export var lose_sight_range: float = 420.0
@export var lose_sight_time: float = 1.5
@export var roam_pause_min: float = 1.0
@export var roam_pause_max: float = 3.0

const STUCK_CHECK_TIME = 1.0
const STUCK_DISTANCE = 6.0
const OBSTACLE_LOOKAHEAD = 26.0
const OBSTACLE_REACT_TIME = 0.35
var DEBUG := OS.is_debug_build()

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var vision_ray: RayCast2D = $VisionRay
@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D
@onready var obstacle_ray: RayCast2D = get_node_or_null("ObstacleRay")

var state: State = State.PATROL
var alert_level: float = 0.0
var alert_label: Label = null

var last_dir: Vector2 = Vector2.DOWN
var is_chasing := false
var _roam_paused := false
var _lose_sight_timer := 0.0
var _last_debug_ms := 0
var _stuck_timer := 0.0
var _stuck_check_pos := Vector2.ZERO
var _obstacle_timer := 0.0

var _investigate_pos: Vector2 = Vector2.ZERO
var _investigate_timer: float = 0.0
var _connected_player: Node2D = null

var noise_alert_min: float = 0.4
var lost_sight_investigate_time: float = 2.5
var lost_sight_alert_level: float = 0.4
var is_roam_running: bool = false
var roam_run_speed: float = 140.0
var roam_run_chance: float = 0.0
var _is_catching_player: bool = false

func _debug_log(msg: String) -> void:
	if not DEBUG:
		return
	var now := Time.get_ticks_msec()
	if now - _last_debug_ms < 500:
		return
	_last_debug_ms = now
	print(msg)

func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	_check_animations()
	_setup_alert_label()
	_apply_difficulty_by_level()

	nav_agent.path_desired_distance = 8.0
	nav_agent.target_desired_distance = 16.0

	if obstacle_ray == null:
		print("[BOSS] (opsional) node 'ObstacleRay' gak ada -> deteksi collision di depan gak aktif, cuma pakai fallback stuck-check.")

	await get_tree().physics_frame
	await get_tree().physics_frame

	var regions := NavigationServer2D.map_get_regions(nav_agent.get_navigation_map())
	_debug_log("[BOSS] Region navigasi terdeteksi: %d (harusnya minimal 1)" % regions.size())

	_pick_roam_target()

func _get_current_level_number() -> int:
	var main_node = get_tree().root.get_node_or_null("Main")
	if main_node and "level" in main_node:
		return main_node.level

	var cur: Node = self
	while cur:
		if cur.scene_file_path != "":
			if "levels_3" in cur.scene_file_path:
				return 3
			elif "levels_2" in cur.scene_file_path:
				return 2
			elif "levels_1" in cur.scene_file_path:
				return 1
		cur = cur.get_parent()

	if get_tree().current_scene:
		var sp := get_tree().current_scene.scene_file_path
		if "levels_3" in sp:
			return 3
		elif "levels_2" in sp:
			return 2
		elif "levels_1" in sp:
			return 1

	return 1

func _apply_difficulty_by_level() -> void:
	var lvl := _get_current_level_number()
	_debug_log("[BOSS] Menyetel statistik Boss untuk Level %d" % lvl)

	match lvl:
		1:
			can_run = false
			chase_speed_walk_only = 90.0
			roam_speed = 65.0
			suspicious_speed = 85.0
			vision_range = 175.0
			cone_angle = 35.0
			alert_buildup_speed = 1.0
			alert_decay_speed = 0.8
			lose_sight_time = 1.2
			lose_sight_range = 340.0
			hearing_range = 160.0
			roam_pause_min = 1.5
			roam_pause_max = 3.5
			noise_alert_min = 0.35
			lost_sight_investigate_time = 2.0
			lost_sight_alert_level = 0.35
			roam_run_speed = 65.0
			roam_run_chance = 0.0

		2:
			can_run = true
			chase_speed = 195.0
			roam_speed = 90.0
			suspicious_speed = 130.0
			vision_range = 280.0
			cone_angle = 50.0
			alert_buildup_speed = 2.6
			alert_decay_speed = 0.3
			lose_sight_time = 2.5
			lose_sight_range = 480.0
			hearing_range = 190.0
			roam_pause_min = 0.4
			roam_pause_max = 1.2
			noise_alert_min = 0.45
			lost_sight_investigate_time = 3.0
			lost_sight_alert_level = 0.55
			roam_run_speed = 155.0
			roam_run_chance = 0.45

		3, _:
			can_run = true
			chase_speed = 220.0
			roam_speed = 105.0
			suspicious_speed = 160.0
			vision_range = 350.0
			cone_angle = 60.0
			alert_buildup_speed = 4.0
			alert_decay_speed = 0.15
			lose_sight_time = 3.5
			lose_sight_range = 600.0
			hearing_range = 230.0
			roam_pause_min = 0.1
			roam_pause_max = 0.5
			noise_alert_min = 0.50
			lost_sight_investigate_time = 4.0
			lost_sight_alert_level = 0.70
			roam_run_speed = 185.0
			roam_run_chance = 0.70

func _setup_alert_label() -> void:
	alert_label = get_node_or_null("AlertLabel") as Label
	if alert_label == null:
		alert_label = Label.new()
		alert_label.name = "AlertLabel"
		alert_label.custom_minimum_size = Vector2(60, 30)
		alert_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		alert_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		alert_label.position = Vector2(-30, -45)
		alert_label.add_theme_color_override("font_color", Color.YELLOW)
		alert_label.add_theme_font_size_override("font_size", 20)
		add_child(alert_label)

func _check_player_noise_connection(player: Node2D) -> void:
	if player != null and player != _connected_player:
		_connected_player = player
		if player.has_signal("noise_emitted") and not player.is_connected("noise_emitted", _on_player_noise):
			player.connect("noise_emitted", _on_player_noise)

func _on_player_noise(pos: Vector2, loudness: float) -> void:
	if state == State.PATROL or state == State.SUSPICIOUS:
		var dist := global_position.distance_to(pos)
		var effective_range := minf(loudness, hearing_range)
		if dist <= effective_range:
			_investigate_pos = pos
			alert_level = maxf(alert_level, noise_alert_min)
			state = State.SUSPICIOUS
			_debug_log("[BOSS] Mendengar suara di (" + str(int(pos.x)) + ", " + str(int(pos.y)) + ")!")

func _physics_process(delta: float) -> void:
	var player := _get_player()
	_check_player_noise_connection(player)

	var can_see := player != null and _can_see_player(player)

	if can_see and player != null:
		var dist := global_position.distance_to(player.global_position)
		var distance_factor := clampf(1.0 - (dist / vision_range), 0.25, 1.0)
		var sprint_bonus := 1.8 if Input.is_action_pressed("sprint") else 1.0
		alert_level = minf(1.0, alert_level + delta * alert_buildup_speed * distance_factor * sprint_bonus)
		_lose_sight_timer = lose_sight_time
		_investigate_pos = player.global_position
	else:
		_lose_sight_timer = maxf(0.0, _lose_sight_timer - delta)
		if state != State.CHASE or _lose_sight_timer <= 0.0:
			alert_level = maxf(0.0, alert_level - delta * alert_decay_speed)

	match state:
		State.PATROL:
			if alert_level >= 1.0:
				_enter_chase()
			elif alert_level > 0.0:
				state = State.SUSPICIOUS
				_debug_log("[BOSS] ??? Curiga!")
			else:
				_roam(delta)

		State.SUSPICIOUS:
			if alert_level >= 1.0:
				_enter_chase()
			elif alert_level <= 0.0:
				state = State.PATROL
				_debug_log("[BOSS] Kembali tenang (Patrol).")
				_pick_roam_target()
			else:
				_move_towards_pos(_investigate_pos, suspicious_speed, delta)

		State.INVESTIGATING:
			_investigate_timer -= delta
			velocity = Vector2.ZERO
			if alert_level >= 1.0:
				_enter_chase()
			elif _investigate_timer <= 0.0:
				state = State.PATROL
				_debug_log("[BOSS] Selesai menyelidiki area, kembali roam.")
				_pick_roam_target()

		State.CHASE:
			var give_up := player == null or _lose_sight_timer <= 0.0
			if give_up:
				state = State.INVESTIGATING
				_investigate_timer = lost_sight_investigate_time
				alert_level = lost_sight_alert_level
				_debug_log("[BOSS] Kehilangan jejak player! Menyelidiki lokasi terakhir...")
			else:
				_chase(player)
				_reset_stuck_tracker()

	is_chasing = (state == State.CHASE)
	move_and_slide()
	_check_player_caught(player)
	_update_alert_ui()
	_play_animation()

func _enter_chase() -> void:
	state = State.CHASE
	is_chasing = true
	_roam_paused = false
	_debug_log("[BOSS] >>> ALERT 100%! MULAI NGEJAR! <<<")

func _move_towards_pos(target_pos: Vector2, speed: float, delta: float) -> void:
	nav_agent.target_position = target_pos

	if nav_agent.is_navigation_finished():
		velocity = Vector2.ZERO
		if state == State.SUSPICIOUS:
			state = State.INVESTIGATING
			_investigate_timer = 2.0
		return

	var next_pos := nav_agent.get_next_path_position()
	var dir := (next_pos - global_position).normalized()
	velocity = dir * speed
	if dir != Vector2.ZERO:
		last_dir = dir

	_update_stuck_check(delta)

func _update_alert_ui() -> void:
	if alert_label == null:
		return

	if alert_level <= 0.0:
		alert_label.text = ""
	elif state == State.CHASE:
		alert_label.text = "!"
		alert_label.add_theme_color_override("font_color", Color.RED)
	elif state == State.INVESTIGATING:
		alert_label.text = "??"
		alert_label.add_theme_color_override("font_color", Color.ORANGE)
	else:
		alert_label.text = "?"
		alert_label.add_theme_color_override("font_color", Color.YELLOW)

func _check_animations() -> void:
	if anim == null or anim.sprite_frames == null:
		print("!! AnimatedSprite2D / SpriteFrames gak ketemu!")
		return

	var missing: Array = []
	for prefix in ["Idle", "Run", "Walk"]:
		for suffix in _all_suffixes():
			var nama: String = str(prefix) + str(suffix)
			if not anim.sprite_frames.has_animation(nama):
				missing.append(nama)

	if missing.is_empty():
		print("OK! Semua 24 animasi boss terdeteksi.")
	else:
		print("Animasi yang gak ada (", missing.size(), "): ", missing)

func _all_suffixes() -> Array:
	return ["_L", "_R", "_up", "_down", "_up_L", "_up_R", "_down_L", "_down_R"]

func _play_animation() -> void:
	if anim == null or anim.sprite_frames == null:
		return

	var moving := velocity.length() > 10.0

	var prefix := "Idle"
	if moving:
		var should_run := can_run and (is_chasing or is_roam_running or velocity.length() >= 130.0)
		prefix = "Run" if should_run else "Walk"

	var suffix := _get_dir_suffix(last_dir)
	var anim_name := prefix + suffix

	if not anim.sprite_frames.has_animation(anim_name):
		for alt in ["Run", "Walk", "Idle"]:
			var alt_name: String = str(alt) + suffix
			if anim.sprite_frames.has_animation(alt_name):
				anim_name = alt_name
				break

	if anim.sprite_frames.has_animation(anim_name):
		if anim.animation != anim_name or not anim.is_playing():
			anim.play(anim_name)

func _get_dir_suffix(dir: Vector2) -> String:
	var y := ""
	var x := ""
	if dir.x < -0.5: x = "L"
	elif dir.x > 0.5: x = "R"
	if dir.y < -0.5: y = "up"
	elif dir.y > 0.5: y = "down"

	if y != "" and x != "":
		return "_" + y + "_" + x
	if x != "":
		return "_" + x
	if y != "":
		return "_" + y
	return "_down"

func _get_player() -> Node2D:
	for group in ["player", "players", "Player"]:
		var nodes := get_tree().get_nodes_in_group(group)
		if not nodes.is_empty():
			return nodes[0] as Node2D
	return null

func _can_see_player(player: Node2D) -> bool:
	var to_player := player.global_position - global_position
	var dist := to_player.length()

	if is_chasing:
		if dist > lose_sight_range:
			return false
	else:
		if dist > vision_range:
			_debug_log("[BOSS] player terlalu jauh: " + str(int(dist)))
			return false
		var angle_deg := absf(rad_to_deg(last_dir.angle_to(to_player)))
		if angle_deg > cone_angle:
			_debug_log("[BOSS] di luar kerucut pandang: sudut " + str(int(angle_deg)))
			return false

	if vision_ray:
		vision_ray.global_rotation = to_player.angle()
		vision_ray.target_position = Vector2(dist, 0)
		vision_ray.force_raycast_update()

		if vision_ray.is_colliding():
			var collider = vision_ray.get_collider()
			if collider == player or (collider != null and collider.is_in_group("player")):
				return true
			_debug_log("[BOSS] pandangan terhalang: " + str(collider.name))
			return false
		return true

	return true

func _roam(delta: float) -> void:
	if _roam_paused:
		velocity = Vector2.ZERO
		return

	if nav_agent.is_navigation_finished():
		velocity = Vector2.ZERO
		_debug_log("[BOSS] roam: gak ada path / udah nyampe (nav mesh kosong?)")
		_pause_then_roam()
		return

	var next_pos := nav_agent.get_next_path_position()
	var dir := (next_pos - global_position).normalized()
	if dir == Vector2.ZERO:
		velocity = Vector2.ZERO
	else:
		var speed := roam_run_speed if (is_roam_running and can_run) else roam_speed
		velocity = dir * speed
		last_dir = dir

	if _is_obstacle_ahead(dir):
		_obstacle_timer += delta
		if _obstacle_timer >= OBSTACLE_REACT_TIME:
			_debug_log("[BOSS] ada collision di depan, langsung reroute")
			_obstacle_timer = 0.0
			velocity = Vector2.ZERO
			_pause_then_roam()
			return
	else:
		_obstacle_timer = 0.0

	_update_stuck_check(delta)

func _is_obstacle_ahead(dir: Vector2) -> bool:
	if obstacle_ray == null or dir == Vector2.ZERO:
		return false
	obstacle_ray.target_position = dir * OBSTACLE_LOOKAHEAD
	obstacle_ray.force_raycast_update()
	if not obstacle_ray.is_colliding():
		return false
	var collider = obstacle_ray.get_collider()
	if collider == null or collider.is_in_group("player"):
		return false
	return true

func _update_stuck_check(delta: float) -> void:
	_stuck_timer += delta
	if _stuck_timer < STUCK_CHECK_TIME:
		return
	_stuck_timer = 0.0

	var moved := global_position.distance_to(_stuck_check_pos)
	_stuck_check_pos = global_position

	if moved < STUCK_DISTANCE:
		_debug_log("[BOSS] macet nabrak collision, ngaso dulu lalu cari jalan baru")
		velocity = Vector2.ZERO
		_pause_then_roam()

func _reset_stuck_tracker() -> void:
	_stuck_timer = 0.0
	_stuck_check_pos = global_position
	_obstacle_timer = 0.0

func _pause_then_roam() -> void:
	if _roam_paused:
		return
	_roam_paused = true
	await get_tree().create_timer(randf_range(roam_pause_min, roam_pause_max)).timeout
	_roam_paused = false
	if state == State.PATROL:
		_pick_roam_target()

func _pick_roam_target() -> void:
	if can_run and roam_run_chance > 0.0:
		is_roam_running = (randf() < roam_run_chance)
	else:
		is_roam_running = false

	if NavigationServer2D.has_method("map_get_random_point"):
		var p: Vector2 = NavigationServer2D.map_get_random_point(
			nav_agent.get_navigation_map(), 1, true)
		if p == Vector2.ZERO:
			push_warning("[BOSS] NAVMESH KOSONG! map_get_random_point selalu balikin (0,0). Cek TileMap Navigation Layer / NavigationRegion2D-nya.")
			return
		nav_agent.target_position = p
		_reset_stuck_tracker()
		if DEBUG:
			print("[BOSS] target roam baru: ", p)
	else:
		var offset := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * 300.0
		nav_agent.target_position = global_position + offset

func _chase(player: Node2D) -> void:
	nav_agent.target_position = player.global_position

	if nav_agent.is_navigation_finished():
		velocity = Vector2.ZERO
		return

	var next_pos := nav_agent.get_next_path_position()
	var dir := (next_pos - global_position).normalized()
	var speed := chase_speed if can_run else chase_speed_walk_only
	velocity = dir * speed
	if dir != Vector2.ZERO:
		last_dir = dir

func _check_player_caught(player: Node2D) -> void:
	if _is_catching_player:
		return
	for i in range(get_slide_collision_count()):
		var collision := get_slide_collision(i)
		var collider := collision.get_collider()
		if collider != null and collider.is_in_group("player"):
			_catch_player()
			return
	if player != null and global_position.distance_to(player.global_position) <= 28.0:
		_catch_player()

func _catch_player() -> void:
	if _is_catching_player:
		return
	var main_node = get_tree().root.get_node_or_null("Main")
	if main_node == null and get_tree().current_scene and get_tree().current_scene.has_method("on_player_caught"):
		main_node = get_tree().current_scene
	if main_node and "is_transitioning" in main_node and main_node.is_transitioning:
		return
	_is_catching_player = true
	velocity = Vector2.ZERO
	_debug_log("[BOSS] PEMAIN TERTANGKAP!")
	if alert_label:
		alert_label.text = "!"
		alert_label.add_theme_color_override("font_color", Color.RED)
	if main_node and main_node.has_method("on_player_caught"):
		main_node.on_player_caught()
	else:
		_standalone_player_caught()

func _standalone_player_caught() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 100
	get_tree().root.add_child(canvas)

	var fade := ColorRect.new()
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.color = Color.BLACK
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.modulate.a = 0.0
	canvas.add_child(fade)

	var tween_out := create_tween()
	tween_out.tween_property(fade, "modulate:a", 1.0, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await tween_out.finished

	var dialog_scene = load("res://Scenes/dialog.tscn")
	if dialog_scene:
		var dialog = dialog_scene.instantiate()
		get_tree().root.add_child(dialog)
		var caught_text := "[color=#ff6b6b]Kamu gagal melarikan diri dan tertangkap oleh Bos![/color]\n\nSelamat menikmati kerja rodi bagai kuda sampai malam! :v"
		dialog.setup_dialog("SI BOS", "Tertangkap!", caught_text, "boss", "[SPASI / ENTER / E] Coba Lagi (Respawn)")
		await dialog.dialog_finished

	canvas.queue_free()
	get_tree().reload_current_scene()
