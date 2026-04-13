class_name EnemyBombschroom
extends EnemyBase
## Bombschroom — walks toward the player, charges up, then explodes.
## Deals area damage and leaves a toxic gas cloud.

@export_group("Explosion")
@export var explosion_radius: float = 40.0
@export var explosion_damage: int = 2
@export var charge_duration: float = 1.0
@export var explosion_particle_count: int = 24
@export var gas_cloud_duration: float = 3.0
@export var gas_cloud_tick_damage: int = 1
@export var gas_cloud_tick_interval: float = 0.8
@export var toxic_gas_texture: Texture2D

@export_group("Bombschroom FX")
@export var charge_color: Color = Color(1.0, 0.3, 0.2, 1.0)
@export var explosion_color: Color = Color(1.0, 0.6, 0.1, 0.95)
@export var gas_color: Color = Color(0.35, 0.7, 0.25, 0.7)

enum BombState { NORMAL, CHARGING, EXPLODING }
var _bomb_state: BombState = BombState.NORMAL
var _charge_timer: float = 0.0
var _original_modulate: Color = Color.WHITE


func _ready() -> void:
	super._ready()
	_original_modulate = _sprite.modulate
	# Bombschroom doesn't use a weapon area — it explodes
	if _weapon:
		_weapon.monitoring = false


func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	if _bomb_state == BombState.CHARGING:
		_charge_timer -= delta
		# Pulsing red as it charges
		var pulse := 0.5 + 0.5 * sin(_charge_timer * 12.0)
		_sprite.modulate = _original_modulate.lerp(charge_color, pulse)
		# Scale up slightly
		_sprite.scale = Vector2.ONE * (1.0 + (1.0 - _charge_timer / charge_duration) * 0.3)
		velocity = Vector2.ZERO

		if _charge_timer <= 0.0:
			_explode()
		return

	if _bomb_state == BombState.EXPLODING:
		return

	super._physics_process(delta)


func _enter_attack() -> void:
	# Instead of a normal attack, start charging
	_state = State.ATTACK
	_bomb_state = BombState.CHARGING
	_charge_timer = charge_duration
	velocity = Vector2.ZERO
	_play_anim("charge")
	_play_attack_sound()


func _explode() -> void:
	_bomb_state = BombState.EXPLODING
	_state = State.DYING
	_is_dead = true
	velocity = Vector2.ZERO

	# Damage everything in explosion radius
	_deal_explosion_damage()

	# Visual explosion
	_spawn_explosion_particles()
	_play_death_sound()

	# Spawn gas cloud
	_spawn_gas_cloud()

	# Play death animation and remove
	_play_anim("death")
	_sprite.modulate = Color(1, 1, 1, 0.5)
	await get_tree().create_timer(0.4).timeout
	queue_free()


func _deal_explosion_damage() -> void:
	# Find the player and damage if in radius
	var space := get_world_2d().direct_space_state
	# Simple distance check to player
	if _player and is_instance_valid(_player):
		if global_position.distance_to(_player.global_position) <= explosion_radius:
			if _player.has_method("take_damage"):
				_player.take_damage(explosion_damage)


func _spawn_explosion_particles() -> void:
	var p := GPUParticles2D.new()
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = clampi(explosion_particle_count, 1, 64)
	p.lifetime = 0.6
	p.z_index = 3

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 60.0
	mat.initial_velocity_max = 120.0
	mat.gravity = Vector3(0, 40, 0)
	mat.damping_min = 10.0
	mat.damping_max = 25.0
	mat.scale_min = 2.0
	mat.scale_max = 5.0
	mat.color = explosion_color

	var alpha_curve := CurveTexture.new()
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(0.3, 0.9))
	curve.add_point(Vector2(1.0, 0.0))
	alpha_curve.curve = curve
	mat.alpha_curve = alpha_curve

	p.process_material = mat
	get_parent().add_child(p)
	p.global_position = global_position
	p.restart()
	p.emitting = true
	get_tree().create_timer(1.0).timeout.connect(p.queue_free)


func _spawn_gas_cloud() -> void:
	## Creates a lingering toxic area that damages the player periodically.
	var cloud := Area2D.new()
	cloud.name = "ToxicGasCloud"
	cloud.add_to_group("enemy_weapon")
	cloud.set("damage", gas_cloud_tick_damage)

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = explosion_radius * 0.8
	shape.shape = circle
	cloud.add_child(shape)

	# Add visual (animated sprite or particles)
	if toxic_gas_texture:
		var gas_sprite := AnimatedSprite2D.new()
		var frames := SpriteFrames.new()
		frames.add_animation("default")
		# Use the toxic gas VFX spritesheet (6 frames @ 32x32)
		for i in range(6):
			var atlas := AtlasTexture.new()
			atlas.atlas = toxic_gas_texture
			atlas.region = Rect2(i * 32, 0, 32, 32)
			frames.add_frame("default", atlas)
		frames.set_animation_speed("default", 8.0)
		frames.set_animation_loop("default", true)
		gas_sprite.sprite_frames = frames
		gas_sprite.play("default")
		gas_sprite.scale = Vector2(2.5, 2.5)
		gas_sprite.modulate = gas_color
		cloud.add_child(gas_sprite)
	else:
		# Fallback: continuous particle emitter
		var p := GPUParticles2D.new()
		p.amount = 12
		p.lifetime = 1.0
		p.explosiveness = 0.0

		var mat := ParticleProcessMaterial.new()
		mat.direction = Vector3(0, -1, 0)
		mat.spread = 180.0
		mat.initial_velocity_min = 5.0
		mat.initial_velocity_max = 15.0
		mat.gravity = Vector3(0, -10, 0)
		mat.scale_min = 3.0
		mat.scale_max = 6.0
		mat.color = gas_color

		var ac := CurveTexture.new()
		var c := Curve.new()
		c.add_point(Vector2(0.0, 0.0))
		c.add_point(Vector2(0.2, 0.7))
		c.add_point(Vector2(0.8, 0.5))
		c.add_point(Vector2(1.0, 0.0))
		ac.curve = c
		mat.alpha_curve = ac

		p.process_material = mat
		cloud.add_child(p)

	# Set up collision layers
	cloud.collision_layer = 0
	cloud.collision_mask = 1  # Player layer
	cloud.set_deferred("monitoring", true)

	get_parent().add_child(cloud)
	cloud.global_position = global_position

	# Tick damage via timer
	var tick_timer := Timer.new()
	tick_timer.wait_time = gas_cloud_tick_interval
	tick_timer.autostart = true
	cloud.add_child(tick_timer)

	tick_timer.timeout.connect(func():
		for body in cloud.get_overlapping_bodies():
			if (body.is_in_group("player") or body.name == "Player") and body.has_method("take_damage"):
				body.take_damage(gas_cloud_tick_damage)
	)

	# Remove cloud after duration
	get_tree().create_timer(gas_cloud_duration).timeout.connect(func():
		if is_instance_valid(cloud):
			cloud.queue_free()
	)


# ── Override: non-directional animations ──────────────────────────────────

func _play_directional_anim(base_name: String) -> void:
	var anim_name := base_name + "_" + _facing
	if _anim_player.has_animation(anim_name):
		if _anim_player.current_animation != anim_name:
			_anim_player.play(anim_name)
	elif _anim_player.has_animation(base_name):
		if _anim_player.current_animation != base_name:
			_anim_player.play(base_name)
