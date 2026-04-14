class_name EnemyBase
extends CharacterBody2D
## Base script for all hostile enemies.
## Handles: health, player detection, wandering, chasing, knockback,
## contact damage, damage flash, attack/hit/death FX, audio, y-sort layering.
##
## Node structure expected:
##   - Node2D/Sprite  (Sprite2D with hframes/vframes)
##   - Node2D/AnimationPlayer
##   - CollisionShape2D
##   - DetectionArea  (Area2D — detects player entering/exiting)
##   - Hurtbox        (Area2D — receives damage, group "enemy_hurtbox")
##   - Weapon         (Area2D — deals damage, group "enemy_weapon") [optional]
##   - AudioStreamPlayer2D (ambient SFX)
##   - FootstepPlayer (movement SFX)
##   - HurtPlayer     (hurt/attack SFX)

## Collision layer constants — enforced in code so scene misconfig can't cause
## self-damage or friendly fire.
const LAYER_PLAYER       := 1    ## Layer 1
const LAYER_ENEMY        := 2    ## Layer 2
const LAYER_PLAYER_MELEE := 16   ## Layer 5 — player sword / tool hitboxes
const LAYER_ENEMY_WEAPON := 32   ## Layer 6 — enemy weapon areas
const LAYER_PLAYER_ARROW := 64   ## Layer 7 — player arrows

@export_group("Stats")
@export var max_health: int = 6          ## Hit points
@export var attack_damage: int = 1       ## Damage dealt on attack hit
@export var knockback_force: float = 120.0
@export var invincibility_duration: float = 0.4

@export_group("Movement")
@export var move_speed: float = 30.0
@export var chase_speed: float = 55.0
@export var wander_radius: float = 48.0
@export var idle_time_min: float = 1.5
@export var idle_time_max: float = 4.0
@export var walk_time_min: float = 1.0
@export var walk_time_max: float = 3.0

@export_group("Detection")
@export var detection_radius: float = 80.0
@export var attack_range: float = 20.0
@export var lose_interest_radius: float = 120.0

@export_group("Attack")
@export var attack_cooldown: float = 1.2
@export var attack_duration: float = 0.5
@export var attack_windup: float = 0.4   ## Delay before the strike lands (telegraph window)

@export_group("Audio")
@export var ambient_sound: AudioStream
@export var ambient_interval_min: float = 10.0
@export var ambient_interval_max: float = 25.0
@export var footstep_sound: AudioStream
@export var footstep_interval: float = 0.3
@export var hurt_sound: AudioStream
@export var death_sound: AudioStream
@export var attack_sound: AudioStream

@export_group("FX")
@export var hurt_flash_color: Color = Color(1.3, 0.3, 0.3, 1.0)
@export var hurt_flash_duration: float = 0.12
@export var death_particle_color: Color = Color(0.9, 0.9, 0.9, 0.9)
@export var death_particle_count: int = 16
@export var hit_particle_color: Color = Color(1.0, 0.85, 0.6, 0.9)
@export var hit_particle_count: int = 8
@export var attack_particle_color: Color = Color(1.0, 1.0, 1.0, 0.8)
@export var attack_particle_count: int = 12

enum State { IDLE, WANDER, CHASE, ATTACK, HURT, DYING }

var _state: State = State.IDLE
var _timer: float = 0.0
var _attack_timer: float = 0.0
var _walk_direction: Vector2 = Vector2.ZERO
var _spawn_position: Vector2 = Vector2.ZERO
var _facing: String = "down"         ## Animation key (may be "right" when visually left via flip)
var _visual_facing: String = "down"  ## True visual direction (accounts for sprite flip)
var _player: Node2D = null
var _knockback_velocity: Vector2 = Vector2.ZERO
var _invincible_timer: float = 0.0
var _audio_timer: float = 0.0
var _footstep_timer: float = 0.0
var _is_dead: bool = false
var _current_hp: int = 0
var _windup_remaining: float = 0.0   ## Time left before the strike activates
var _attack_struck: bool = false      ## Whether _on_attack_start() has fired this attack
var _damage_aggro: bool = false       ## True when aggro'd by taking damage from outside detection range

# ── Health Bar UI ──
var _health_bar_bg: ColorRect
var _health_bar_fill: ColorRect
var _health_bar_container: Node2D
var _health_bar_visible_timer: float = 0.0
const HEALTH_BAR_WIDTH: float = 20.0
const HEALTH_BAR_HEIGHT: float = 3.0
const HEALTH_BAR_OFFSET_Y: float = -14.0   ## Pixels above enemy origin
const HEALTH_BAR_SHOW_DURATION: float = 3.0 ## Seconds to stay visible after damage
const HEALTH_BAR_FADE_SPEED: float = 3.0    ## Alpha units per second for fade-out

# SFX banks loaded at runtime
var _footstep_sounds: Array[AudioStream] = []
var _hurt_sounds: Array[AudioStream] = []
var _attack_sounds: Array[AudioStream] = []

@onready var _anim_player: AnimationPlayer = $Node2D/AnimationPlayer
@onready var _sprite: Sprite2D = $Node2D/Sprite
@onready var _detection_area: Area2D = $DetectionArea
@onready var _hurtbox: Area2D = $Hurtbox
@onready var _weapon: Area2D = $Weapon if has_node("Weapon") else null
@onready var _ambient_player: AudioStreamPlayer2D = $AudioStreamPlayer2D if has_node("AudioStreamPlayer2D") else null
@onready var _footstep_player: AudioStreamPlayer2D = $FootstepPlayer if has_node("FootstepPlayer") else null
@onready var _hurt_player: AudioStreamPlayer2D = $HurtPlayer if has_node("HurtPlayer") else null


func _ready() -> void:
	_spawn_position = global_position
	_current_hp = max_health
	_audio_timer = randf_range(ambient_interval_min, ambient_interval_max)

	# Set up detection radius
	_setup_detection_area()

	# Connect detection signals
	_detection_area.body_entered.connect(_on_player_entered)
	_detection_area.body_exited.connect(_on_player_exited)

	# Set up hurtbox — enforce layers so it only detects player weapons/arrows
	_hurtbox.add_to_group("enemy_hurtbox")
	_hurtbox.collision_layer = LAYER_ENEMY
	_hurtbox.collision_mask  = LAYER_PLAYER_MELEE | LAYER_PLAYER_ARROW
	_hurtbox.area_entered.connect(_on_hurtbox_area_entered)

	# Set up weapon area — enforce layers so it only interacts with the player
	if _weapon:
		_weapon.add_to_group("enemy_weapon")
		_weapon.collision_layer = LAYER_ENEMY_WEAPON
		_weapon.collision_mask  = LAYER_PLAYER
		_weapon.set("damage", attack_damage)
		_weapon.set_deferred("monitoring", false)
		_weapon.set_deferred("monitorable", false)
		_set_weapon_shapes(true)  # Start with shapes disabled

	# Enforce detection area layers — only detect the player body
	_detection_area.collision_layer = 0
	_detection_area.collision_mask  = LAYER_PLAYER

	# Add to enemy group
	add_to_group("enemies")

	# Create health bar UI (hidden until first hit)
	_setup_health_bar()

	# Load SFX banks
	_load_sfx()

	_enter_idle()


func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	# Invincibility cooldown
	if _invincible_timer > 0.0:
		_invincible_timer -= delta

	# Knockback decay
	if _knockback_velocity.length() > 5.0:
		_knockback_velocity = _knockback_velocity.lerp(Vector2.ZERO, 8.0 * delta)
	else:
		_knockback_velocity = Vector2.ZERO

	# Attack cooldown
	if _attack_timer > 0.0:
		_attack_timer -= delta

	# State machine
	match _state:
		State.IDLE:
			_process_idle(delta)
		State.WANDER:
			_process_wander(delta)
		State.CHASE:
			_process_chase(delta)
		State.ATTACK:
			_process_attack(delta)
		State.HURT:
			_process_hurt(delta)
		State.DYING:
			return

	# Apply movement with knockback
	velocity = velocity + _knockback_velocity
	move_and_slide()

	# Health bar fade
	_process_health_bar(delta)

	# Audio
	_process_audio(delta)


# ── Health Bar UI ─────────────────────────────────────────────────────────

func _setup_health_bar() -> void:
	_health_bar_container = Node2D.new()
	_health_bar_container.z_index = 10
	_health_bar_container.position = Vector2(0, HEALTH_BAR_OFFSET_Y)
	# Don't inherit parent transforms like flip — bar should stay level
	_health_bar_container.top_level = false

	# Background (dark)
	_health_bar_bg = ColorRect.new()
	_health_bar_bg.color = Color(0.1, 0.1, 0.1, 0.8)
	_health_bar_bg.size = Vector2(HEALTH_BAR_WIDTH + 2, HEALTH_BAR_HEIGHT + 2)
	_health_bar_bg.position = Vector2(-(HEALTH_BAR_WIDTH + 2) / 2.0, 0)
	_health_bar_container.add_child(_health_bar_bg)

	# Fill (red → yellow → green based on HP ratio)
	_health_bar_fill = ColorRect.new()
	_health_bar_fill.size = Vector2(HEALTH_BAR_WIDTH, HEALTH_BAR_HEIGHT)
	_health_bar_fill.position = Vector2(-HEALTH_BAR_WIDTH / 2.0, 1)
	_health_bar_container.add_child(_health_bar_fill)

	add_child(_health_bar_container)

	# Start hidden
	_health_bar_container.modulate = Color(1, 1, 1, 0)


func _show_health_bar() -> void:
	if _health_bar_container == null:
		return
	var ratio := clampf(float(_current_hp) / float(max_health), 0.0, 1.0)

	# Update fill width
	_health_bar_fill.size.x = HEALTH_BAR_WIDTH * ratio

	# Color: green > 0.5, yellow at 0.5, red < 0.25
	if ratio > 0.5:
		_health_bar_fill.color = Color(0.2, 0.85, 0.2, 1.0)  # Green
	elif ratio > 0.25:
		_health_bar_fill.color = Color(0.95, 0.85, 0.15, 1.0) # Yellow
	else:
		_health_bar_fill.color = Color(0.9, 0.15, 0.15, 1.0)  # Red

	# Show and reset timer
	_health_bar_container.modulate = Color(1, 1, 1, 1)
	_health_bar_visible_timer = HEALTH_BAR_SHOW_DURATION


func _process_health_bar(delta: float) -> void:
	if _health_bar_container == null:
		return
	if _health_bar_visible_timer > 0.0:
		_health_bar_visible_timer -= delta
	elif _health_bar_container.modulate.a > 0.0:
		# Fade out
		var a := maxf(_health_bar_container.modulate.a - HEALTH_BAR_FADE_SPEED * delta, 0.0)
		_health_bar_container.modulate = Color(1, 1, 1, a)


# ── State processors ──────────────────────────────────────────────────────

func _process_idle(delta: float) -> void:
	velocity = Vector2.ZERO
	_timer -= delta

	if _player and _can_see_player():
		_enter_chase()
		return

	if _timer <= 0.0:
		_enter_wander()


func _process_wander(delta: float) -> void:
	velocity = _walk_direction * move_speed
	_timer -= delta

	if _player and _can_see_player():
		_enter_chase()
		return

	if get_slide_collision_count() > 0:
		_walk_direction = -_walk_direction.rotated(randf_range(-PI / 2, PI / 2))
		_update_facing(_walk_direction)
		_play_directional_anim("walk")

	if global_position.distance_to(_spawn_position) > wander_radius:
		_walk_direction = (_spawn_position - global_position).normalized()
		_update_facing(_walk_direction)
		_play_directional_anim("walk")

	if _timer <= 0.0:
		_enter_idle()


func _process_chase(_delta: float) -> void:
	if not _player or not is_instance_valid(_player):
		_player = null
		_damage_aggro = false
		_enter_idle()
		return

	var dist := global_position.distance_to(_player.global_position)

	# When aggro'd by taking damage, chase much further before giving up.
	# Once close enough for normal detection, clear the aggro flag.
	if _damage_aggro:
		if dist <= detection_radius:
			_damage_aggro = false  # Normal detection takes over
		elif dist > lose_interest_radius * 3.0:
			_damage_aggro = false
			_player = null
			_enter_idle()
			return
	elif dist > lose_interest_radius:
		_player = null
		_enter_idle()
		return

	if dist <= attack_range and _attack_timer <= 0.0:
		_enter_attack()
		return

	# Within attack range but on cooldown — hold position instead of pushing
	if dist <= attack_range:
		velocity = Vector2.ZERO
		var face_dir := (_player.global_position - global_position).normalized()
		_update_facing(face_dir)
		_play_directional_anim("idle")
		return

	var dir := ((_player.global_position - global_position).normalized())
	velocity = dir * chase_speed
	_update_facing(dir)
	_play_directional_anim("walk")


func _process_attack(delta: float) -> void:
	velocity = Vector2.ZERO
	_timer -= delta

	# Tick windup — once it expires, fire the actual strike
	if not _attack_struck:
		_windup_remaining -= delta
		if _windup_remaining <= 0.0:
			_attack_struck = true
			_on_attack_start()

	if _timer <= 0.0:
		_end_attack()
		_attack_timer = attack_cooldown
		if _player and _can_see_player():
			_enter_chase()
		else:
			_enter_idle()


func _process_hurt(delta: float) -> void:
	velocity = Vector2.ZERO
	_timer -= delta
	if _timer <= 0.0:
		# Always chase after being hit if we know where the player is
		if _player and is_instance_valid(_player):
			_enter_chase()
		else:
			_enter_idle()


# ── State transitions ─────────────────────────────────────────────────────

func _enter_idle() -> void:
	_state = State.IDLE
	_timer = randf_range(idle_time_min, idle_time_max)
	velocity = Vector2.ZERO
	_play_directional_anim("idle")


func _enter_wander() -> void:
	_state = State.WANDER
	_timer = randf_range(walk_time_min, walk_time_max)
	var angle := randf() * TAU
	_walk_direction = Vector2(cos(angle), sin(angle)).normalized()
	if global_position.distance_to(_spawn_position) > wander_radius * 0.6:
		_walk_direction = (_spawn_position - global_position).normalized().rotated(randf_range(-0.5, 0.5))
	_update_facing(_walk_direction)
	_play_directional_anim("walk")


func _enter_chase() -> void:
	_state = State.CHASE
	if _player:
		var dir := (_player.global_position - global_position).normalized()
		_update_facing(dir)
		_play_directional_anim("walk")


func _enter_attack() -> void:
	_state = State.ATTACK
	_attack_struck = false
	_windup_remaining = attack_windup
	# Total time in ATTACK state = windup + strike duration
	_timer = attack_windup + attack_duration
	if _player:
		var dir := (_player.global_position - global_position).normalized()
		_update_facing(dir)
	_play_directional_anim("attack")


func _enter_hurt() -> void:
	_state = State.HURT
	_timer = 0.3
	_play_anim("hurt")


func _enter_dying() -> void:
	_state = State.DYING
	_is_dead = true
	velocity = Vector2.ZERO
	if _weapon:
		_weapon.set_deferred("monitoring", false)
		_weapon.set_deferred("monitorable", false)
		_set_weapon_shapes(true)
	# Hide health bar on death
	if _health_bar_container:
		_health_bar_container.modulate = Color(1, 1, 1, 0)
	_play_death_sound()
	_spawn_death_particles()
	_play_anim("death")
	if _anim_player.has_animation("death") or _anim_player.has_animation("death_" + _facing):
		await _anim_player.animation_finished
	else:
		await get_tree().create_timer(0.5).timeout
	_on_death_complete()
	queue_free()


# ── Attack interface (override in subclasses) ─────────────────────────────

func _on_attack_start() -> void:
	_play_attack_sound()
	_spawn_attack_particles()
	if _weapon:
		_weapon.set("damage", attack_damage)
		_weapon.set_deferred("monitoring", true)
		_weapon.set_deferred("monitorable", true)
		_set_weapon_shapes(false)  # Enable collision shapes


func _end_attack() -> void:
	if _weapon:
		_weapon.set_deferred("monitoring", false)
		_weapon.set_deferred("monitorable", false)
		_set_weapon_shapes(true)  # Disable collision shapes so nothing can detect it


func _set_weapon_shapes(disabled: bool) -> void:
	if _weapon == null:
		return
	for child in _weapon.get_children():
		if child is CollisionShape2D:
			child.set_deferred("disabled", disabled)


func _on_death_complete() -> void:
	pass


# ── Damage / Health ───────────────────────────────────────────────────────

func take_damage(amount: int = 1) -> void:
	if _is_dead:
		return
	if _invincible_timer > 0.0:
		return

	_current_hp -= amount
	_invincible_timer = invincibility_duration

	# Clean up weapon hitbox if interrupted mid-attack
	if _state == State.ATTACK:
		_attack_struck = false
		_windup_remaining = 0.0
		_end_attack()

	# ── Aggro on damage: find the player even if outside detection range ──
	if _player == null or not is_instance_valid(_player):
		_player = _find_player()
	if _player and is_instance_valid(_player):
		var dist := global_position.distance_to(_player.global_position)
		if dist > detection_radius:
			_damage_aggro = true  # Player hit us from far away — chase them down

	_flash_hurt()
	_spawn_hit_particles(global_position)
	_play_hurt_sound()
	_show_health_bar()

	if _current_hp <= 0:
		_enter_dying()
	else:
		# Knockback away from damage source
		if _player and is_instance_valid(_player):
			var kb_dir := (global_position - _player.global_position).normalized()
			_knockback_velocity = kb_dir * knockback_force
		_enter_hurt()


# ── Detection ─────────────────────────────────────────────────────────────

func _setup_detection_area() -> void:
	var shape := _detection_area.get_node_or_null("CollisionShape2D")
	if shape and shape.shape is CircleShape2D:
		(shape.shape as CircleShape2D).radius = detection_radius


func _on_player_entered(body: Node2D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		_player = body


func _on_player_exited(_body: Node2D) -> void:
	pass


func _can_see_player() -> bool:
	if not _player or not is_instance_valid(_player):
		return false
	return global_position.distance_to(_player.global_position) <= detection_radius


func _find_player() -> Node2D:
	## Search the scene tree for the player (used for aggro when hit from outside detection range).
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0 and is_instance_valid(players[0]):
		return players[0] as Node2D
	return null


func _on_hurtbox_area_entered(area: Area2D) -> void:
	# ── Reject ALL enemy-owned sources (prevents friendly fire & self-damage) ──
	if area.is_in_group("enemy_weapon") or area.is_in_group("enemy_hurtbox"):
		return

	# Walk up the tree — if ANY ancestor is an EnemyBase, this is enemy-owned
	var node := area.get_parent()
	while node != null:
		if node is EnemyBase:
			return
		node = node.get_parent()

	# ── Only accept damage from verified player sources ──
	if not area.is_in_group("player_weapon"):
		return

	var source_owner := area.get_parent()
	var dmg: int = 1
	if area.get("damage") != null:
		dmg = area.damage
	elif source_owner and source_owner.get("damage") != null:
		dmg = source_owner.damage
	take_damage(dmg)


# ── Animation helpers ─────────────────────────────────────────────────────

func _play_directional_anim(base_name: String) -> void:
	var anim_name := base_name + "_" + _facing
	if _anim_player.has_animation(anim_name):
		if _anim_player.current_animation != anim_name:
			_anim_player.play(anim_name)
	elif _anim_player.has_animation(base_name + "_down"):
		if _anim_player.current_animation != base_name + "_down":
			_anim_player.play(base_name + "_down")
	elif _anim_player.has_animation(base_name):
		if _anim_player.current_animation != base_name:
			_anim_player.play(base_name)


func _play_anim(anim_name: String) -> void:
	if _anim_player.has_animation(anim_name + "_" + _facing):
		_anim_player.play(anim_name + "_" + _facing)
	elif _anim_player.has_animation(anim_name):
		_anim_player.play(anim_name)


func _update_facing(dir: Vector2) -> void:
	if dir == Vector2.ZERO:
		return
	if absf(dir.x) > absf(dir.y):
		_visual_facing = "right" if dir.x > 0 else "left"
	else:
		_visual_facing = "down" if dir.y > 0 else "up"

	# _facing is the key used for animation lookup — may differ from visual
	# direction when left animations are missing (sprite flip is used instead).
	_facing = _visual_facing
	if _facing == "left":
		if not _anim_player.has_animation("idle_left"):
			_sprite.flip_h = true
			_facing = "right"   # animation key only — _visual_facing stays "left"
		else:
			_sprite.flip_h = false
	elif _facing == "right":
		_sprite.flip_h = false


# ── FX ────────────────────────────────────────────────────────────────────

func _flash_hurt() -> void:
	if _sprite == null:
		return
	var orig := _sprite.modulate
	_sprite.modulate = hurt_flash_color
	var tw := create_tween()
	tw.tween_property(_sprite, "modulate", orig, hurt_flash_duration)
	# Scale punch on hit
	var orig_scale := _sprite.scale
	_sprite.scale = orig_scale * 1.2
	var tw2 := create_tween()
	tw2.tween_property(_sprite, "scale", orig_scale, 0.12).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


func _spawn_hit_particles(at_pos: Vector2) -> void:
	## Orange-white spark burst when taking or dealing damage.
	var p := GPUParticles2D.new()
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = clampi(hit_particle_count, 1, 32)
	p.lifetime = 0.3
	p.z_index = 3

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 40.0
	mat.initial_velocity_max = 80.0
	mat.gravity = Vector3(0, 100, 0)
	mat.damping_min = 12.0
	mat.damping_max = 25.0
	mat.scale_min = 1.0
	mat.scale_max = 2.5
	mat.color = hit_particle_color

	var alpha_curve := CurveTexture.new()
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(0.5, 0.7))
	curve.add_point(Vector2(1.0, 0.0))
	alpha_curve.curve = curve
	mat.alpha_curve = alpha_curve

	p.process_material = mat
	get_parent().add_child(p)
	p.global_position = at_pos
	p.restart()
	p.emitting = true
	get_tree().create_timer(0.5).timeout.connect(p.queue_free)


func _spawn_attack_particles() -> void:
	## Directional slash/swing particles when attacking.
	var p := GPUParticles2D.new()
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = clampi(attack_particle_count, 1, 32)
	p.lifetime = 0.35
	p.z_index = 2

	var angle_deg := _dir_angle(_visual_facing)
	var offset := _dir_offset(_visual_facing, 12.0)

	var mat := ParticleProcessMaterial.new()
	var rad := deg_to_rad(angle_deg)
	mat.direction = Vector3(cos(rad), sin(rad), 0.0)
	mat.spread = 55.0
	mat.initial_velocity_min = 35.0
	mat.initial_velocity_max = 70.0
	mat.gravity = Vector3(0, 50, 0)
	mat.damping_min = 10.0
	mat.damping_max = 20.0
	mat.scale_min = 1.2
	mat.scale_max = 2.8
	mat.color = attack_particle_color

	var alpha_curve := CurveTexture.new()
	var c := Curve.new()
	c.add_point(Vector2(0.0, 0.9))
	c.add_point(Vector2(0.6, 0.5))
	c.add_point(Vector2(1.0, 0.0))
	alpha_curve.curve = c
	mat.alpha_curve = alpha_curve

	p.process_material = mat
	get_parent().add_child(p)
	p.global_position = global_position + offset
	p.restart()
	p.emitting = true
	get_tree().create_timer(0.5).timeout.connect(p.queue_free)


func _spawn_death_particles() -> void:
	var p := GPUParticles2D.new()
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = clampi(death_particle_count, 1, 64)
	p.lifetime = 0.5
	p.z_index = 2

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 30.0
	mat.initial_velocity_max = 70.0
	mat.gravity = Vector3(0, 100, 0)
	mat.damping_min = 10.0
	mat.damping_max = 20.0
	mat.scale_min = 1.5
	mat.scale_max = 3.0
	mat.color = death_particle_color

	var alpha_curve := CurveTexture.new()
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(0.5, 0.8))
	curve.add_point(Vector2(1.0, 0.0))
	alpha_curve.curve = curve
	mat.alpha_curve = alpha_curve

	p.process_material = mat
	get_parent().add_child(p)
	p.global_position = global_position
	p.restart()
	p.emitting = true
	get_tree().create_timer(0.8).timeout.connect(p.queue_free)


func _dir_angle(dir: String) -> float:
	match dir:
		"right": return 0.0
		"left": return 180.0
		"up": return -90.0
		"down": return 90.0
	return 90.0


func _dir_offset(dir: String, dist: float) -> Vector2:
	match dir:
		"right": return Vector2(dist, 0)
		"left": return Vector2(-dist, 0)
		"up": return Vector2(0, -dist)
		"down": return Vector2(0, dist)
	return Vector2(0, dist)


# ── Audio ─────────────────────────────────────────────────────────────────

func _load_sfx() -> void:
	# Load footstep banks (reuse player footstep sounds)
	if footstep_sound == null:
		_footstep_sounds = _load_bank("res://Assets/Audio/SFX/Footsteps/step_%d.ogg", range(1, 5))
	else:
		_footstep_sounds.append(footstep_sound)

	# Load hurt sounds (reuse sword swing as a hit sound if no dedicated sound)
	if hurt_sound:
		_hurt_sounds.append(hurt_sound)
	else:
		_hurt_sounds = _load_bank("res://Assets/Audio/SFX/Weapons/arrow_hit_%d.ogg", range(1, 4))

	# Load attack sounds (reuse swing sounds)
	if attack_sound:
		_attack_sounds.append(attack_sound)
	else:
		_attack_sounds = _load_bank("res://Assets/Audio/SFX/Weapons/swing_%d.wav", [5, 6, 7])


func _load_bank(pattern: String, indices) -> Array[AudioStream]:
	var bank: Array[AudioStream] = []
	for i in indices:
		var s = load(pattern % i)
		if s:
			bank.append(s)
	return bank


func _process_audio(delta: float) -> void:
	# Footstep audio while moving
	if _footstep_player and _state in [State.WANDER, State.CHASE]:
		_footstep_timer -= delta
		if _footstep_timer <= 0.0:
			_play_sfx(_footstep_player, _footstep_sounds, -12.0)
			_footstep_timer = footstep_interval

	# Ambient audio
	if _ambient_player and ambient_sound:
		_audio_timer -= delta
		if _audio_timer <= 0.0:
			_ambient_player.stream = ambient_sound
			_ambient_player.pitch_scale = randf_range(0.9, 1.1)
			_ambient_player.play()
			_audio_timer = randf_range(ambient_interval_min, ambient_interval_max)


func _play_sfx(player: AudioStreamPlayer2D, bank: Array[AudioStream],
		volume_db: float = 0.0, pitch_min: float = 0.85, pitch_max: float = 1.15) -> void:
	if bank.is_empty() or player == null:
		return
	player.stream = bank[randi() % bank.size()]
	player.pitch_scale = randf_range(pitch_min, pitch_max)
	if volume_db != 0.0:
		player.volume_db = volume_db
	player.play()


func _play_hurt_sound() -> void:
	_play_sfx(_hurt_player, _hurt_sounds, -2.0, 0.8, 1.2)


func _play_death_sound() -> void:
	if death_sound and _hurt_player:
		_hurt_player.stream = death_sound
		_hurt_player.pitch_scale = 0.75
		_hurt_player.volume_db = 0.0
		_hurt_player.play()
	else:
		_play_sfx(_hurt_player, _hurt_sounds, 0.0, 0.6, 0.8)


func _play_attack_sound() -> void:
	_play_sfx(_hurt_player, _attack_sounds, -2.0, 0.9, 1.1)
