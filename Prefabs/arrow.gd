extends Area2D

# ─────────────────────────────────────────────────────────────────────────────
# Arrow Projectile
# Spawned by the Bow — flies in a direction, handles collision, then frees itself.
# ─────────────────────────────────────────────────────────────────────────────

@export var speed: float = 200.0
@export var max_distance: float = 300.0

var direction: Vector2 = Vector2.ZERO
var distance_traveled: float = 0.0

# Per-direction spawn offsets and rotation (set by Bow before adding to scene)
# These values position the arrow relative to the player's origin
const DIRECTION_DATA = {
	"down":  {"offset": Vector2(0, 3),   "rotation": 90.0},
	"right": {"offset": Vector2(2, 3),   "rotation": 0.0},
	"left":  {"offset": Vector2(-2, 2),  "rotation": 180.0},
	"up":    {"offset": Vector2(0, -5),  "rotation": 270.0},
}


func setup(facing: String) -> void:
	var data = DIRECTION_DATA.get(facing, DIRECTION_DATA["down"])
	position += data["offset"]
	rotation_degrees = data["rotation"]

	# Movement direction from facing
	match facing:
		"down":
			direction = Vector2.DOWN
		"up":
			direction = Vector2.UP
		"left":
			direction = Vector2.LEFT
		"right":
			direction = Vector2.RIGHT


func _physics_process(delta: float) -> void:
	if direction == Vector2.ZERO:
		return

	var movement = direction * speed * delta
	position += movement
	distance_traveled += movement.length()

	# Remove arrow after max distance
	if distance_traveled >= max_distance:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	# TODO: deal damage to enemies here
	# if body.has_method("take_damage"):
	#     body.take_damage(1)
	queue_free()


func _on_area_entered(area: Area2D) -> void:
	# TODO: handle hitting other areas (shields, destructibles, etc.)
	pass
