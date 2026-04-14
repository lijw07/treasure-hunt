class_name EnemySlime
extends EnemyBase
## Slime enemy — uses non-directional animations (idle, walk, attack, death).
## Hops toward the player and lunges to attack.
## Movement only happens while airborne (during the jump arc), so the slime
## visually leaps forward and pauses on landing — no sliding.
## Big slimes can optionally split into smaller slimes on death.

@export_group("Slime")
@export var hop_height: float = 4.0
## How fast the hop cycle progresses.  At hop_speed = 2.0, one full
## airborne→grounded cycle takes 1.0s (airborne ≈ 0.5s, grounded ≈ 0.5s),
## which gives the walk/jump animation room to play through cleanly.
@export var hop_speed: float = 2.0
## Multiplier applied to hop_height for the visual jump arc.  Used by BOTH
## the regular hop and the attack pounce so they look identical.
@export var jump_arc_scale: float = 1.8
@export var split_on_death: bool = false
@export var split_scene: PackedScene = null
@export var split_count: int = 2
## Peak velocity at the apex of the arc.  Used by BOTH regular hops and
## the attack pounce, so chase and pounce feel like the same kind of leap.
@export var lunge_force: float = 100.0

@export_group("Slime FX")
@export var slime_color: Color = Color(0.3, 0.75, 0.25, 0.85)
@export var splat_particle_count: int = 10

var _hop_phase: float = 0.0       ## Tracks position in the hop cycle (0..1 per hop)
var _hop_was_airborne: bool = false ## Tracks if we were airborne last frame (for landing FX)
var _hop_direction: Vector2 = Vector2.ZERO  ## Direction locked at start of each hop

# ── Pounce (attack jump) state ────────────────────────────────────────────
var _pounce_direction: Vector2 = Vector2.ZERO  ## Locked at strike moment — slime leaps toward the player
var _pounce_active: bool = false               ## True during the airborne phase of the attack pounce


func _physics_process(delta: float) -> void:
	# Advance the hop phase and set the sprite's visual offset BEFORE the base
	# class runs the state machine + move_and_slide().  The actual velocity is
	# applied inside the overridden _process_chase / _process_wander so it's
	# ready when the base class calls move_and_slide().
	if not _is_dead and _state in [State.WANDER, State.CHASE]:
		_hop_phase += hop_speed * delta
		var sine_val := sin(_hop_phase * PI)
		# Use the unified arc helper so hops match the pounce visually.
		_sprite.position.y = _jump_arc_y(sine_val)
	elif not _is_dead and _state != State.ATTACK:
		# ATTACK handles its own sprite Y (pounce arc); let other states settle.
		_sprite.position.y = lerp(_sprite.position.y, 0.0, 10.0 * delta)

	# Hard-guarantee: slime cannot be pushed while attacking.  Any lingering
	# knockback from a hit taken right before ATTACK started is zeroed out.
	if _state == State.ATTACK:
		_knockback_velocity = Vector2.ZERO

	super._physics_process(delta)


## Compute hop velocity for this frame.  Call from state processors so the
## value is set before the base class's move_and_slide().
## Movement ONLY happens during the airborne phase, and each takeoff
## re-triggers the jump ("walk") animation from frame 0 — so every hop is a
## distinct, visible leap rather than a continuous slide + looping animation.
##
## The `_speed` parameter is preserved for API compatibility with the base
## class but ignored — both regular hops and the attack pounce now use
## `lunge_force` so chase and pounce feel like the same kind of leap.
func _apply_hop_velocity(_speed: float) -> void:
	var sine_val := sin(_hop_phase * PI)
	var airborne := sine_val > 0.05

	if airborne:
		# Takeoff: lock direction, face it, and trigger a fresh jump animation.
		if not _hop_was_airborne:
			_hop_direction = _get_move_direction()
			_update_facing(_hop_direction)
			_trigger_jump_anim()
		# Unified arc velocity — same formula as the pounce.
		velocity = _jump_arc_velocity(_hop_direction, sine_val)
	else:
		velocity = Vector2.ZERO
		# Landing: switch to idle between hops so the slime visibly pauses.
		if _hop_was_airborne:
			_play_grounded_anim()

	_hop_was_airborne = airborne


# ── Unified jump arc — single source of truth for hops AND pounce ─────────
# Both the regular hop cycle (wander/chase) and the attack pounce route
# their sprite Y and velocity through these helpers.  Tweaking hop_height,
# jump_arc_scale, or lunge_force changes both the same way, so the slime's
# leap reads as one consistent motion regardless of intent.

func _jump_arc_y(sine_val: float) -> float:
	## Sprite Y offset for a sine arc.  sine_val is sin(phase * PI) ∈ [-1, 1].
	return -absf(sine_val) * hop_height * jump_arc_scale


func _jump_arc_velocity(direction: Vector2, sine_val: float) -> Vector2:
	## Horizontal velocity for the airborne phase, peaking at the arc apex.
	return direction * lunge_force * clampf(absf(sine_val), 0.0, 1.0)


## Restart the jump/walk animation from the beginning so every hop is a
## fresh, clearly-triggered animation cycle.  The animation's playback rate
## is scaled so it completes in exactly one airborne arc — keeps the visual
## jump in sync with the actual hop motion at any hop_speed setting.
func _trigger_jump_anim() -> void:
	var anim := "walk"
	if not _anim_player.has_animation(anim):
		return
	# Airborne arc length in seconds: half the full sine cycle.
	# Full cycle (sin going 0→2π) takes 2/hop_speed sec, so airborne ≈ 1/hop_speed.
	var airborne_dur := 1.0 / maxf(hop_speed, 0.001)
	var anim_len := _anim_player.get_animation(anim).length
	if anim_len > 0.0 and airborne_dur > 0.0:
		_anim_player.speed_scale = anim_len / airborne_dur
	else:
		_anim_player.speed_scale = 1.0
	_anim_player.stop()
	_anim_player.play(anim)


## Play the grounded/idle animation between hops at normal speed.
func _play_grounded_anim() -> void:
	_anim_player.speed_scale = 1.0
	if _anim_player.has_animation("idle") and _anim_player.current_animation != "idle":
		_anim_player.play("idle")


## Returns the direction the slime should hop toward based on its current state.
func _get_move_direction() -> Vector2:
	if _state == State.CHASE and _player and is_instance_valid(_player):
		return (_player.global_position - global_position).normalized()
	return _walk_direction


# ── Override: chase uses hop movement, not continuous velocity ────────────

func _process_chase(_delta: float) -> void:
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

	# Animation is driven by the hop cycle (takeoff → walk/jump, land → idle).
	_apply_hop_velocity(chase_speed)


func _process_wander(delta: float) -> void:
	_timer -= delta

	if _player and _can_see_player():
		_enter_chase()
		return

	if get_slide_collision_count() > 0:
		_walk_direction = -_walk_direction.rotated(randf_range(-PI / 2, PI / 2))
		_update_facing(_walk_direction)

	if global_position.distance_to(_spawn_position) > wander_radius:
		_walk_direction = (_spawn_position - global_position).normalized()
		_update_facing(_walk_direction)

	if _timer <= 0.0:
		_enter_idle()
		return

	# Animation is driven by the hop cycle (takeoff → walk/jump, land → idle).
	_apply_hop_velocity(move_speed)


# ── Override: non-directional animations ──────────────────────────────────

func _play_directional_anim(base_name: String) -> void:
	# Slimes have no directional variants — just play the base animation.
	# Reset speed_scale so animations triggered by the base state machine
	# (idle on entering IDLE, attack on entering ATTACK, etc.) play at
	# normal speed even if the hop trigger left a custom scale set.
	if _anim_player.has_animation(base_name):
		if _anim_player.current_animation != base_name:
			_anim_player.speed_scale = 1.0
			_anim_player.play(base_name)
	elif _anim_player.has_animation("idle"):
		if _anim_player.current_animation != "idle":
			_anim_player.speed_scale = 1.0
			_anim_player.play("idle")


func _play_anim(anim_name: String) -> void:
	if _anim_player.has_animation(anim_name):
		# Reset to normal playback rate — _trigger_jump_anim mutates speed_scale
		# to sync the walk anim with the hop arc, and we don't want that
		# bleeding into attack/death/hurt animations.
		_anim_player.speed_scale = 1.0
		_anim_player.play(anim_name)


# ── Override: pounce attack — slime jumps onto the player's collision ─────

## Called at the moment the strike lands (after windup).  Lock the pounce
## direction toward the player and begin the airborne leap.
func _on_attack_start() -> void:
	super._on_attack_start()
	_spawn_splat_fx()
	_pounce_active = true
	if _player and is_instance_valid(_player):
		_pounce_direction = (_player.global_position - global_position).normalized()
		_update_facing(_pounce_direction)
	else:
		_pounce_direction = Vector2.ZERO
	# No knockback-style lunge — movement is the pounce arc itself.
	_knockback_velocity = Vector2.ZERO


## Override the base attack processor so the slime actually JUMPS onto the
## player instead of standing still with a decaying knockback shove.
## During windup: plant on ground, face the player.
## During strike: arc through the air toward the player.
func _process_attack(delta: float) -> void:
	_timer -= delta

	# Windup phase — telegraph the attack, stay grounded.
	if not _attack_struck:
		_windup_remaining -= delta
		velocity = Vector2.ZERO
		_sprite.position.y = lerp(_sprite.position.y, 0.0, 10.0 * delta)
		if _player and is_instance_valid(_player):
			_update_facing((_player.global_position - global_position).normalized())
		if _windup_remaining <= 0.0:
			_attack_struck = true
			_on_attack_start()
	else:
		# Strike phase — single jump arc toward the player.
		# t goes 0 → 1 over the attack_duration window, same shape as a hop.
		var t := 1.0 - clampf(_timer / maxf(attack_duration, 0.001), 0.0, 1.0)
		var sine_val := sin(t * PI)
		# Routed through the same helpers as a regular hop, so the pounce
		# arc and movement match the slime's normal leap exactly.
		_sprite.position.y = _jump_arc_y(sine_val)
		if sine_val > 0.05 and _pounce_direction != Vector2.ZERO:
			velocity = _jump_arc_velocity(_pounce_direction, sine_val)
		else:
			velocity = Vector2.ZERO

	# Extra belt-and-braces: no pushback can accumulate mid-pounce.
	_knockback_velocity = Vector2.ZERO

	if _timer <= 0.0:
		_end_attack()
		_attack_timer = attack_cooldown
		_sprite.position.y = 0.0
		if _player and _can_see_player():
			_enter_chase()
		else:
			_enter_idle()


# ── Override: invulnerable while attacking/pouncing ───────────────────────
# When the slime is mid-pounce on the player, the player's swing shouldn't
# damage or knock it back — slimes use their body as the weapon, so the
# pounce phase is treated as their "armoured" frames.  The knockback clear
# in _physics_process / _process_attack handles any lingering push from a
# hit the slime absorbed the frame it entered ATTACK.
func take_damage(amount: int = 1) -> void:
	if _state == State.ATTACK:
		return
	super.take_damage(amount)


func _end_attack() -> void:
	super._end_attack()
	_pounce_active = false
	_pounce_direction = Vector2.ZERO
	_spawn_splat_fx()


# ── Override: facing (slimes flip sprite based on x direction) ────────────

func _update_facing(dir: Vector2) -> void:
	if dir == Vector2.ZERO:
		return
	_sprite.flip_h = dir.x < 0
	# Store facing for weapon positioning — slimes keep _facing == _visual_facing
	# because they use non-directional animations (no left→right remap needed).
	if absf(dir.x) > absf(dir.y):
		_facing = "right" if dir.x > 0 else "left"
	else:
		_facing = "down" if dir.y > 0 else "up"
	_visual_facing = _facing


# ── Override: death with optional split ───────────────────────────────────

func _on_death_complete() -> void:
	if split_on_death and split_scene:
		for i in range(split_count):
			var child := split_scene.instantiate() as Node2D
			get_parent().add_child(child)
			var angle := (TAU / split_count) * i + randf_range(-0.3, 0.3)
			child.global_position = global_position + Vector2(cos(angle), sin(angle)) * 12.0


# ── Slime FX ──────────────────────────────────────────────────────────────

func _spawn_splat_fx() -> void:
	var p := GPUParticles2D.new()
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = clampi(splat_particle_count, 1, 32)
	p.lifetime = 0.35
	p.z_index = -1

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 160.0
	mat.initial_velocity_min = 20.0
	mat.initial_velocity_max = 50.0
	mat.gravity = Vector3(0, 60, 0)
	mat.damping_min = 15.0
	mat.damping_max = 25.0
	mat.scale_min = 1.0
	mat.scale_max = 2.5
	mat.color = slime_color

	var alpha_curve := CurveTexture.new()
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.9))
	curve.add_point(Vector2(1.0, 0.0))
	alpha_curve.curve = curve
	mat.alpha_curve = alpha_curve

	p.process_material = mat
	get_parent().add_child(p)
	p.global_position = global_position + Vector2(0, 4)
	p.restart()
	p.emitting = true
	get_tree().create_timer(0.6).timeout.connect(p.queue_free)
