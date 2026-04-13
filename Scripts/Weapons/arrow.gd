extends Area2D

const SPEED: float = 400.0
const MAX_DISTANCE: float = 250.0
const DAMAGE: int = 1

var _direction: Vector2 = Vector2.DOWN
var _traveled: float = 0.0


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


func _physics_process(delta: float) -> void:
	var move := _direction * SPEED * delta
	position += move
	_traveled += move.length()

	if _traveled >= MAX_DISTANCE:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	# Hit a wall / tilemap
	queue_free()


func _on_area_entered(area: Area2D) -> void:
	# Hit an enemy hitbox
	if area.is_in_group("enemy_hurtbox"):
		var enemy = area.get_parent()
		if enemy.has_method("take_damage"):
			enemy.take_damage(DAMAGE)
	queue_free()
