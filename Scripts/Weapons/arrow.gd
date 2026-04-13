extends Area2D

const SPEED: float = 400.0
const MAX_DISTANCE: float = 250.0
const DAMAGE: int = 1

var _direction: Vector2 = Vector2.DOWN
var _traveled: float = 0.0
var _hit_sounds: Array[AudioStream] = []


func setup(dir: String) -> void:
	match dir:
		"up":
			_direction = Vector2.UP
			rotation_degrees = -90
		"down":
			_direction = Vector2.DOWN
			rotation_degrees = 90
		"left":
			_direction = Vector2.LEFT
			rotation_degrees = 180
		"right":
			_direction = Vector2.RIGHT
			rotation_degrees = 0


func _ready() -> void:
	_load_hit_sounds()


func _physics_process(delta: float) -> void:
	var move := _direction * SPEED * delta
	position += move
	_traveled += move.length()
	if _traveled >= MAX_DISTANCE:
		_impact()


func _on_body_entered(_body: Node2D) -> void:
	_impact()


func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("enemy_hurtbox"):
		var enemy = area.get_parent()
		if enemy.has_method("take_damage"):
			enemy.take_damage(DAMAGE)
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
	p.lifetime = 0.3
	p.z_index = 3

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(-_direction.x, -_direction.y, 0.0)
	mat.spread = 35.0
	mat.initial_velocity_min = 40.0
	mat.initial_velocity_max = 80.0
	mat.gravity = Vector3(0, 120, 0)
	mat.damping_min = 20.0
	mat.damping_max = 40.0
	mat.scale_min = 1.0
	mat.scale_max = 2.0
	mat.color = Color(0.85, 0.75, 0.55, 1.0)

	var curve_tex := CurveTexture.new()
	var c := Curve.new()
	c.add_point(Vector2(0.0, 1.0))
	c.add_point(Vector2(1.0, 0.0))
	curve_tex.curve = c
	mat.alpha_curve = curve_tex

	p.process_material = mat
	get_parent().add_child(p)
	p.global_position = global_position
	p.restart()
	p.emitting = true
	get_tree().create_timer(0.5).timeout.connect(p.queue_free)
