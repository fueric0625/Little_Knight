class_name Player
extends CharacterBody2D

## 留空时使用 movement_tuning.gd 里的默认值。
## 不要在场景里另存一份参数，否则改脚本不会生效。
@export var tuning: MovementTuning

const LIGHT_SLASH_DIR := "res://art/character/v2/attack/light"
# 碰撞不读贴图。动画帧缩到大约 128 高，脚底落在这条碰撞框的底边。
const BODY_CANVAS := 128.0
const COLLISION_SIZE := Vector2(BODY_CANVAS * 0.78, BODY_CANVAS * 0.9)
const FRAME_TEX := 720.0
# 待机可见高度。走和跑用同一个缩放，避免切换时人物突然变大。
const BODY_SCALE := BODY_CANVAS / (694.0 - 34.0)
const FRAME_SEC := 1.0 / 24.0
# 刀光是 2048 的透明图。挂在图片中心，放在角色身前半格。
const SLASH_TEX := 2048.0
const LIGHT_ANCHOR := Vector2(1024.0, 1024.0)
const LIGHT_SLASH_SCALE := 0.08
const SLASH_FORWARD := BODY_CANVAS * 0.5
const CLIP_DIR := {
	"idle": "res://art/character/v2/Idle/frames",
	"walk": "res://art/character/v2/walk/frames",
	"run": "res://art/character/v2/run/selected",
	"jump_air": "res://art/character/v2/jump/air",
	"jump_land": "res://art/character/v2/jump/land",
	"jump_lean": "res://art/character/v2/jump_up/selected",
	"dash": "res://art/character/v2/dash",
}
# 待机、走、跑各用一个身体中线和脚底。跳跃按每一帧自己的脚钉住，避免画布里的升降再叠一次。
const CLIP_MID_X := {"idle": 396.0, "walk": 364.0, "run": 299.0}
const CLIP_FOOT_Y := {"idle": 694.0, "walk": 701.0, "run": 690.0}
const JUMP_TEX_H := 752.0
# 空中第 24 帧是第 0 张，第 40 帧是最高点。
const JUMP_AIR_APEX := 16
const LAND_SEC := 0.2
const JUMP_AIR_MID := [
	395.5, 395.4, 388.4, 386.7, 387.1, 386.1, 385.6, 384.5, 382.9, 382.9,
	382.6, 380.1, 380.2, 380.2, 377.2, 377.0, 377.1, 376.4, 376.3, 375.7,
	375.3, 375.2, 375.3, 373.9, 374.1, 374.2, 373.2, 373.1, 373.1, 373.2,
	373.1, 372.8, 373.3, 373.1, 373.3, 373.2, 373.3, 373.4, 373.2,
]
const JUMP_AIR_FOOT := [
	669, 669, 595, 583, 582, 578, 574, 569, 566, 566,
	565, 562, 562, 562, 560, 560, 560, 561, 561, 562,
	564, 564, 564, 568, 569, 569, 579, 580, 581, 590,
	591, 595, 609, 610, 611, 661, 661, 661, 705,
]
const JUMP_LAND_MID := [
	372.8, 373.0, 374.4, 375.0, 375.9, 379.6, 379.6, 379.8, 382.6, 382.7,
	382.8, 382.7, 382.7, 383.0, 382.0, 381.9, 381.8, 382.5, 382.4, 383.0,
	385.0, 385.2, 385.1, 386.8, 386.8, 387.0, 387.7, 387.6,
]
const JUMP_LAND_FOOT := [
	725, 726, 728, 728, 728, 728, 728, 728, 728, 728,
	728, 728, 728, 728, 728, 728, 728, 728, 728, 728,
	728, 728, 728, 728, 728, 728, 728, 728,
]
# 侧面跃起只停在已经摆开的最后一帧。
const JUMP_LEAN_MID := 359.0
const JUMP_LEAN_FOOT := 588.0
# 冲刺是一张 2048 的单帧。缩到和待机一样高，身体中线对齐碰撞盒，披风留在身后。
const DASH_TEX := 2048.0
const DASH_MID := 1190.0
const DASH_FOOT := 1797.0
const DASH_SCALE := BODY_CANVAS / (DASH_FOOT - 48.0)

enum AttackPhase { NONE, STARTUP, ACTIVE, RECOVERY }

@onready var sprite: Sprite2D = $Sprite
@onready var weapon: Sprite2D = $Weapon
@onready var collision: CollisionShape2D = $Collision
@onready var debug_label: Label = $DebugLayer/DebugLabel

const SEC_TO_MS := 1000.0

var facing := 1.0
# 计时都是毫秒，和 movement_tuning.gd 一致。
var coyote_timer := 0.0
var jump_buffer_timer := 0.0
var dash_timer := 0.0
var dash_cooldown_timer := 0.0
var pending_land_refresh := false
var air_jumps_left := 0
var attack_phase := AttackPhase.NONE
var attack_time_left := 0.0
var spawn_position := Vector2.ZERO
var fall_limit := 100000.0
var body_scale := BODY_SCALE
var clips: Dictionary = {}
var current_clip := "idle"
var frame_time := 0.0
var frame_index := 0
var wants_walk := false
var jump_anim := false
var land_anim := false
var air_dash := false
var light_slash_frames: Array[Texture2D] = []
var jump_time := 0.0
var land_time := 0.0
var fall_time := 0.0
# 这一跳从离地到最高点的时间。空中动画用两倍时长，下落和上升一样长。
var jump_rise_sec := 0.53


func _ready() -> void:
	if tuning == null:
		tuning = MovementTuning.new()
	air_jumps_left = tuning.air_jumps
	_apply_collision()
	_load_clips()
	weapon.visible = false
	_set_clip("idle")
	_setup_debug_font()


func configure_spawn(pos: Vector2, limit_y: float) -> void:
	spawn_position = pos
	fall_limit = limit_y
	global_position = pos
	velocity = Vector2.ZERO


func _physics_process(delta: float) -> void:
	_tick_timers(delta)

	var move := Input.get_axis("move_left", "move_right")
	var jump_pressed := Input.is_action_just_pressed("jump")
	var jump_released := Input.is_action_just_released("jump")
	var dash_pressed := Input.is_action_just_pressed("dash")
	var light_pressed := Input.is_action_just_pressed("attack_light")

	if jump_pressed:
		jump_buffer_timer = tuning.jump_buffer_ms

	var dashing := dash_timer > 0.0
	wants_walk = Input.is_action_pressed("move_walk") and not dashing
	if not dashing and attack_phase == AttackPhase.NONE and move != 0.0:
		facing = signf(move)

	if not dashing and dash_pressed and dash_cooldown_timer <= 0.0 and _dash_allowed():
		if attack_phase != AttackPhase.NONE:
			_end_attack()
		dash_timer = tuning.dash_ms
		dashing = true
		air_dash = not is_on_floor()
		jump_anim = false
		land_anim = false

	if dashing:
		velocity = Vector2(tuning.dash_speed * facing, 0.0)
		var on_floor_before := is_on_floor()
		move_and_slide()
		_resolve_floor(on_floor_before, false)
		dash_timer -= delta * SEC_TO_MS
		if dash_timer <= 0.0:
			dash_timer = 0.0
			_finish_dash()
	else:
		if light_pressed:
			_try_start_attack()

		var attacking := attack_phase != AttackPhase.NONE
		var move_speed := tuning.walk_speed if wants_walk else tuning.run_speed
		velocity.x = move * move_speed
		if land_anim and absf(velocity.x) > 1.0:
			land_anim = false
		if is_on_floor():
			if velocity.y > 0.0:
				velocity.y = 0.0
		else:
			velocity.y += tuning.gravity * delta
			velocity.y = minf(velocity.y, tuning.max_fall_speed)

		# 攻击中不起新跳。
		if not attacking and jump_buffer_timer > 0.0 and (is_on_floor() or coyote_timer > 0.0):
			velocity.y = tuning.jump_velocity
			coyote_timer = 0.0
			jump_buffer_timer = 0.0
			_begin_jump_anim(tuning.jump_velocity)
		elif not attacking and jump_buffer_timer > 0.0 and not is_on_floor() and air_jumps_left > 0:
			velocity.y = tuning.air_jump_velocity
			air_jumps_left -= 1
			jump_buffer_timer = 0.0
			_begin_jump_anim(tuning.air_jump_velocity)

		if jump_released and velocity.y < 0.0:
			velocity.y *= tuning.jump_cut_multiplier

		var on_floor_before := is_on_floor()
		move_and_slide()
		_resolve_floor(on_floor_before, true)

	_tick_attack(delta)
	_post_frame(delta)


func _tick_timers(delta: float) -> void:
	var step := delta * SEC_TO_MS
	coyote_timer = maxf(coyote_timer - step, 0.0)
	jump_buffer_timer = maxf(jump_buffer_timer - step, 0.0)
	if dash_timer <= 0.0:
		dash_cooldown_timer = maxf(dash_cooldown_timer - step, 0.0)


func _resolve_floor(on_floor_before: bool, allow_coyote: bool) -> void:
	var on_floor := is_on_floor()
	if on_floor_before and not on_floor and allow_coyote and velocity.y >= 0.0:
		coyote_timer = tuning.coyote_ms
	elif on_floor:
		coyote_timer = 0.0
		air_jumps_left = tuning.air_jumps
		if jump_anim and velocity.y >= 0.0:
			jump_anim = false
			if absf(velocity.x) <= 1.0:
				land_anim = true
				land_time = 0.0

	if not on_floor_before and on_floor and tuning.refresh_dash_on_land:
		if dash_timer > 0.0:
			pending_land_refresh = true
		else:
			dash_cooldown_timer = 0.0


func _finish_dash() -> void:
	if pending_land_refresh and tuning.refresh_dash_on_land:
		dash_cooldown_timer = 0.0
	else:
		dash_cooldown_timer = tuning.dash_cooldown_ms
	pending_land_refresh = false
	# 冲刺把垂直速度清成 0，结束后只有重力，不会再上升。
	if air_dash and not is_on_floor():
		jump_anim = true
		fall_time = 0.0
		jump_time = jump_rise_sec
	air_dash = false


func _post_frame(delta: float) -> void:
	if global_position.y > fall_limit:
		_respawn()
	_update_sprite(delta)
	_update_debug()


func _respawn() -> void:
	global_position = spawn_position
	velocity = Vector2.ZERO
	dash_timer = 0.0
	dash_cooldown_timer = 0.0
	coyote_timer = 0.0
	jump_buffer_timer = 0.0
	pending_land_refresh = false
	air_jumps_left = tuning.air_jumps
	jump_anim = false
	land_anim = false
	air_dash = false
	fall_time = 0.0
	_end_attack()


func _load_clips() -> void:
	for clip_name in CLIP_DIR:
		clips[clip_name] = _load_frames(CLIP_DIR[clip_name])
	light_slash_frames = _load_frames(LIGHT_SLASH_DIR)


func _load_frames(dir_path: String) -> Array[Texture2D]:
	var frames: Array[Texture2D] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_error("打不开动画目录 %s" % dir_path)
		return frames
	var names: PackedStringArray = []
	for file_name in dir.get_files():
		if file_name.ends_with(".png"):
			names.append(file_name)
	names.sort()
	for file_name in names:
		var texture := load(dir_path.path_join(file_name)) as Texture2D
		if texture != null:
			frames.append(texture)
	if frames.is_empty():
		push_error("动画目录没有可用帧 %s" % dir_path)
	return frames


func _begin_jump_anim(jump_velocity: float) -> void:
	jump_anim = true
	land_anim = false
	jump_time = 0.0
	land_time = 0.0
	fall_time = 0.0
	jump_rise_sec = absf(jump_velocity) / tuning.gravity


func _set_clip(clip_name: String) -> void:
	frame_time = 0.0
	_show_frame(clip_name, 0)


func _apply_collision() -> void:
	var shape := RectangleShape2D.new()
	shape.size = COLLISION_SIZE
	collision.shape = shape
	collision.position = Vector2(0.0, (BODY_CANVAS - COLLISION_SIZE.y) * 0.5)


func _try_start_attack() -> void:
	# 冲刺途中攻击留到取消规则单独看过之后再加。
	if attack_phase != AttackPhase.NONE or dash_timer > 0.0:
		return
	attack_phase = AttackPhase.STARTUP
	attack_time_left = _attack_duration(AttackPhase.STARTUP)
	land_anim = false


func _end_attack() -> void:
	attack_phase = AttackPhase.NONE
	attack_time_left = 0.0


func _dash_allowed() -> bool:
	if attack_phase == AttackPhase.NONE:
		return true
	if attack_phase != AttackPhase.RECOVERY:
		return false
	return _recovery_elapsed() < _dash_cancel_window()


func _dash_cancel_window() -> float:
	return _attack_duration(AttackPhase.RECOVERY)


func _recovery_elapsed() -> float:
	return _attack_duration(AttackPhase.RECOVERY) - attack_time_left


func _tick_attack(delta: float) -> void:
	if attack_phase == AttackPhase.NONE:
		return
	attack_time_left -= delta * SEC_TO_MS
	while attack_time_left <= 0.0 and attack_phase != AttackPhase.NONE:
		var overflow := -attack_time_left
		match attack_phase:
			AttackPhase.STARTUP:
				attack_phase = AttackPhase.ACTIVE
				attack_time_left = _attack_duration(AttackPhase.ACTIVE) - overflow
			AttackPhase.ACTIVE:
				attack_phase = AttackPhase.RECOVERY
				attack_time_left = _attack_duration(AttackPhase.RECOVERY) - overflow
			_:
				attack_phase = AttackPhase.NONE
				attack_time_left = 0.0


func _attack_duration(phase: AttackPhase) -> float:
	match phase:
		AttackPhase.STARTUP:
			return tuning.light_startup_ms
		AttackPhase.ACTIVE:
			return tuning.light_active_ms
		AttackPhase.RECOVERY:
			return tuning.light_recovery_ms
		_:
			return 0.0


func _attack_force() -> float:
	return tuning.light_force


# 出手时前几帧走得快，这一段结束就画到完整刀光。后摇一直停在最后一帧。
func _light_slash_frame() -> int:
	var count := light_slash_frames.size()
	if count <= 1:
		return 0
	var shown := 0.0
	if attack_phase == AttackPhase.ACTIVE:
		shown = tuning.light_active_ms - attack_time_left
	elif attack_phase == AttackPhase.RECOVERY:
		shown = tuning.light_active_ms + (tuning.light_recovery_ms - attack_time_left)
	var grow := tuning.light_active_ms
	var u := clampf(shown / grow, 0.0, 1.0)
	var t := pow(u, 0.55)
	return mini(int(t * float(count)), count - 1)


func _update_sprite(delta: float) -> void:
	if jump_anim:
		jump_time += delta
		if velocity.y >= 0.0:
			fall_time += delta
	if land_anim and not is_on_floor():
		land_anim = false
	if land_anim:
		land_time += delta
	var clip_name := _clip_name()
	if clip_name != current_clip and not clip_name.begins_with("jump"):
		frame_time = 0.0
	var index := _frame_index_for(clip_name, delta)
	if clip_name != current_clip or index != frame_index:
		_show_frame(clip_name, index)
	if land_anim and land_time >= LAND_SEC:
		land_anim = false
	sprite.flip_h = facing < 0.0
	sprite.scale = Vector2(body_scale, body_scale)
	_update_slash()


func _clip_name() -> String:
	if dash_timer > 0.0:
		return "dash"
	if land_anim:
		return "jump_land"
	if jump_anim and not is_on_floor():
		# 侧面跃起没有下落。上升时用它，一开始下落就回到 jump 的下落帧。
		if absf(velocity.x) > 1.0 and velocity.y < 0.0:
			return "jump_lean"
		return "jump_air"
	if absf(velocity.x) > 1.0 and not wants_walk:
		return "run"
	if absf(velocity.x) > 1.0:
		return "walk"
	return "idle"


func _frame_index_for(clip_name: String, delta: float) -> int:
	var frames: Array = clips[clip_name]
	var count := frames.size()
	if count <= 1:
		return 0
	if clip_name == "jump_lean":
		return count - 1
	if clip_name == "jump_air":
		return _air_frame_index(count)
	if clip_name == "jump_land":
		var along := clampf(land_time / LAND_SEC, 0.0, 0.999)
		return mini(int(along * float(count)), count - 1)
	frame_time += delta
	return int(frame_time / FRAME_SEC) % count


func _air_frame_index(count: int) -> int:
	var rise := jump_rise_sec if jump_rise_sec > 0.0 else 0.53
	var apex := mini(JUMP_AIR_APEX, count - 1)
	if velocity.y < 0.0:
		if jump_time >= rise:
			return apex
		return mini(int(jump_time / rise * float(apex + 1)), apex)
	var tail := count - apex
	var along := fall_time / rise
	if along >= 1.0:
		return count - 1
	return mini(apex + int(along * float(tail)), count - 1)


func _show_frame(clip_name: String, index: int) -> void:
	current_clip = clip_name
	var frames: Array = clips[clip_name]
	if frames.is_empty():
		frame_index = 0
		return
	frame_index = clampi(index, 0, frames.size() - 1)
	sprite.texture = frames[frame_index]
	_place_shown(clip_name, frame_index)


func _place_shown(clip_name: String, index: int) -> void:
	body_scale = DASH_SCALE if clip_name == "dash" else BODY_SCALE
	if clip_name == "jump_air":
		_place_body(JUMP_AIR_MID[index], JUMP_AIR_FOOT[index], FRAME_TEX, JUMP_TEX_H)
	elif clip_name == "jump_land":
		_place_body(JUMP_LAND_MID[index], JUMP_LAND_FOOT[index], FRAME_TEX, JUMP_TEX_H)
	elif clip_name == "jump_lean":
		_place_body(JUMP_LEAN_MID, JUMP_LEAN_FOOT, FRAME_TEX, FRAME_TEX)
	elif clip_name == "dash":
		_place_body(DASH_MID, DASH_FOOT, DASH_TEX, DASH_TEX)
	else:
		_place_body(CLIP_MID_X[clip_name], CLIP_FOOT_Y[clip_name], FRAME_TEX, FRAME_TEX)


func _place_body(mid_x: float, foot_y: float, tex_w: float, tex_h: float) -> void:
	sprite.offset = Vector2(tex_w * 0.5 - mid_x, 0.0)
	var foot_local := (foot_y - tex_h * 0.5) * body_scale
	sprite.position = Vector2(0.0, BODY_CANVAS * 0.5 - foot_local)


func _update_slash() -> void:
	var swinging := attack_phase == AttackPhase.ACTIVE or attack_phase == AttackPhase.RECOVERY
	weapon.visible = swinging
	if not swinging or light_slash_frames.is_empty():
		weapon.visible = false
		return
	weapon.rotation = 0.0
	weapon.z_index = 1
	weapon.texture = light_slash_frames[_light_slash_frame()]
	# 横向缩放的正负绕图片中心翻转，弧线鼓向面朝的一侧。
	weapon.scale = Vector2(LIGHT_SLASH_SCALE * facing, LIGHT_SLASH_SCALE)
	weapon.offset = Vector2(SLASH_TEX * 0.5 - LIGHT_ANCHOR.x, SLASH_TEX * 0.5 - LIGHT_ANCHOR.y)
	weapon.flip_h = false
	weapon.position = Vector2(SLASH_FORWARD * facing, 0.0)


func _setup_debug_font() -> void:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "Segoe UI"])
	debug_label.add_theme_font_override("font", font)


func _update_debug() -> void:
	debug_label.text = "\n".join([
		"状态: %s" % _state_name(),
		"动画: %s %d" % [current_clip, frame_index + 1],
		"速度: %.0f, %.0f" % [velocity.x, velocity.y],
		"着地: %s" % ("是" if is_on_floor() else "否"),
		"郊狼: %.0f ms" % coyote_timer,
		"跳跃缓冲: %.0f ms" % jump_buffer_timer,
		"冲刺剩余: %.0f ms" % dash_timer,
		"冲刺冷却: %.0f ms" % dash_cooldown_timer,
		"连跳: %d" % air_jumps_left,
		"攻击: %s" % _attack_name(),
	])
	if attack_phase == AttackPhase.RECOVERY:
		var cancel_left := maxf(_dash_cancel_window() - _recovery_elapsed(), 0.0)
		if cancel_left > 0.0:
			debug_label.text += "\n冲刺取消: 剩余 %.0f ms" % cancel_left
		else:
			debug_label.text += "\n冲刺取消: 已过"
	if attack_phase == AttackPhase.ACTIVE:
		var force := _attack_force()
		var self_speed := HitKnockback.speed(force, tuning.player_mass)
		var enemy_speed := HitKnockback.speed(force, tuning.sample_enemy_mass)
		debug_label.text += "\n命中击退: 自己 %.0f px/s，重量 %.1f 的敌人 %.0f px/s" % [
			self_speed, tuning.sample_enemy_mass, enemy_speed,
		]


func _state_name() -> String:
	if dash_timer > 0.0:
		return "冲刺"
	if not is_on_floor():
		return "上升" if velocity.y < 0.0 else "下落"
	if absf(velocity.x) > 1.0:
		return "走" if wants_walk else "跑"
	return "待机"


func _attack_name() -> String:
	if attack_phase == AttackPhase.NONE:
		return "无"
	var kind := "轻击"
	match attack_phase:
		AttackPhase.STARTUP:
			return kind + "前摇"
		AttackPhase.ACTIVE:
			return kind + "出手"
		_:
			return kind + "后摇"
