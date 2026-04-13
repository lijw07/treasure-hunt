class_name EnemyProjectile
extends Area2D
## Projectile fired by ranged enemies. Damages the player on contact.

@export var speed: float = 200.0
@export var max_distance: float = 200.0
@export var damage: int = 1
@export var projectile_color: Color = Color(0.8, 0.3, 1.0, 1.0)

var _direction: Vector2 = Vector2.DOWN
var _traveled: float = 0.0


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
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


func _physics_process(delta: float) -> void:
	var move := _direction * speed * delta
	position += move
	_traveled += move.length()
	if _traveled >= max_distance:
		_impact()


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemies"):
		return
	if body.is_in_group("player") or body.name == "Player":
		if body.has_method("take_damage"):
			body.take_damage(damage)
	_impact()


func _on_area_entered(area: Area2D) -> void:
	# Skip enemy hurtboxes — don't deal friendly fire
	if area.is_in_group("enemy_hurtbox"):
		return
	if area.is_in_group("player_hurtbox"):
		var player = area.get_parent()
		if player and player.has_method("take_damage"):
			player.take_damage(damage)
		_impact()


func _impact() -> void:
	set_physics_process(false)
	set_deferred("monitoring", false)
	_spawn_impact_fx()
	queue_free()


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
