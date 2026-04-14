class_name EnemyProjectile
extends Area2D
## Projectile fired by ranged enemies. Damages the player on contact.

@export var speed: float = 200.0
@export var max_distance: float = 200.0
@export var damage: int = 1
@export var projectile_color: Color = Color(0.8, 0.3, 1.0, 1.0)

var _direction: Vector2 = Vector2.DOWN
var _traveled: float = 0.0
var _hit_sounds: Array[AudioStream] = []


func setup(dir: Vector2, spd: float = -1.0, dmg: int = -1) -> void:
	_direction = dir.normalized()
	if spd > 0:
		speed = spd
	if dmg > 0:
		damage = dmg
	# Rotate sprite to face direction
	rotation = _direction.angle()


func _ready() -> void:
	add_to_group("enemy_weapon")
	# Enforce collision layers — only interact with the player, never enemies
	collision_layer = 32   # Layer 6: enemy weapons
	collision_mask  = 1    # Layer 1: player body only
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	_load_hit_sounds()


func _physics_process(delta: float) -> void:
	var move := _direction * speed * delta
	position += move
	_traveled += move.length()
	if _traveled >= max_distance:
		_impact()


func _on_body_entered(body: Node2D) -> void:
	# Skip ALL enemies (including the one that fired us) and enemy-owned nodes
	if body.is_in_group("enemies"):
		return
	var node := body.get_parent()
	while node != null:
		if node.is_in_group("enemies"):
			return
		node = node.get_parent()

	if body.is_in_group("player") or body.name == "Player":
		if body.has_method("take_damage"):
			body.take_damage(damage)
	_impact()


func _on_area_entered(area: Area2D) -> void:
	# Skip anything enemy-owned — prevents friendly fire and self-damage
	if area.is_in_group("enemy_hurtbox") or area.is_in_group("enemy_weapon"):
		return
	var node := area.get_parent()
	while node != null:
		if node.is_in_group("enemies"):
			return
		node = node.get_parent()

	if area.is_in_group("player_hurtbox"):
		var player = area.get_parent()
		if player and player.has_method("take_damage"):
			player.take_damage(damage)
		_impact()


func _impact() -> void:
	set_physics_process(false)
	set_deferred("monitoring", false)
	_spawn_impact_fx()
	_play_impact_sound()
	queue_free()


func _load_hit_sounds() -> void:
	for i in range(1, 6):
		var s = load("res://Assets/Audio/SFX/Weapons/arrow_hit_%d.ogg" % i)
		if s:
			_hit_sounds.append(s)


func _play_impact_sound() -> void:
	if _hit_sounds.is_empty():
		return
	var sfx := AudioStreamPlayer2D.new()
	sfx.stream = _hit_sounds[randi() % _hit_sounds.size()]
	sfx.pitch_scale = randf_range(0.9, 1.15)
	sfx.volume_db = -4.0
	sfx.max_distance = 400
	sfx.bus = "Master"
	get_parent().add_child(sfx)
	sfx.global_position = global_position
	sfx.play()
	sfx.finished.connect(sfx.queue_free)


func _spawn_impact_fx() -> void:
	var p := GPUParticles2D.new()
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 6
	p.lifetime = 0.25
	p.z_index = 3

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(-_direction.x, -_direction.y, 0.0)
	mat.spread = 40.0
	mat.initial_velocity_min = 30.0
	mat.initial_velocity_max = 60.0
	mat.gravity = Vector3(0, 80, 0)
	mat.damping_min = 15.0
	mat.damping_max = 30.0
	mat.scale_min = 1.0
	mat.scale_max = 2.0
	mat.color = projectile_color

	var alpha_curve := CurveTexture.new()
	var c := Curve.new()
	c.add_point(Vector2(0.0, 1.0))
	c.add_point(Vector2(1.0, 0.0))
	alpha_curve.curve = c
	mat.alpha_curve = alpha_curve

	p.process_material = mat
	get_parent().add_child(p)
	p.global_position = global_position
	p.restart()
	p.emitting = true
	get_tree().create_timer(0.4).timeout.connect(p.queue_free)
