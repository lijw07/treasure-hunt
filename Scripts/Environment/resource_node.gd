extends StaticBody2D

@export var resource_type: String = "rock"
@export var ore_type: String = "iron"
@export var health: int = 3
@export var max_health: int = 3
@export var drop_count: int = 2
@export var particle_color: Color = Color(0.6, 0.6, 0.7, 1.0)
@export var drop_texture: Texture2D

var _sprite: Sprite2D
var _original_position: Vector2

const ORE_SPARK_COLORS: Dictionary = {
	"iron":     Color(0.85, 0.9, 1.0, 1.0),
	"copper":   Color(1.0, 0.7, 0.45, 1.0),
	"gold":     Color(1.0, 0.95, 0.5, 1.0),
	"amber":    Color(1.0, 0.8, 0.3, 1.0),
	"emerald":  Color(0.4, 1.0, 0.6, 1.0),
	"sapphire": Color(0.4, 0.7, 1.0, 1.0),
	"ruby":     Color(1.0, 0.4, 0.45, 1.0),
	"amethyst": Color(0.85, 0.55, 1.0, 1.0),
}

const ORE_SPARK_AMOUNTS: Dictionary = {
	"iron": 6, "copper": 7, "gold": 10, "amber": 8,
	"emerald": 10, "sapphire": 10, "ruby": 12, "amethyst": 12,
}


func _ready() -> void:
	max_health = health
	_sprite = get_node_or_null("Sprite2D")
	_original_position = position
	_setup_groups()


func take_hit(damage: int = 1) -> void:
	health -= damage
	_flash_hit()
	_shake()
	_spawn_hit_particles()
	if health <= 0:
		call_deferred("_destroy")


func _setup_groups() -> void:
	add_to_group("mineable")
	var hurtbox = get_node_or_null("Hurtbox")
	if hurtbox:
		for g in get_groups():
			hurtbox.add_to_group(g)


func _flash_hit() -> void:
	if _sprite == null:
		return
	var tw := create_tween()
	tw.tween_property(_sprite, "modulate", Color(1, 0.4, 0.3), 0.05)
	tw.tween_property(_sprite, "modulate", Color.WHITE, 0.15)


func _shake() -> void:
	var tw := create_tween()
	tw.tween_property(self, "position", _original_position + Vector2(randf_range(-2, 2), randf_range(-1, 1)), 0.03)
	tw.tween_property(self, "position", _original_position + Vector2(randf_range(-1, 1), randf_range(-1, 1)), 0.03)
	tw.tween_property(self, "position", _original_position, 0.06)


func _spawn_hit_particles() -> void:
	_emit_debris()
	_emit_sparks()
	_emit_flash()
	_emit_smoke()


func _destroy() -> void:
	_spawn_break_particles()
	_spawn_drops(global_position)
	queue_free()


func _spawn_drops(spawn_pos: Vector2) -> void:
	if drop_texture == null:
		return
	var drop_script = load("res://Scripts/Environment/ore_drop.gd")
	if drop_script == null:
		return
	for i in range(drop_count):
		var drop := Area2D.new()
		drop.set_script(drop_script)
		drop.set_meta("ore_type", ore_type)

		var drop_sprite := Sprite2D.new()
		drop_sprite.texture = drop_texture
		drop_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		drop.add_child(drop_sprite)

		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 5.0
		shape.shape = circle
		drop.add_child(shape)

		drop.collision_layer = 8
		drop.collision_mask = 1

		get_parent().add_child(drop)
		drop.global_position = spawn_pos

		var angle := randf() * TAU
		var dist := randf_range(8.0, 18.0)
		var target := drop.global_position + Vector2(cos(angle) * dist, sin(angle) * dist)

		var tw := drop.create_tween()
		tw.set_parallel(true)
		tw.tween_property(drop, "global_position", target, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tw.tween_property(drop_sprite, "position:y", -8.0, 0.15).set_ease(Tween.EASE_OUT)
		tw.chain().tween_property(drop_sprite, "position:y", 0.0, 0.15).set_ease(Tween.EASE_IN)


func _emit_debris() -> void:
	var p := _make_emitter(10, 0.45, 2)

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 140.0
	mat.initial_velocity_min = 30.0
	mat.initial_velocity_max = 65.0
	mat.gravity = Vector3(0, 110, 0)
	mat.scale_min = 1.2
	mat.scale_max = 2.8
	mat.damping_min = 6.0
	mat.damping_max = 14.0
	mat.color = particle_color
	mat.alpha_curve = _make_alpha_curve([Vector2(0.0, 1.0), Vector2(0.5, 0.85), Vector2(1.0, 0.0)])
	mat.scale_curve = _make_scale_curve([Vector2(0.0, 1.0), Vector2(0.6, 0.6), Vector2(1.0, 0.15)])

	p.process_material = mat
	add_child(p)
	p.restart()
	p.emitting = true
	get_tree().create_timer(0.6).timeout.connect(p.queue_free)


func _emit_sparks() -> void:
	var spark_color: Color = ORE_SPARK_COLORS.get(ore_type, Color.WHITE)
	var spark_count: int = ORE_SPARK_AMOUNTS.get(ore_type, 6)

	var p := _make_emitter(spark_count, 0.3, 3)

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 160.0
	mat.initial_velocity_min = 50.0
	mat.initial_velocity_max = 100.0
	mat.gravity = Vector3(0, 60, 0)
	mat.scale_min = 0.6
	mat.scale_max = 1.4
	mat.damping_min = 12.0
	mat.damping_max = 25.0
	mat.color = spark_color
	mat.alpha_curve = _make_alpha_curve([Vector2(0.0, 1.0), Vector2(0.2, 0.9), Vector2(1.0, 0.0)])
	mat.scale_curve = _make_scale_curve([Vector2(0.0, 0.5), Vector2(0.15, 1.0), Vector2(1.0, 0.0)])

	p.process_material = mat
	add_child(p)
	p.restart()
	p.emitting = true
	get_tree().create_timer(0.45).timeout.connect(p.queue_free)


func _emit_flash() -> void:
	var p := _make_emitter(3, 0.12, 4)

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 0, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 0.0
	mat.initial_velocity_max = 8.0
	mat.gravity = Vector3.ZERO
	mat.scale_min = 3.0
	mat.scale_max = 5.0
	mat.color = Color(1.0, 1.0, 1.0, 0.7)
	mat.alpha_curve = _make_alpha_curve([Vector2(0.0, 1.0), Vector2(1.0, 0.0)])

	p.process_material = mat
	add_child(p)
	p.restart()
	p.emitting = true
	get_tree().create_timer(0.2).timeout.connect(p.queue_free)


func _emit_smoke(amount: int = 5, spread_radius: float = 6.0, lifetime: float = 0.5) -> void:
	var p := _make_emitter(amount, lifetime, 1, 0.85)

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 8.0
	mat.initial_velocity_max = 20.0
	mat.gravity = Vector3(0, -12, 0)
	mat.scale_min = 2.0
	mat.scale_max = 4.5
	mat.damping_min = 4.0
	mat.damping_max = 10.0
	mat.color = Color(0.75, 0.7, 0.6, 0.4)
	mat.alpha_curve = _make_alpha_curve([Vector2(0.0, 0.0), Vector2(0.1, 1.0), Vector2(0.4, 0.6), Vector2(1.0, 0.0)])
	mat.scale_curve = _make_scale_curve([Vector2(0.0, 0.4), Vector2(0.3, 1.0), Vector2(1.0, 1.5)])

	p.process_material = mat
	p.position = Vector2(randf_range(-spread_radius, spread_radius), randf_range(-2, 2))
	add_child(p)
	p.restart()
	p.emitting = true
	get_tree().create_timer(lifetime + 0.1).timeout.connect(p.queue_free)


func _spawn_break_particles() -> void:
	var spark_color: Color = ORE_SPARK_COLORS.get(ore_type, Color.WHITE)

	var debris := _make_emitter(20, 0.55, 5)
	var dmat := ParticleProcessMaterial.new()
	dmat.direction = Vector3(0, -1, 0)
	dmat.spread = 180.0
	dmat.initial_velocity_min = 45.0
	dmat.initial_velocity_max = 95.0
	dmat.gravity = Vector3(0, 130, 0)
	dmat.scale_min = 1.5
	dmat.scale_max = 3.5
	dmat.damping_min = 8.0
	dmat.damping_max = 16.0
	dmat.color = particle_color
	dmat.alpha_curve = _make_alpha_curve([Vector2(0.0, 1.0), Vector2(0.55, 0.7), Vector2(1.0, 0.0)])
	dmat.scale_curve = _make_scale_curve([Vector2(0.0, 1.0), Vector2(0.5, 0.5), Vector2(1.0, 0.1)])

	debris.process_material = dmat
	get_parent().add_child(debris)
	debris.global_position = global_position
	debris.restart()
	debris.emitting = true
	get_tree().create_timer(0.7).timeout.connect(debris.queue_free)

	var sparks := _make_emitter(16, 0.4, 6)
	var smat := ParticleProcessMaterial.new()
	smat.direction = Vector3(0, -1, 0)
	smat.spread = 180.0
	smat.initial_velocity_min = 60.0
	smat.initial_velocity_max = 120.0
	smat.gravity = Vector3(0, 80, 0)
	smat.scale_min = 0.8
	smat.scale_max = 1.8
	smat.damping_min = 15.0
	smat.damping_max = 30.0
	smat.color = spark_color
	smat.alpha_curve = _make_alpha_curve([Vector2(0.0, 1.0), Vector2(0.3, 0.85), Vector2(1.0, 0.0)])

	sparks.process_material = smat
	get_parent().add_child(sparks)
	sparks.global_position = global_position
	sparks.restart()
	sparks.emitting = true
	get_tree().create_timer(0.55).timeout.connect(sparks.queue_free)

	_emit_break_smoke()


func _emit_break_smoke() -> void:
	var p := _make_emitter(10, 0.7, 4, 0.8)

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 12.0
	mat.initial_velocity_max = 30.0
	mat.gravity = Vector3(0, -18, 0)
	mat.scale_min = 3.5
	mat.scale_max = 7.0
	mat.damping_min = 5.0
	mat.damping_max = 12.0
	mat.color = Color(0.7, 0.65, 0.55, 0.5)
	mat.alpha_curve = _make_alpha_curve([Vector2(0.0, 0.0), Vector2(0.08, 0.9), Vector2(0.35, 0.5), Vector2(1.0, 0.0)])
	mat.scale_curve = _make_scale_curve([Vector2(0.0, 0.5), Vector2(0.25, 1.0), Vector2(1.0, 1.8)])

	p.process_material = mat
	get_parent().add_child(p)
	p.global_position = global_position
	p.restart()
	p.emitting = true
	get_tree().create_timer(0.9).timeout.connect(p.queue_free)


func _make_emitter(amount: int, lifetime: float, z: int, explosiveness: float = 1.0) -> GPUParticles2D:
	var p := GPUParticles2D.new()
	p.emitting = false
	p.one_shot = true
	p.explosiveness = explosiveness
	p.amount = amount
	p.lifetime = lifetime
	p.z_index = z
	return p


func _make_alpha_curve(points: Array) -> CurveTexture:
	var tex := CurveTexture.new()
	var c := Curve.new()
	for pt in points:
		c.add_point(pt)
	tex.curve = c
	return tex


func _make_scale_curve(points: Array) -> CurveTexture:
	return _make_alpha_curve(points)
