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

@export_group("Stats")
@export var max_health: int = 3          ## Half-hearts
@export var contact_damage: int = 1      ## Damage dealt when player overlaps
@export var attack_damage: int = 1       ## Damage dealt on attack hit
@export var knockback_force: float = 120.0
@export var invincibility_duration: float = 0.4
@export var contact_damage_interval: float = 0.6  ## Seconds between contact damage ticks

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
var _facing: String = "down"
var _player: Node2D = null
var _knockback_velocity: Vector2 = Vector2.ZERO
var _invincible_timer: float = 0.0
var _audio_timer: float = 0.0
var _footstep_timer: float = 0.0
var _is_dead: bool = false
var _current_hp: int = 0
var _contact_cooldown: float = 0.0
var _contact_area: Area2D

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

	# Set up hurtbox
	_hurtbox.add_to_group("enemy_hurtbox")
	_hurtbox.area_entered.connect(_on_hurtbox_area_entered)

	# Set up weapon area
	if _weapon:
		_weapon.add_to_group("enemy_weapon")
		_weapon.set("damage", attack_damage)
		_weapon.monitoring = false

	# Create contact damage area (always-on Area2D that hurts player on overlap)
	_setup_contact_area()

	# Add to enemy group
	add_to_group("enemies")

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

	# Contact damage cooldown
	if _contact_cooldown > 0.0:
		_contact_cooldown -= delta

	# Contact damage check
	_check_contact_damage()

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

	# Audio
	_process_audio(delta)


# ── Contact Damage ────────────────────────────────────────────────────────

func _setup_contact_area() -> void:
	_contact_area = Area2D.new()
	_contact_area.name = "ContactArea"
	_contact_area.collision_layer = 0
	_contact_area.collision_mask = 1  # Detect player body
	_contact_area.monitoring = true

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 8.0  # Tight overlap radius
	shape.shape = circle
	_contact_area.add_child(shape)
	add_child(_contact_area)


func _check_contact_damage() -> void:
	if _contact_cooldown > 0.0 or _is_dead:
		return
	for body in _contact_area.get_overlapping_bodies():
		if (body.is_in_group("player") or body.name == "Player"):
			if body.get("invincible") and body.invincible:
				return
			if body.has_method("take_damage"):
				body.take_damage(contact_damage)
				_contact_cooldown = contact_damage_interval
				# Knock player away
				if body.has_method("apply_knockback"):
					var kb_dir := (body.global_position - global_position).normalized()
					body.apply_knockback(kb_dir * knockback_force * 1.5)
				_spawn_hit_particles(body.global_position)
				_play_sfx(_hurt_player, _hurt_sounds, -2.0)
				return


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


func _process_chase(delta: float) -> void:
	if not _player or not is_instance_valid(_player):
		_player = null
		_enter_idle()
		return

	var dist := global_position.distance_to(_player.global_position)

	if dist > lose_interest_radius:
		_player = null
		_enter_idle()
		return

	if dist <= attack_range and _attack_timer <= 0.0:
		_enter_attack()
		return

	var dir := ((_player.global_position - global_position).normalized())
	velocity = dir * chase_speed
	_update_facing(dir)
	_play_directional_anim("walk")


func _process_attack(delta: float) -> void:
	velocity = Vector2.ZERO
	_timer -= delta
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
		if _player and _can_see_player():
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
	_timer = attack_duration
	if _player:
		var dir := (_player.global_position - global_position).normalized()
		_update_facing(dir)
	_play_directional_anim("attack")
	_on_attack_start()


func _enter_hurt() -> void:
	_state = State.HURT
	_timer = 0.3
	_play_anim("hurt")


func _enter_dying() -> void:
	_state = State.DYING
	_is_dead = true
	velocity = Vector2.ZERO
	if _weapon:
		_weapon.monitoring = false
	_contact_area.monitoring = false
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
		_weapon.monitoring = true


func _end_attack() -> void:
	if _weapon:
		_weapon.monitoring = false


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
	_flash_hurt()
	_spawn_hit_particles(global_position)
	_play_hurt_sound()

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


func _on_player_exited(body: Node2D) -> void:
	pass


func _can_see_player() -> bool:
	if not _player or not is_instance_valid(_player):
		return false
	return global_position.distance_to(_player.global_position) <= detection_radius


func _on_hurtbox_area_entered(area: Area2D) -> void:
	# Reject any damage from enemy-owned sources (prevents friendly fire / self-damage)
	if area.is_in_group("enemy_weapon"):
		return
	var source_owner := area.get_parent()
	if source_owner is EnemyBase:
		return

	if area.is_in_group("player_weapon") or area.name.begins_with("Hitbox"):
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
		_facing = "right" if dir.x > 0 else "left"
	else:
		_facing = "down" if dir.y > 0 else "up"
	if _facing == "left":
		if not _anim_player.has_animation("idle_left"):
			_sprite.flip_h = true
			_facing = "right"
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

	var angle_deg := _dir_angle(_facing)
	var offset := _dir_offset(_facing, 12.0)

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
