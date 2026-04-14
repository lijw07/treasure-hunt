extends Node2D

@export_group("Sword")
@export var sword_slash_color: Color = Color(0.95, 0.95, 1.0, 0.9)
@export var sword_slash_amount: int = 20

@export_group("Tools")
@export var axe_spark_color: Color = Color(1.0, 0.85, 0.4, 1.0)
@export var pickaxe_spark_color: Color = Color(1.0, 0.95, 0.5, 1.0)
@export var hoe_dust_color: Color = Color(0.7, 0.55, 0.35, 0.9)
@export var water_splash_color: Color = Color(0.3, 0.65, 1.0, 0.9)

@export_group("Bow")
@export var arrow_trail_color: Color = Color(1.0, 0.9, 0.5, 0.8)

@export_group("Movement")
@export var grass_color: Color = Color(0.3, 0.75, 0.25, 0.85)
@export var dust_color: Color = Color(0.65, 0.55, 0.4, 0.7)
@export var grass_walk_amount: int = 5
@export var grass_jump_amount: int = 14
@export var grass_roll_amount: int = 8

@export_group("Mount")
@export var summon_smoke_color: Color = Color(0.85, 0.85, 0.85, 0.9)
@export var summon_smoke_amount: int = 24

@export_group("Flash")
@export var flash_color: Color = Color(1.2, 1.2, 1.2, 1.0)
@export var flash_duration: float = 0.1
@export var hitstop_duration: float = 0.06

var _character_node: Node2D
var _weapons_node: Node2D
var _slash_particles: GPUParticles2D
var _impact_particles: GPUParticles2D
var _grass_particles: GPUParticles2D
var _movement_dust: GPUParticles2D
var _summon_particles: GPUParticles2D


func _ready() -> void:
	var player = get_parent()
	_character_node = player.get_node_or_null("Character")
	_weapons_node = player.get_node_or_null("Weapons")

	_slash_particles = _create_burst_emitter("SlashFX", sword_slash_color, sword_slash_amount)
	_impact_particles = _create_burst_emitter("ImpactFX", axe_spark_color, 16)
	_grass_particles = _create_burst_emitter("GrassFX", grass_color, grass_walk_amount)
	_movement_dust = _create_burst_emitter("DustFX", dust_color, 6)
	_summon_particles = _create_burst_emitter("SummonFX", summon_smoke_color, summon_smoke_amount)


func play_sword_fx(dir: String, combo_step: int) -> void:
	var count = sword_slash_amount + combo_step * 6
	var speed = 55.0 + combo_step * 20.0
	_weapon_burst(_slash_particles, dir, 14.0, sword_slash_color, count, 55.0, speed)
	if combo_step >= 3:
		_hitstop()


func play_axe_fx(dir: String) -> void:
	_weapon_burst(_impact_particles, dir, 14.0, axe_spark_color, 16, 70.0, 60.0)


func play_pickaxe_fx(dir: String) -> void:
	_weapon_burst(_impact_particles, dir, 14.0, pickaxe_spark_color, 18, 60.0, 65.0)


func play_hoe_fx(dir: String) -> void:
	_weapon_burst(_impact_particles, dir, 12.0, hoe_dust_color, 12, 100.0, 35.0, 180.0)


func play_water_fx(dir: String) -> void:
	var offset = _dir_offset(dir, 16.0)
	_burst(_impact_particles, global_position + offset, water_splash_color,
		14, _dir_angle(dir), 50.0, 40.0, dir)
	_flash_weapon()


func play_bow_fx(dir: String) -> void:
	_weapon_burst(_slash_particles, dir, 8.0, arrow_trail_color, 10, 30.0, 65.0)


func play_fish_cast_fx(dir: String) -> void:
	var offset = _dir_offset(dir, 18.0)
	_burst(_impact_particles, global_position + offset, water_splash_color,
		12, -90.0, 70.0, 45.0, dir)
	_flash_weapon()


func play_summon_smoke() -> void:
	if _summon_particles == null:
		return
	_summon_particles.position = Vector2.ZERO
	_summon_particles.amount = clampi(summon_smoke_amount, 1, 64)
	_summon_particles.lifetime = 0.6
	_summon_particles.z_index = 1

	var mat: ParticleProcessMaterial = _summon_particles.process_material as ParticleProcessMaterial
	if mat == null:
		return
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 25.0
	mat.initial_velocity_max = 55.0
	mat.gravity = Vector3(0, -20, 0)
	mat.color = summon_smoke_color
	mat.scale_min = 2.0
	mat.scale_max = 4.0

	_summon_particles.restart()
	_summon_particles.emitting = true


func play_walk_grass() -> void:
	_ground_burst(_grass_particles, grass_color, grass_walk_amount, 180.0, 18.0)


func play_jump_grass() -> void:
	_ground_burst(_grass_particles, grass_color, grass_jump_amount, 360.0, 40.0)
	_ground_burst(_movement_dust, dust_color, 8, 360.0, 30.0)


func play_roll_grass() -> void:
	_ground_burst(_grass_particles, grass_color, grass_roll_amount, 360.0, 25.0, 4.0)
	_ground_burst(_movement_dust, dust_color, 5, 180.0, 18.0, 4.0)


func _weapon_burst(emitter: GPUParticles2D, dir: String, dist: float,
		color: Color, amount: int, spread: float, speed: float,
		angle_offset: float = 0.0) -> void:
	var offset = _dir_offset(dir, dist)
	_burst(emitter, global_position + offset, color,
		amount, _dir_angle(dir) + angle_offset, spread, speed, dir)
	_flash_weapon()
	_scale_punch()


func _ground_burst(emitter: GPUParticles2D, color: Color,
		amount: int, spread: float, speed: float, y_offset: float = 6.0) -> void:
	_burst(emitter, global_position + Vector2(0, y_offset), color,
		amount, -90.0, spread, speed, "down")
	emitter.z_index = 0


func _flash_weapon() -> void:
	if _weapons_node == null:
		return
	var sprites: Array[Node] = []
	_collect_sprites(_weapons_node, sprites)
	for s in sprites:
		if s is Sprite2D or s is AnimatedSprite2D:
			var orig_mod: Color = s.modulate
			s.modulate = flash_color
			var tw = create_tween()
			tw.tween_property(s, "modulate", orig_mod, flash_duration)


func _scale_punch() -> void:
	if _character_node == null:
		return
	var orig_scale: Vector2 = _character_node.scale
	var punch_scale: Vector2 = orig_scale * 1.15
	var tw = create_tween()
	tw.tween_property(_character_node, "scale", punch_scale, 0.04)
	tw.tween_property(_character_node, "scale", orig_scale, 0.08).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


func _hitstop() -> void:
	Engine.time_scale = 0.05
	await get_tree().create_timer(hitstop_duration, true, false, true).timeout
	Engine.time_scale = 1.0


func _collect_sprites(node: Node, out: Array[Node]) -> void:
	if node is Sprite2D or node is AnimatedSprite2D:
		out.append(node)
	for child in node.get_children():
		_collect_sprites(child, out)


func _create_burst_emitter(emitter_name: String, color: Color, amount: int) -> GPUParticles2D:
	var p := GPUParticles2D.new()
	p.name = emitter_name
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = 0.4

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 45.0
	mat.initial_velocity_min = 30.0
	mat.initial_velocity_max = 60.0
	mat.gravity = Vector3(0, 80, 0)
	mat.scale_min = 1.2
	mat.scale_max = 2.5
	mat.damping_min = 8.0
	mat.damping_max = 15.0
	mat.color = color

	var alpha_curve := CurveTexture.new()
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(0.4, 0.9))
	curve.add_point(Vector2(1.0, 0.0))
	alpha_curve.curve = curve
	mat.alpha_curve = alpha_curve

	var scale_curve := CurveTexture.new()
	var sc := Curve.new()
	sc.add_point(Vector2(0.0, 1.0))
	sc.add_point(Vector2(0.5, 0.7))
	sc.add_point(Vector2(1.0, 0.2))
	scale_curve.curve = sc
	mat.scale_curve = scale_curve

	p.process_material = mat
	add_child(p)
	return p


func _burst(emitter: GPUParticles2D, pos: Vector2, color: Color,
		amount: int, angle_deg: float, spread: float, speed: float,
		dir: String = "") -> void:
	if emitter == null:
		return
	emitter.position = pos - global_position
	emitter.amount = clampi(amount, 1, 64)

	emitter.z_as_relative = true
	if dir == "down":
		emitter.z_index = -1
	else:
		emitter.z_index = 1

	var mat: ParticleProcessMaterial = emitter.process_material as ParticleProcessMaterial
	if mat == null:
		return

	var rad = deg_to_rad(angle_deg)
	mat.direction = Vector3(cos(rad), sin(rad), 0.0)
	mat.spread = spread
	mat.initial_velocity_min = speed * 0.6
	mat.initial_velocity_max = speed
	mat.color = color

	emitter.restart()
	emitter.emitting = true


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
