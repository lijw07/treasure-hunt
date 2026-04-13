class_name EnemySlime
extends EnemyBase
## Slime enemy — uses non-directional animations (idle, walk, attack, death).
## Hops toward the player and lunges to attack.
## Movement only happens while airborne (during the jump arc), so the slime
## visually leaps forward and pauses on landing — no sliding.
## Big slimes can optionally split into smaller slimes on death.

@export_group("Slime")
@export var hop_height: float = 4.0
@export var hop_speed: float = 6.0
@export var split_on_death: bool = false
@export var split_scene: PackedScene = null
@export var split_count: int = 2
@export var lunge_force: float = 100.0

@export_group("Slime FX")
@export var slime_color: Color = Color(0.3, 0.75, 0.25, 0.85)
@export var splat_particle_count: int = 10

var _hop_phase: float = 0.0       ## Tracks position in the hop cycle (0..1 per hop)
var _hop_was_airborne: bool = false ## Tracks if we were airborne last frame (for landing FX)
var _hop_direction: Vector2 = Vector2.ZERO  ## Direction locked at start of each hop


func _physics_process(delta: float) -> void:
	# Advance the hop phase and set the sprite's visual offset BEFORE the base
	# class runs the state machine + move_and_slide().  The actual velocity is
	# applied inside the overridden _process_chase / _process_wander so it's
	# ready when the base class calls move_and_slide().
	if not _is_dead and _state in [State.WANDER, State.CHASE]:
		_hop_phase += hop_speed * delta
		var sine_val := sin(_hop_phase * PI)
		_sprite.position.y = -abs(sine_val) * hop_height
	elif not _is_dead:
		_sprite.position.y = lerp(_sprite.position.y, 0.0, 10.0 * delta)

	super._physics_process(delta)


## Compute hop velocity for this frame.  Call from state processors so the
## value is set before the base class's move_and_slide().
func _apply_hop_velocity(speed: float) -> void:
	var sine_val := sin(_hop_phase * PI)
	var airborne := sine_val > 0.05

	if airborne:
		# Lock direction at the start of each hop (takeoff moment)
		if not _hop_was_airborne:
			_hop_direction = _get_move_direction()
			_update_facing(_hop_direction)
		# Scale speed by the arc height so movement peaks mid-jump
		velocity = _hop_direction * speed * clampf(sine_val, 0.0, 1.0)
	else:
		velocity = Vector2.ZERO

	_hop_was_airborne = airborne


## Returns the direction the slime should hop toward based on its current state.
func _get_move_direction() -> Vector2:
	if _state == State.CHASE and _player and is_instance_valid(_player):
		return (_player.global_position - global_position).normalized()
	return _walk_direction


# ── Override: chase uses hop movement, not continuous velocity ────────────

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

	_apply_hop_velocity(chase_speed)
	_play_directional_anim("walk")


func _process_wander(delta: float) -> void:
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
		return

	_apply_hop_velocity(move_speed)


# ── Override: non-directional animations ──────────────────────────────────

func _play_directional_anim(base_name: String) -> void:
	# Slimes have no directional variants — just play the base animation
	if _anim_player.has_animation(base_name):
		if _anim_player.current_animation != base_name:
			_anim_player.play(base_name)
	elif _anim_player.has_animation("idle"):
		if _anim_player.current_animation != "idle":
			_anim_player.play("idle")


func _play_anim(anim_name: String) -> void:
	if _anim_player.has_animation(anim_name):
		_anim_player.play(anim_name)


# ── Override: lunge attack ────────────────────────────────────────────────

func _on_attack_start() -> void:
	super._on_attack_start()
	_spawn_splat_fx()
	# Lunge toward player
	if _player and is_instance_valid(_player):
		var dir := (_player.global_position - global_position).normalized()
		_knockback_velocity = dir * lunge_force


func _end_attack() -> void:
	super._end_attack()
	_spawn_splat_fx()


# ── Override: facing (slimes flip sprite based on x direction) ────────────

func _update_facing(dir: Vector2) -> void:
	if dir == Vector2.ZERO:
		return
	_sprite.flip_h = dir.x < 0
	# Store facing for weapon positioning
	if absf(dir.x) > absf(dir.y):
		_facing = "right" if dir.x > 0 else "left"
	else:
		_facing = "down" if dir.y > 0 else "up"


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
