extends StaticBody2D
## Base script for harvestable resources (trees, rocks, etc.)
## Add to "choppable" or "mineable" group in the scene tree.

@export var resource_type: String = "tree"  # "tree", "rock", etc.
@export var health: int = 3


func _ready() -> void:
	match resource_type:
		"tree":
			add_to_group("choppable")
		"rock":
			add_to_group("mineable")
	# Make the Hurtbox also carry the group for easy detection
	var hurtbox = get_node_or_null("Hurtbox")
	if hurtbox:
		for g in get_groups():
			hurtbox.add_to_group(g)


func take_hit(damage: int = 1) -> void:
	health -= damage
	# Brief flash to show hit registered
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1, 0.5, 0.5), 0.05)
	tween.tween_property(self, "modulate", Color.WHITE, 0.15)
	if health <= 0:
		_destroy()


func _destroy() -> void:
	# TODO: spawn drops, particles, etc.
	queue_free()
