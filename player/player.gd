class_name Player
extends CharacterBody2D

## 留空时使用 movement_tuning.gd 里的默认值。
## 不要在场景里另存一份参数，否则改脚本不会生效。
@export var tuning: MovementTuning

const LIGHT_WEAPON := preload("res://art/weapon_axe.png")
const HEAVY_WEAPON := preload("res://art/weapon_axe_double.png")
const WEAPON_OFFSET := 72.0

enum AttackKind { LIGHT, HEAVY }
enum AttackPhase { NONE, STARTUP, ACTIVE, RECOVERY }

@onready var sprite: Sprite2D = $Sprite
@onready var weapon: Sprite2D = $Weapon
@onready var collision: CollisionShape2D = $Collision
@onready var debug_label: Label = $DebugLayer/DebugLabel

var facing := 1.0
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


func _ready() -> void:
	if tuning == null:
		tuning = MovementTuning.new()
	air_jumps_left = tuning.air_jumps
	_fit_collision()
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
		jump_buffer_timer = tuning.jump_buffer_time

	var dashing := dash_timer > 0.0
	if not dashing and move != 0.0:
		facing = signf(move)

	if not dashing and dash_pressed and dash_cooldown_timer <= 0.0:
		dash_timer = tuning.dash_duration
		dashing = true

	if dashing:
		velocity = Vector2(tuning.dash_speed * facing, 0.0)
		var on_floor_before := is_on_floor()
		move_and_slide()
		_resolve_floor(on_floor_before, false)
		dash_timer -= delta
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
			velocity.x = move * tuning.run_speed
			if is_on_floor():
				if velocity.y > 0.0:
					velocity.y = 0.0
			else:
				velocity.y += tuning.gravity * delta
				velocity.y = minf(velocity.y, tuning.max_fall_speed)

			if jump_buffer_timer > 0.0 and (is_on_floor() or coyote_timer > 0.0):
				velocity.y = tuning.jump_velocity
				coyote_timer = 0.0
				jump_buffer_timer = 0.0
			elif jump_buffer_timer > 0.0 and not is_on_floor() and air_jumps_left > 0:
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
	coyote_timer = maxf(coyote_timer - delta, 0.0)
	jump_buffer_timer = maxf(jump_buffer_timer - delta, 0.0)
	if dash_timer <= 0.0:
		dash_cooldown_timer = maxf(dash_cooldown_timer - delta, 0.0)


func _resolve_floor(on_floor_before: bool, allow_coyote: bool) -> void:
	var on_floor := is_on_floor()
	if on_floor_before and not on_floor and allow_coyote and velocity.y >= 0.0:
		coyote_timer = tuning.coyote_time
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
		dash_cooldown_timer = tuning.dash_cooldown
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
	attack_phase = AttackPhase.NONE
	attack_time_left = 0.0


func _fit_collision() -> void:
	var tex_size := sprite.texture.get_size()
	var shape := RectangleShape2D.new()
	# 左右多收一点，避开图片上的黑边，减少卡在砖缝里的情况。脚底和图片底对齐。
	shape.size = Vector2(tex_size.x * 0.78, tex_size.y * 0.9)
	collision.shape = shape
	collision.position = Vector2(0.0, (tex_size.y - shape.size.y) * 0.5)


func _try_start_attack(kind: AttackKind) -> void:
	if attack_phase != AttackPhase.NONE or dash_timer > 0.0:
		return
	attack_kind = kind
	attack_phase = AttackPhase.STARTUP
	attack_time_left = _attack_duration(AttackPhase.STARTUP)


func _tick_attack(delta: float) -> void:
	if attack_phase == AttackPhase.NONE:
		return
	attack_time_left -= delta
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
			return tuning.heavy_startup if heavy else tuning.light_startup
		AttackPhase.ACTIVE:
			return tuning.heavy_active if heavy else tuning.light_active
		AttackPhase.RECOVERY:
			return tuning.heavy_recovery if heavy else tuning.light_recovery
		_:
			return 0.0


func _is_air_heavy() -> bool:
	return attack_phase != AttackPhase.NONE and attack_kind == AttackKind.HEAVY and not is_on_floor()


func _attack_force() -> float:
	return tuning.heavy_force if attack_kind == AttackKind.HEAVY else tuning.light_force


func _update_sprite() -> void:
	sprite.flip_h = facing < 0.0
	if dash_timer > 0.0:
		sprite.scale = Vector2(1.18, 0.92)
	else:
		sprite.scale = Vector2.ONE
	_update_weapon()


func _update_weapon() -> void:
	var air_slam := _is_air_heavy() and attack_phase != AttackPhase.RECOVERY
	var swinging := attack_phase == AttackPhase.ACTIVE or air_slam
	weapon.visible = swinging
	if not swinging:
		weapon.rotation = 0.0
		return
	weapon.texture = HEAVY_WEAPON if attack_kind == AttackKind.HEAVY else LIGHT_WEAPON
	if air_slam:
		weapon.flip_h = false
		weapon.rotation = PI / 2.0
		weapon.position = Vector2(0.0, WEAPON_OFFSET)
	else:
		weapon.flip_h = facing < 0.0
		weapon.rotation = 0.0
		weapon.position = Vector2(WEAPON_OFFSET * facing, 8.0)
	var body_height := sprite.texture.get_size().y
	var weapon_height := weapon.texture.get_size().y
	if weapon_height > body_height * 1.15:
		var fitted := body_height * 0.7 / weapon_height
		weapon.scale = Vector2(fitted, fitted)
	else:
		weapon.scale = Vector2.ONE


func _setup_debug_font() -> void:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "Segoe UI"])
	debug_label.add_theme_font_override("font", font)


func _update_debug() -> void:
	debug_label.text = "\n".join([
		"状态: %s" % _state_name(),
		"速度: %.0f, %.0f" % [velocity.x, velocity.y],
		"着地: %s" % ("是" if is_on_floor() else "否"),
		"郊狼: %.3f s" % coyote_timer,
		"跳跃缓冲: %.3f s" % jump_buffer_timer,
		"冲刺剩余: %.3f s" % dash_timer,
		"冲刺冷却: %.3f s" % dash_cooldown_timer,
		"连跳: %d" % air_jumps_left,
		"攻击: %s" % _attack_name(),
	])
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
