extends Area2D

func _ready() -> void:
	add_to_group("player_hurtbox")
	area_entered.connect(_on_area_entered)


func _on_area_entered(area: Area2D) -> void:
	if not area.is_in_group("enemy_weapon"):
		return
	var player = get_parent()
	if player == null:
		return

	var dmg: int = 1
	if area.get("damage") != null:
		dmg = area.damage
	elif area.get_parent() and area.get_parent().get("damage") != null:
		dmg = area.get_parent().damage

	if player.has_method("take_damage"):
		player.take_damage(dmg)
	if player.has_method("apply_stun"):
		player.apply_stun(area.global_position)
