extends CharacterBody2D

@export var move_speed: float = 70.0
@export var dodge_speed: float = 110.0
@export var dodge_duration: float = 0.5
@export var dodge_cooldown: float = 0.4
@export var jump_duration: float = 0.35
@export var jump_move_factor: float = 0.25

@export_group("Stun")
@export var stun_duration: float = 0.4
@export var stun_knockback_speed: float = 120.0

@export_group("Mount")
@export var mounted_speed: float = 100.0
@export var summon_duration: float = 2.0

enum State { IDLE, MOVE, DODGE, JUMP, ATTACK, STUN, DEAD }

var state: State = State.IDLE
var facing: String = "down"
var dodge_facing: String = "down"
var invincible: bool = false
var attack_anim_name: String = ""
var mounted: bool = false

var _dodge_timer: float = 0.0
var _dodge_cooldown_timer: float = 0.0
var _dodge_direction: Vector2 = Vector2.ZERO
var _stun_timer: float = 0.0
var _stun_direction: Vector2 = Vector2.ZERO
var _jump_timer: float = 0.0
var _jump_direction: Vector2 = Vector2.ZERO
var _jump_start_speed: float = 0.0
var _attack_timer: float = 0.0
var _sword_combo_step: int = 0
var _combo_window_timer: float = 0.0
var _queued_combo: bool = false
var _weapon_hidden_this_swing: bool = false
var _bow_shoot_timer: float = 0.0
var _bow_shot_fired: bool = false
var _bow_charging: bool = false
var _bow_charge_time: float = 0.0
var _bow_original_char_pos: Vector2 = Vector2.ZERO
var _bow_original_weap_pos: Vector2 = Vector2.ZERO
var _fishing_casting: bool = false
var _fishing_reeling: bool = false

const COMBO_WINDOW: float = 0.4
const BOW_RELEASE_TIME: float = 0.3
const BOW_MAX_CHARGE: float = 2.5
const BOW_SHAKE_START: float = 0.8
const BOW_SHAKE_MAX: float = 0.8
const SWORD_COMBO_MAX: int = 3
const WEAPON_HIDE_BEFORE_END: float = 0.1
const FOOTSTEP_INTERVAL: float = 0.3
const GRASS_STEP_INTERVAL: float = 0.25

var _input_mgr: Node
var _base_collision_layer: int = 0
var _base_collision_mask: int = 0
var _player_hitbox: CollisionShape2D
var _toolbar: Node
var _anim_player: AnimationPlayer
var _character_node: Node2D
var _weapons_node: Node2D
var _sword_node: Node2D
var _tools_node: Node2D
var _bow_node: Node2D
var _fishing_rod_node: Node2D
var _sword_hitboxes: Dictionary = {}
var _tool_hitboxes: Dictionary = {}
var _audio: Node
var _fx: Node2D
var _health: Node
var _health_ui: CanvasLayer
var _game_over_ui: CanvasLayer
var _footstep_timer: float = 0.0
var _grass_step_timer: float = 0.0
var _iframe_flash_timer: float = 0.0
var _knockback_velocity: Vector2 = Vector2.ZERO
var _spawn_position: Vector2 = Vector2.ZERO
var _debug_collisions: bool = false
var _collect_area: Area2D
var _magnet_targets: Array = []

# ── Mount ────────────────────────────────────────────────────────────
var _summoning: bool = false
var _summon_timer: float = 0.0
var _mount_node: Node2D
const SUMMON_BAR_WIDTH: float = 20.0
const SUMMON_BAR_HEIGHT: float = 3.0
const SUMMON_BAR_Y_OFFSET: float = -18.0

const WEAPON_NODE_MAP: Dictionary = {
	"sword_combo": "sword",
	"bow": "bow",
	"tool_axe": "tools",
	"tool_pickaxe": "tools",
	"tool_hoe": "tools",
	"tool_watercan": "tools",
	"fish_cast": "fishing_rod",
}


func _ready() -> void:
	_input_mgr = get_node_or_null("/root/InputManager")
	_base_collision_layer = collision_layer
	_base_collision_mask = collision_mask
	_player_hitbox = get_node_or_null("PlayerHitbox")
	_character_node = get_node_or_null("Character")
	_anim_player = get_node_or_null("Character/AnimationPlayer")
	_weapons_node = get_node_or_null("Weapons")
	_sword_node = get_node_or_null("Weapons/Sword")
	_tools_node = get_node_or_null("Weapons/Tools")
	_bow_node = get_node_or_null("Weapons/Bow")
	_fishing_rod_node = get_node_or_null("Weapons/FishingRod")
	_sword_hitboxes = {
		"down": get_node_or_null("Weapons/Sword/Hitbox/HitboxDown"),
		"up": get_node_or_null("Weapons/Sword/Hitbox/HitboxUp"),
		"left": get_node_or_null("Weapons/Sword/Hitbox/HitboxLeft"),
		"right": get_node_or_null("Weapons/Sword/Hitbox/HitboxRight"),
	}
	for hitbox in _sword_hitboxes.values():
		if hitbox:
			hitbox.add_to_group("player_weapon")
	_tool_hitboxes = {
		"tool_axe": get_node_or_null("Weapons/Tools/AxeHitbox"),
		"tool_pickaxe": get_node_or_null("Weapons/Tools/PickaxeHitbox"),
		"tool_hoe": get_node_or_null("Weapons/Tools/HoeHitbox"),
		"tool_watercan": get_node_or_null("Weapons/Tools/WaterCanHitbox"),
	}
	for hitbox in _tool_hitboxes.values():
		if hitbox:
			hitbox.add_to_group("player_weapon")
	_disable_all_hitboxes()
	_connect_tool_hitbox_signals()
	_hide_all_weapons()
	_setup_audio()
	_setup_fx()
	_setup_health()
	_spawn_position = global_position
	add_to_group("player")
	_setup_collect_area()
	_mount_node = get_node_or_null("Mount")
	call_deferred("_deferred_ready")


func _deferred_ready() -> void:
	var nodes = get_tree().get_nodes_in_group("toolbar")
	if nodes.size() > 0:
		_toolbar = nodes[0]


func _setup_audio() -> void:
	var audio_script = load("res://Scripts/Player/player_audio.gd")
	if audio_script:
		_audio = Node.new()
		_audio.set_script(audio_script)
		_audio.name = "PlayerAudio"
		add_child(_audio)


func _setup_fx() -> void:
	var fx_script = load("res://Scripts/FX/combat_fx.gd")
	if fx_script:
		_fx = Node2D.new()
		_fx.set_script(fx_script)
		_fx.name = "CombatFX"
		add_child(_fx)
		move_child(_fx, 0)


func _setup_health() -> void:
	var hs_script = load("res://Scripts/Player/health_system.gd")
	if hs_script:
		_health = Node.new()
		_health.set_script(hs_script)
		_health.name = "HealthSystem"
		add_child(_health)
		_health.damage_taken.connect(_on_damage_taken)
		_health.died.connect(_on_died)

	var hui_script = load("res://Scripts/UI/health_ui.gd")
	if hui_script:
		_health_ui = CanvasLayer.new()
		_health_ui.set_script(hui_script)
		_health_ui.name = "HealthUI"
		_health_ui.layer = 10
		add_child(_health_ui)

	var go_script = load("res://Scripts/UI/game_over_ui.gd")
	if go_script:
		_game_over_ui = CanvasLayer.new()
		_game_over_ui.set_script(go_script)
		_game_over_ui.name = "GameOverUI"
		add_child(_game_over_ui)
		_game_over_ui.respawn_requested.connect(_on_respawn)


func _setup_collect_area() -> void:
	_collect_area = Area2D.new()
	_collect_area.name = "CollectRadius"
	_collect_area.collision_layer = 0
	_collect_area.collision_mask = 8
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 40.0
	shape.shape = circle
	_collect_area.add_child(shape)
	add_child(_collect_area)
	_collect_area.area_entered.connect(_on_collect_area_entered)


func _on_collect_area_entered(area: Area2D) -> void:
	if area.has_method("magnet_collect") and not area in _magnet_targets:
		_magnet_targets.append(area)


func take_damage(amount: int = 1) -> bool:
	if _health and _health.has_method("take_damage"):
		return _health.take_damage(amount)
	return false


func apply_knockback(kb: Vector2) -> void:
	_knockback_velocity = kb


func apply_stun(_from_position: Vector2) -> void:
	if state == State.DEAD or state == State.DODGE or state == State.ATTACK:
		return
	# Don't stun during invincibility frames — the enemy toggles its weapon
	# monitoring on/off each attack cycle, which re-fires area_entered even
	# when the player is invincible.  Without this check the player gets
	# stun-locked between combos and _hide_all_weapons() keeps firing.
	if _health and _health.is_invincible():
		return
	# Knock backwards from the direction the player was walking
	var move_dir := velocity.normalized() if velocity.length() > 5.0 else _facing_to_vector()
	_stun_direction = -move_dir
	_stun_timer = stun_duration
	_knockback_velocity = Vector2.ZERO
	state = State.STUN
	_hide_all_weapons()


func set_checkpoint(pos: Vector2) -> void:
	_spawn_position = pos


func _on_damage_taken(_amount: int) -> void:
	_iframe_flash_timer = _health.invincibility_duration if _health else 1.0


func _on_died() -> void:
	state = State.DEAD
	velocity = Vector2.ZERO
	_fishing_casting = false
	_fishing_reeling = false
	_hide_all_weapons()
	_set_hit_collision(false)
	# Wait for death animation to finish before showing game over
	if _anim_player and _anim_player.has_animation("death"):
		_anim_player.play("death")
		await _anim_player.animation_finished
	if _game_over_ui:
		_game_over_ui.show_game_over()


func _on_respawn() -> void:
	state = State.IDLE
	global_position = _spawn_position
	_set_hit_collision(true)
	if _character_node:
		_character_node.modulate = Color.WHITE
	if _health:
		_health.reset()


func _connect_tool_hitbox_signals() -> void:
	var axe_hitbox = _tool_hitboxes.get("tool_axe")
	if axe_hitbox and not axe_hitbox.is_connected("area_entered", _on_axe_hit):
		axe_hitbox.area_entered.connect(_on_axe_hit)
	var pick_hitbox = _tool_hitboxes.get("tool_pickaxe")
	if pick_hitbox and not pick_hitbox.is_connected("area_entered", _on_pickaxe_hit):
		pick_hitbox.area_entered.connect(_on_pickaxe_hit)


func _on_axe_hit(area: Area2D) -> void:
	if area.is_in_group("choppable"):
		if _audio:
			_audio.play_axe_chop()
		var parent = area.get_parent()
		if parent and parent.has_method("take_hit"):
			parent.take_hit(1)


func _on_pickaxe_hit(area: Area2D) -> void:
	if area.is_in_group("mineable"):
		if _audio:
			_audio.play_ore_hit()
		var parent = area.get_parent()
		if parent and parent.has_method("take_hit"):
			parent.take_hit(1)


func _update_magnet_targets(delta: float) -> void:
	var to_remove: Array = []
	for drop in _magnet_targets:
		if not is_instance_valid(drop):
			to_remove.append(drop)
			continue
		var dir: Vector2 = global_position - (drop as Node2D).global_position
		var dist: float = dir.length()
		if dist < 6.0:
			if drop.has_method("magnet_collect"):
				drop.magnet_collect()
			to_remove.append(drop)
		else:
			var speed: float = 200.0 * delta
			(drop as Node2D).global_position += dir.normalized() * speed
	for d in to_remove:
		_magnet_targets.erase(d)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F3:
		_debug_collisions = !_debug_collisions
		queue_redraw()


func _draw() -> void:
	# Summon progress bar
	if _summoning and summon_duration > 0.0:
		var progress: float = clampf(_summon_timer / summon_duration, 0.0, 1.0)
		var bar_x: float = -SUMMON_BAR_WIDTH / 2.0
		var bar_y: float = SUMMON_BAR_Y_OFFSET
		# Background
		draw_rect(Rect2(bar_x - 1, bar_y - 1, SUMMON_BAR_WIDTH + 2, SUMMON_BAR_HEIGHT + 2),
			Color(0.1, 0.1, 0.1, 0.8))
		# Fill
		var fill_width: float = SUMMON_BAR_WIDTH * progress
		draw_rect(Rect2(bar_x, bar_y, fill_width, SUMMON_BAR_HEIGHT),
			Color(0.9, 0.8, 0.3, 0.95))

	if not _debug_collisions:
		return
	var player_shape = get_node_or_null("PlayerHitbox")
	if player_shape and player_shape.shape and not player_shape.disabled:
		_draw_collision_shape(player_shape, Color.GREEN)
	if state == State.ATTACK:
		for dir_name in _sword_hitboxes:
			var hitbox_area = _sword_hitboxes[dir_name]
			if hitbox_area == null or not hitbox_area.monitoring:
				continue
			for child in hitbox_area.get_children():
				if child is CollisionShape2D and child.shape and not child.disabled:
					_draw_collision_shape(child, Color.RED)
		for tool_name in _tool_hitboxes:
			var hitbox_area = _tool_hitboxes[tool_name]
			if hitbox_area == null or not hitbox_area.monitoring:
				continue
			for child in hitbox_area.get_children():
				if child is CollisionShape2D and child.shape and not child.disabled:
					_draw_collision_shape(child, Color.ORANGE)


func _draw_collision_shape(shape_node: CollisionShape2D, color: Color) -> void:
	var shape = shape_node.shape
	var pos = shape_node.global_position - global_position
	if shape is RectangleShape2D:
		var rect = Rect2(pos - shape.size / 2.0, shape.size)
		draw_rect(rect, Color(color, 0.3), true)
		draw_rect(rect, color, false, 1.0)
	elif shape is CircleShape2D:
		draw_circle(pos, shape.radius, Color(color, 0.3))
		draw_arc(pos, shape.radius, 0, TAU, 32, color, 1.0)


func _physics_process(delta: float) -> void:
	if _debug_collisions:
		queue_redraw()
	if _dodge_cooldown_timer > 0.0:
		_dodge_cooldown_timer -= delta

	if _combo_window_timer > 0.0:
		_combo_window_timer -= delta
		if _combo_window_timer <= 0.0:
			_sword_combo_step = 0

	if _iframe_flash_timer > 0.0:
		_iframe_flash_timer -= delta
		if _character_node:
			var blink = int(_iframe_flash_timer * 10.0) % 2 == 0
			_character_node.modulate.a = 0.3 if blink else 1.0
		if _iframe_flash_timer <= 0.0 and _character_node:
			_character_node.modulate = Color.WHITE

	# Knockback decay
	if _knockback_velocity.length() > 5.0:
		_knockback_velocity = _knockback_velocity.lerp(Vector2.ZERO, 10.0 * delta)
		velocity += _knockback_velocity
	else:
		_knockback_velocity = Vector2.ZERO

	_update_magnet_targets(delta)

	if state == State.DEAD:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# Handle mount summoning (locks out all other input)
	if _summoning:
		_process_summon(delta)
		return

	_update_facing()

	match state:
		State.IDLE:
			_state_idle()
		State.MOVE:
			_state_move()
		State.DODGE:
			_state_dodge(delta)
		State.JUMP:
			_state_jump(delta)
		State.ATTACK:
			_state_attack(delta)
		State.STUN:
			_state_stun(delta)


func _update_facing() -> void:
	if state == State.STUN:
		return
	if state == State.ATTACK and not _bow_charging:
		return

	var diff := get_global_mouse_position() - global_position

	if _input_mgr:
		diff *= _input_mgr.mouse_sensitivity
		if _input_mgr.mouse_inverted:
			diff.y = -diff.y

	if abs(diff.x) > abs(diff.y):
		facing = "right" if diff.x > 0 else "left"
	else:
		facing = "up" if diff.y < 0 else "down"


func _state_idle() -> void:
	velocity = Vector2.ZERO
	_footstep_timer = 0.0

	if _try_mount_action():
		return
	if not mounted:
		if _try_attack():
			return
		if _try_dodge():
			return
		if _try_jump():
			return
	if _get_input_direction() != Vector2.ZERO:
		state = State.MOVE
		return

	move_and_slide()


func _state_move() -> void:
	if _try_mount_action():
		return
	if not mounted:
		if _try_attack():
			return
		if _try_dodge():
			return
		if _try_jump():
			return

	var input_dir = _get_input_direction()

	if input_dir == Vector2.ZERO:
		state = State.IDLE
		return

	var current_speed: float = mounted_speed if mounted else move_speed
	velocity = input_dir * current_speed
	move_and_slide()

	_footstep_timer -= get_physics_process_delta_time()
	if _footstep_timer <= 0.0:
		if _audio:
			_audio.play_footstep()
		_footstep_timer = FOOTSTEP_INTERVAL
	_grass_step_timer -= get_physics_process_delta_time()
	if _grass_step_timer <= 0.0:
		if _fx:
			_fx.play_walk_grass()
		_grass_step_timer = GRASS_STEP_INTERVAL


func _state_dodge(delta: float) -> void:
	_dodge_timer -= delta

	if _dodge_timer <= 0.0:
		invincible = false
		if _get_input_direction() != Vector2.ZERO:
			state = State.MOVE
		else:
			state = State.IDLE
		return

	_grass_step_timer -= delta
	if _grass_step_timer <= 0.0:
		if _fx:
			_fx.play_roll_grass()
		_grass_step_timer = GRASS_STEP_INTERVAL * 0.6

	velocity = _dodge_direction * dodge_speed
	move_and_slide()


func _state_jump(delta: float) -> void:
	_jump_timer -= delta

	if _jump_timer <= 0.0:
		if _audio:
			_audio.play_land()
		if _get_input_direction() != Vector2.ZERO:
			state = State.MOVE
		else:
			state = State.IDLE
		return

	var progress: float = 1.0 - (_jump_timer / jump_duration)
	var curve: float = 1.0 - sin(progress * PI)
	var current_speed: float = lerpf(_jump_start_speed * jump_move_factor, _jump_start_speed, curve)
	velocity = _jump_direction * current_speed
	move_and_slide()


func _state_attack(delta: float) -> void:
	if _bow_charging:
		_bow_charge_time += delta

		var should_release = not Input.is_action_pressed("basic_attack")
		var auto_release = _bow_charge_time >= BOW_MAX_CHARGE

		var current_item = null
		if _toolbar:
			current_item = _toolbar.get_selected_item()
		var tool_switched = current_item != null and current_item.anim_prefix != "bow"

		if tool_switched:
			_bow_cancel()
			return

		if should_release or auto_release:
			_bow_release()
			return

		if _bow_charge_time > BOW_SHAKE_START:
			var shake_progress = clampf((_bow_charge_time - BOW_SHAKE_START) / (BOW_MAX_CHARGE - BOW_SHAKE_START), 0.0, 1.0)
			var shake_intensity = shake_progress * BOW_SHAKE_MAX
			var shake_offset = Vector2(
				randf_range(-shake_intensity, shake_intensity),
				randf_range(-shake_intensity, shake_intensity)
			)
			if _character_node:
				_character_node.position = _bow_original_char_pos + shake_offset
			if _weapons_node:
				_weapons_node.position = _bow_original_weap_pos + shake_offset
			queue_redraw()

		if _anim_player and _anim_player.is_playing():
			if _anim_player.current_animation_position >= 0.2:
				_anim_player.pause()

		velocity = Vector2.ZERO
		move_and_slide()
		return

	_attack_timer -= delta

	if not _bow_shot_fired and _bow_shoot_timer > 0.0:
		_bow_shoot_timer -= delta
		if _bow_shoot_timer <= 0.0:
			_bow_shot_fired = true
			if _bow_node and _bow_node.has_method("shoot"):
				_bow_node.shoot()
			if _audio:
				_audio.play_bow_shoot()
			if _fx:
				_fx.play_bow_fx(facing)

	if Input.is_action_just_pressed("basic_attack"):
		_queued_combo = true

	if not _weapon_hidden_this_swing and not _fishing_casting and not _fishing_reeling and _attack_timer <= WEAPON_HIDE_BEFORE_END:
		_hide_all_weapons()
		_weapon_hidden_this_swing = true

	if _attack_timer <= 0.0:
		if _fishing_casting:
			_start_fish_reel()
			return
		if _fishing_reeling:
			_fishing_reeling = false
			_hide_all_weapons()
		if _queued_combo and _sword_combo_step > 0 and _sword_combo_step < SWORD_COMBO_MAX:
			_queued_combo = false
			_advance_sword_combo()
			return

		# Safety: always disable all hitboxes when leaving ATTACK state
		# prevents lingering weapon areas from damaging enemies while idle/moving
		_hide_all_weapons()
		_queued_combo = false

		# Stop the looping attack animation so it doesn't keep applying
		# stale track values (frame, z_index) to weapon sprites after we
		# leave the ATTACK state.  playerAnimation.gd will pick up the
		# correct idle/walk animation on the next _process frame.
		if _anim_player:
			_anim_player.stop(true)

		_combo_window_timer = COMBO_WINDOW
		if _get_input_direction() != Vector2.ZERO:
			state = State.MOVE
		else:
			state = State.IDLE
		return

	velocity = Vector2.ZERO
	move_and_slide()


func _state_stun(delta: float) -> void:
	_stun_timer -= delta
	var progress := clampf(_stun_timer / stun_duration, 0.0, 1.0)
	velocity = _stun_direction * stun_knockback_speed * progress
	move_and_slide()

	if _stun_timer <= 0.0:
		_stun_direction = Vector2.ZERO
		if _get_input_direction() != Vector2.ZERO:
			state = State.MOVE
		else:
			state = State.IDLE


func _try_attack() -> bool:
	if not Input.is_action_just_pressed("basic_attack"):
		return false
	if _toolbar == null:
		return false
	var item = _toolbar.get_selected_item()
	if item.anim_prefix == "":
		return false

	var prefix: String = item.anim_prefix
	var anim_name: String

	if prefix == "sword_combo":
		if _combo_window_timer > 0.0 and _sword_combo_step > 0 and _sword_combo_step < SWORD_COMBO_MAX:
			_sword_combo_step += 1
		else:
			_sword_combo_step = 1
		_combo_window_timer = 0.0
		anim_name = prefix + "_" + facing + "_" + str(_sword_combo_step)
	else:
		_sword_combo_step = 0
		anim_name = prefix + "_" + facing

	if _anim_player == null or not _anim_player.has_animation(anim_name):
		return false

	state = State.ATTACK
	_queued_combo = false
	_weapon_hidden_this_swing = false
	attack_anim_name = anim_name
	_attack_timer = _anim_player.get_animation(anim_name).length
	# Force-play the animation immediately so it always restarts from frame 0,
	# even if the AnimationPlayer is still playing the same animation from a
	# previous attack (race between _physics_process and _process).
	_anim_player.play(anim_name)
	# Force the AnimationPlayer to apply the first frame's track values (frame,
	# z_index, flip) right now.  Without this, the values only update on the
	# next _process cycle, leaving weapon sprites with stale properties for
	# one frame after _show_weapon makes them visible.
	_anim_player.seek(0.0, true)
	_show_weapon(prefix)
	_play_attack_sfx(prefix)
	return true


func _play_attack_sfx(prefix: String) -> void:
	match prefix:
		"sword_combo":
			if _audio:
				_audio.play_sword_swing(_sword_combo_step)
			if _fx:
				_fx.play_sword_fx(facing, _sword_combo_step)
		"tool_axe":
			if _audio:
				_audio.play_axe_swing()
			if _fx:
				_fx.play_axe_fx(facing)
		"tool_pickaxe":
			if _audio:
				_audio.play_pickaxe_swing()
			if _fx:
				_fx.play_pickaxe_fx(facing)
		"tool_hoe":
			if _audio:
				_audio.play_water_pour()
			if _fx:
				_fx.play_water_fx(facing)
		"tool_watercan":
			if _audio:
				_audio.play_tool_swing()
			if _fx:
				_fx.play_hoe_fx(facing)
		"bow":
			_bow_charging = true
			_bow_charge_time = 0.0
			_bow_shot_fired = false
			_bow_shoot_timer = 0.0
			_attack_timer = 999.0
			if _audio:
				_audio.play_bow_draw()
			if _character_node:
				_bow_original_char_pos = _character_node.position
			if _weapons_node:
				_bow_original_weap_pos = _weapons_node.position
		"fish_cast":
			_fishing_casting = true
			_fishing_reeling = false
			if _audio:
				_audio.play_fish_cast()
			if _fx:
				_fx.play_fish_cast_fx(facing)


func _start_fish_reel() -> void:
	_fishing_casting = false
	_fishing_reeling = true
	if _audio:
		_audio.play_fish_splash()
	var reel_anim := "fish_reel_" + facing
	if _anim_player and _anim_player.has_animation(reel_anim):
		_anim_player.play(reel_anim)
		_attack_timer = _anim_player.get_animation(reel_anim).length
		if _audio:
			_audio.play_fish_reel()
	else:
		_fishing_reeling = false
		_attack_timer = 0.0


func _bow_release() -> void:
	_bow_charging = false
	if _audio:
		_audio.stop_bow()
	if _character_node:
		_character_node.position = _bow_original_char_pos
	if _weapons_node:
		_weapons_node.position = _bow_original_weap_pos
	if _anim_player:
		_anim_player.play()
	_bow_shoot_timer = 0.1
	_bow_shot_fired = false
	var anim_name = "bow_" + facing
	if _anim_player and _anim_player.has_animation(anim_name):
		var anim_length = _anim_player.get_animation(anim_name).length
		_attack_timer = anim_length - 0.2
	else:
		_attack_timer = 0.4


func _bow_cancel() -> void:
	_bow_charging = false
	_bow_shot_fired = true
	if _audio:
		_audio.stop_bow()
	if _character_node:
		_character_node.position = _bow_original_char_pos
	if _weapons_node:
		_weapons_node.position = _bow_original_weap_pos
	if _anim_player:
		_anim_player.stop(true)
	_hide_all_weapons()
	if _get_input_direction() != Vector2.ZERO:
		state = State.MOVE
	else:
		state = State.IDLE


func _advance_sword_combo() -> void:
	_sword_combo_step += 1
	var anim_name = "sword_combo_" + facing + "_" + str(_sword_combo_step)

	if _anim_player == null or not _anim_player.has_animation(anim_name):
		_sword_combo_step = 0
		_hide_all_weapons()
		if _anim_player:
			_anim_player.stop(true)
		state = State.IDLE
		return

	_weapon_hidden_this_swing = false
	attack_anim_name = anim_name
	_attack_timer = _anim_player.get_animation(anim_name).length
	_anim_player.play(anim_name)
	_anim_player.seek(0.0, true)
	_show_weapon("sword_combo")
	if _audio:
		_audio.play_sword_swing(_sword_combo_step)
	if _fx:
		_fx.play_sword_fx(facing, _sword_combo_step)


func _try_dodge() -> bool:
	if not Input.is_action_just_pressed("dodge"):
		return false
	if _dodge_cooldown_timer > 0.0:
		return false

	state = State.DODGE
	invincible = true
	_dodge_timer = dodge_duration
	_dodge_cooldown_timer = dodge_cooldown
	if _audio:
		_audio.play_roll()
	if _fx:
		_fx.play_roll_grass()

	var input_dir = _get_input_direction()
	if input_dir != Vector2.ZERO:
		_dodge_direction = input_dir
	else:
		_dodge_direction = _facing_to_vector()

	if abs(_dodge_direction.x) > abs(_dodge_direction.y):
		dodge_facing = "right" if _dodge_direction.x > 0 else "left"
	else:
		dodge_facing = "up" if _dodge_direction.y < 0 else "down"

	return true


func _try_jump() -> bool:
	if not Input.is_action_just_pressed("jump"):
		return false

	state = State.JUMP
	_jump_timer = jump_duration
	_jump_direction = _get_input_direction()
	_jump_start_speed = velocity.length() if velocity.length() > 0.0 else move_speed
	if _audio:
		_audio.play_jump()
	if _fx:
		_fx.play_jump_grass()
	return true


func _show_weapon(anim_prefix: String) -> void:
	_hide_all_weapons()
	if _weapons_node == null:
		return
	_weapons_node.visible = true

	var weapon_key = WEAPON_NODE_MAP.get(anim_prefix, "")
	match weapon_key:
		"sword":
			if _sword_node:
				_sword_node.visible = true
			_enable_sword_hitbox(facing)
		"tools":
			if _tools_node:
				_tools_node.visible = true
			_enable_tool_hitbox(anim_prefix, facing)
		"bow":
			if _bow_node:
				_bow_node.visible = true
		"fishing_rod":
			if _fishing_rod_node:
				_fishing_rod_node.visible = true


func _hide_all_weapons() -> void:
	_disable_all_hitboxes()
	if _weapons_node:
		_weapons_node.visible = false
	if _sword_node:
		_sword_node.visible = false
		_sword_node.z_index = 1
	if _tools_node:
		_tools_node.visible = false
		_tools_node.z_index = 1
	if _bow_node:
		_bow_node.visible = false
	if _fishing_rod_node:
		_fishing_rod_node.visible = false


func _enable_sword_hitbox(dir: String) -> void:
	_disable_all_hitboxes()
	var hitbox = _sword_hitboxes.get(dir)
	if hitbox:
		hitbox.set_deferred("monitoring", true)
		hitbox.set_deferred("monitorable", true)
		var shape_suffix = "2" if _sword_combo_step >= 3 else "1"
		for child in hitbox.get_children():
			if child is CollisionShape2D:
				child.set_deferred("disabled", not child.name.ends_with(shape_suffix))


func _enable_tool_hitbox(anim_prefix: String, dir: String) -> void:
	_disable_all_hitboxes()
	var hitbox = _tool_hitboxes.get(anim_prefix)
	if hitbox == null:
		return
	hitbox.set_deferred("monitoring", true)
	hitbox.set_deferred("monitorable", true)
	for child in hitbox.get_children():
		if child is CollisionShape2D:
			var shape_dir = child.name.replace("Hitbox", "").to_lower()
			child.set_deferred("disabled", shape_dir != dir)


func _disable_all_hitboxes() -> void:
	for hitbox in _sword_hitboxes.values():
		if hitbox:
			hitbox.set_deferred("monitoring", false)
			hitbox.set_deferred("monitorable", false)
			_set_collision_shapes(hitbox, true)
	for hitbox in _tool_hitboxes.values():
		if hitbox:
			hitbox.set_deferred("monitoring", false)
			hitbox.set_deferred("monitorable", false)
			_set_collision_shapes(hitbox, true)


func _set_collision_shapes(parent: Node, disabled: bool) -> void:
	for child in parent.get_children():
		if child is CollisionShape2D:
			child.set_deferred("disabled", disabled)


func _facing_to_vector() -> Vector2:
	match facing:
		"up": return Vector2.UP
		"down": return Vector2.DOWN
		"left": return Vector2.LEFT
		"right": return Vector2.RIGHT
	return Vector2.DOWN


func _get_input_direction() -> Vector2:
	var dir = Vector2.ZERO
	dir.x = Input.get_axis("move_left", "move_right")
	dir.y = Input.get_axis("move_up", "move_down")
	if dir.length() > 1.0:
		dir = dir.normalized()
	return dir


# ═════════════════════════════════════════════════════════════════════
#  MOUNT SUMMONING
# ═════════════════════════════════════════════════════════════════════

func _start_summon() -> void:
	_summoning = true
	_summon_timer = 0.0
	velocity = Vector2.ZERO

func _cancel_summon() -> void:
	_summoning = false
	_summon_timer = 0.0
	queue_redraw()

func _complete_summon() -> void:
	_summoning = false
	_summon_timer = 0.0
	mounted = true
	if _mount_node:
		_mount_node.visible = true
	_hide_all_weapons()
	if _fx:
		_fx.play_summon_smoke()
	if _audio and _audio.has_method("play_horse_neigh"):
		_audio.play_horse_neigh()
	queue_redraw()

func _dismount() -> void:
	mounted = false
	if _mount_node:
		_mount_node.visible = false
	if _fx:
		_fx.play_summon_smoke()

func _process_summon(delta: float) -> void:
	_summon_timer += delta
	queue_redraw()
	# Cancel if player tries to move
	if _get_input_direction() != Vector2.ZERO:
		_cancel_summon()
		return
	# Cancel if pressed H again
	if Input.is_action_just_pressed("mount"):
		_cancel_summon()
		return
	if _summon_timer >= summon_duration:
		_complete_summon()
		return
	velocity = Vector2.ZERO
	move_and_slide()

func _try_mount_action() -> bool:
	if not Input.is_action_just_pressed("mount"):
		return false
	if mounted:
		_dismount()
		return true
	else:
		_start_summon()
		return true


func _set_hit_collision(enabled: bool) -> void:
	if enabled:
		collision_layer = _base_collision_layer
		collision_mask = _base_collision_mask
	else:
		collision_layer = 0
		collision_mask = 0
	if _player_hitbox:
		_player_hitbox.set_deferred("disabled", not enabled)
