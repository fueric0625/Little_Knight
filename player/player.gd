class_name Player
extends CharacterBody2D

## 留空时使用 movement_tuning.gd 里的默认值。
## 不要在场景里另存一份参数，否则改脚本不会生效。
@export var tuning: MovementTuning

const BODY_TEXTURE := preload("res://art/character/character_Idle_Right_NoWeapon.png")
const SWORD_TEXTURE := preload("res://art/character/weapon_Sword.png")
# 碰撞不读贴图。角色图缩到大约 128 高，脚底落在这条碰撞框的底边。
const BODY_CANVAS := 128.0
const COLLISION_SIZE := Vector2(BODY_CANVAS * 0.78, BODY_CANVAS * 0.9)
# 下面的像素是从 2880 导出图上量的不透明范围。
const BODY_TEX := 2880.0
const BODY_TOP := 184.0
const BODY_FOOT := 2728.0
const BODY_MID_X := 1526.0
const SWORD_GRIP_Y := 2260.0

enum AttackKind { LIGHT, HEAVY }
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
var attack_kind := AttackKind.LIGHT
var attack_phase := AttackPhase.NONE
var attack_time_left := 0.0
var spawn_position := Vector2.ZERO
var fall_limit := 100000.0
var body_scale := 1.0


func _ready() -> void:
	if tuning == null:
		tuning = MovementTuning.new()
	air_jumps_left = tuning.air_jumps
	_apply_collision()
	_fit_character_art()
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
	var heavy_pressed := Input.is_action_just_pressed("attack_heavy")

	if jump_pressed:
		jump_buffer_timer = tuning.jump_buffer_ms

	var dashing := dash_timer > 0.0
	if not dashing and attack_phase == AttackPhase.NONE and move != 0.0:
		facing = signf(move)

	if not dashing and dash_pressed and dash_cooldown_timer <= 0.0 and _dash_allowed():
		if attack_phase != AttackPhase.NONE:
			_end_attack()
		dash_timer = tuning.dash_ms
		dashing = true

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
			_try_start_attack(AttackKind.LIGHT)
		elif heavy_pressed:
			_try_start_attack(AttackKind.HEAVY)

		if _is_air_heavy():
			velocity = Vector2(0.0, tuning.heavy_air_drop_speed)
		else:
			var attacking := attack_phase != AttackPhase.NONE
			# 只有站在地上的攻击锁水平速度。空中轻击沿用原来的空中移动，不把跳跃的水平速度清掉。
			if attacking and is_on_floor():
				velocity.x = 0.0
			else:
				velocity.x = move * tuning.run_speed
			if is_on_floor():
				if velocity.y > 0.0:
					velocity.y = 0.0
			else:
				velocity.y += tuning.gravity * delta
				velocity.y = minf(velocity.y, tuning.max_fall_speed)

			# 攻击中不起新跳。地面重击一离地就会变成空中下砸。
			if not attacking and jump_buffer_timer > 0.0 and (is_on_floor() or coyote_timer > 0.0):
				velocity.y = tuning.jump_velocity
				coyote_timer = 0.0
				jump_buffer_timer = 0.0
			elif not attacking and jump_buffer_timer > 0.0 and not is_on_floor() and air_jumps_left > 0:
				velocity.y = tuning.air_jump_velocity
				air_jumps_left -= 1
				jump_buffer_timer = 0.0

			if jump_released and velocity.y < 0.0:
				velocity.y *= tuning.jump_cut_multiplier

		var on_floor_before := is_on_floor()
		move_and_slide()
		_resolve_floor(on_floor_before, true)

	_tick_attack(delta)
	_post_frame()


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


func _post_frame() -> void:
	if global_position.y > fall_limit:
		_respawn()
	_update_sprite()
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
	_end_attack()


func _fit_character_art() -> void:
	sprite.texture = BODY_TEXTURE
	body_scale = BODY_CANVAS / (BODY_FOOT - BODY_TOP)
	sprite.offset = Vector2(BODY_TEX * 0.5 - BODY_MID_X, 0.0)
	var foot_local := (BODY_FOOT - BODY_TEX * 0.5) * body_scale
	sprite.position = Vector2(0.0, BODY_CANVAS * 0.5 - foot_local)
	weapon.texture = SWORD_TEXTURE
	weapon.scale = Vector2(body_scale, body_scale)
	# 旋转中心放在剑柄，而不是画布中心。
	weapon.offset = Vector2(0.0, BODY_TEX * 0.5 - SWORD_GRIP_Y)


func _apply_collision() -> void:
	var shape := RectangleShape2D.new()
	shape.size = COLLISION_SIZE
	collision.shape = shape
	collision.position = Vector2(0.0, (BODY_CANVAS - COLLISION_SIZE.y) * 0.5)


func _try_start_attack(kind: AttackKind) -> void:
	# 冲刺途中攻击留到取消规则单独看过之后再加。
	if attack_phase != AttackPhase.NONE or dash_timer > 0.0:
		return
	attack_kind = kind
	attack_phase = AttackPhase.STARTUP
	attack_time_left = _attack_duration(AttackPhase.STARTUP)


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
	if attack_kind == AttackKind.HEAVY:
		return tuning.heavy_dash_cancel_ms
	return _attack_duration(AttackPhase.RECOVERY)


func _recovery_elapsed() -> float:
	return _attack_duration(AttackPhase.RECOVERY) - attack_time_left


func _recovery_pose_split() -> float:
	var recovery := _attack_duration(AttackPhase.RECOVERY)
	if attack_kind == AttackKind.HEAVY:
		return minf(tuning.heavy_dash_cancel_ms, recovery)
	return recovery * 0.5


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
	var heavy := attack_kind == AttackKind.HEAVY
	match phase:
		AttackPhase.STARTUP:
			return tuning.heavy_startup_ms if heavy else tuning.light_startup_ms
		AttackPhase.ACTIVE:
			return tuning.heavy_active_ms if heavy else tuning.light_active_ms
		AttackPhase.RECOVERY:
			return tuning.heavy_recovery_ms if heavy else tuning.light_recovery_ms
		_:
			return 0.0


func _is_air_heavy() -> bool:
	return attack_phase != AttackPhase.NONE and attack_kind == AttackKind.HEAVY and not is_on_floor()


func _attack_force() -> float:
	return tuning.heavy_force if attack_kind == AttackKind.HEAVY else tuning.light_force


func _update_sprite() -> void:
	sprite.flip_h = facing < 0.0
	if dash_timer > 0.0:
		sprite.scale = Vector2(body_scale * 1.18, body_scale * 0.92)
	else:
		sprite.scale = Vector2(body_scale, body_scale)
	_update_weapon()


func _update_weapon() -> void:
	var grip := Vector2(26.0, -18.0)
	var angle := PI * 1.2
	var in_front := false
	if _is_air_heavy() and attack_phase != AttackPhase.RECOVERY:
		grip = Vector2(8.0, 24.0)
		angle = PI
		in_front = true
	elif attack_phase != AttackPhase.NONE:
		in_front = true
		match attack_phase:
			AttackPhase.STARTUP:
				grip = Vector2(-6.0, -10.0)
				angle = -PI * 0.55
			AttackPhase.ACTIVE:
				grip = Vector2(18.0, 4.0)
				angle = PI * 0.5
			_:
				if _recovery_elapsed() < _recovery_pose_split():
					grip = Vector2(16.0, 20.0)
					angle = PI * 0.85
				else:
					grip = Vector2(8.0, -4.0)
					angle = PI * 0.2
	weapon.visible = true
	weapon.z_index = 1 if in_front else -1
	weapon.flip_h = facing < 0.0
	weapon.position = Vector2(grip.x * facing, grip.y)
	weapon.rotation = angle * facing


func _setup_debug_font() -> void:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "Segoe UI"])
	debug_label.add_theme_font_override("font", font)


func _update_debug() -> void:
	debug_label.text = "\n".join([
		"状态: %s" % _state_name(),
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
		return "跑"
	return "待机"


func _attack_name() -> String:
	if attack_phase == AttackPhase.NONE:
		return "无"
	var kind := "重击" if attack_kind == AttackKind.HEAVY else "轻击"
	match attack_phase:
		AttackPhase.STARTUP:
			return kind + "前摇"
		AttackPhase.ACTIVE:
			return kind + "出手"
		_:
			return kind + "后摇"
