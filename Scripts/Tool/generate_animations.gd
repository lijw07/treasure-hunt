@tool
extends EditorScript

# ─────────────────────────────────────────────────────────────────────────────
# Quick-run animation generator (File > Run)
# Reads configuration from the FastSpriteAnimation plugin's JSON config file.
# For a visual editor, use the dock panel instead (Project > Project Settings >
# Plugins > Fast Sprite Animation).
# ─────────────────────────────────────────────────────────────────────────────

const CONFIG_PATH = "res://addons/FastSpriteAnimation/animation_config.json"


func _run():
	var scene_root = get_scene()
	if scene_root == null:
		printerr("No scene open! Open your player scene first.")
		return

	# Load config
	if not FileAccess.file_exists(CONFIG_PATH):
		printerr("Config file not found at: ", CONFIG_PATH)
		printerr("Open the Fast Sprite Animation dock and save a config first.")
		return

	var file = FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if file == null:
		printerr("Could not open config: ", CONFIG_PATH)
		return

	var json = JSON.new()
	var err = json.parse(file.get_as_text())
	file.close()
	if err != OK:
		printerr("Config JSON parse error: ", json.get_error_message())
		return

	var config = json.data
	var anim_player_path: String = config.get("animation_player_path", "Character/AnimationPlayer")
	var blank_threshold: int = int(config.get("blank_threshold", 10))
	var sprite_groups: Array = config.get("sprite_groups", [])

	# Get AnimationPlayer
	var anim_player = scene_root.get_node_or_null(anim_player_path)
	if anim_player == null:
		printerr("AnimationPlayer not found at: ", anim_player_path)
		return

	# Get or create AnimationLibrary
	var library: AnimationLibrary
	if anim_player.has_animation_library(""):
		library = anim_player.get_animation_library("")
	else:
		library = AnimationLibrary.new()
		anim_player.add_animation_library("", library)

	# Sync hframes/vframes on Sprite2D nodes to match config per group
	for group in sprite_groups:
		var hframes: int = int(group.get("hframes", 9))
		var vframes: int = int(group.get("vframes", 56))
		for path in group.get("sprites", []):
			var sprite = scene_root.get_node_or_null(str(path))
			if sprite != null and sprite is Sprite2D:
				if sprite.hframes != hframes or sprite.vframes != vframes:
					print("Updating '%s': %dx%d -> %dx%d" % [path, sprite.hframes, sprite.vframes, hframes, vframes])
					sprite.hframes = hframes
					sprite.vframes = vframes

	# Collect all unique animation names across all groups
	var all_anim_names = {}
	for group in sprite_groups:
		var anims = group.get("animations", {})
		for anim_name in anims.keys():
			all_anim_names[anim_name] = true

	# Process each animation name, merging tracks from all relevant groups
	for anim_name in all_anim_names.keys():
		var anim = Animation.new()
		anim.loop_mode = Animation.LOOP_LINEAR
		var longest_length = 0.0
		var tracks_added = 0

		for group in sprite_groups:
			var anims = group.get("animations", {})
			if not anims.has(anim_name):
				continue

			var row: int = int(anims[anim_name])
			var hframes: int = int(group.get("hframes", 9))
			var vframes: int = int(group.get("vframes", 56))
			var frame_duration: float = float(group.get("frame_duration", 0.1))

			# Validate row is within bounds
			if row >= vframes:
				print("  Warning: Row %d out of range for '%s' (max %d) — skipping." % [row, anim_name, vframes - 1])
				continue

			# Get nodes for this group
			var sprites = []
			var all_found = true
			for path in group.get("sprites", []):
				var sprite = scene_root.get_node_or_null(str(path))
				if sprite == null:
					printerr("Sprite2D not found at: ", path, " — skipping group")
					all_found = false
					break
				sprites.append(sprite)
			if not all_found:
				continue

			# Use first sprite in group to detect blank frames
			var texture = sprites[0].texture
			if texture == null:
				printerr("No texture on: ", group.get("sprites", ["?"])[0], " — skipping group")
				continue

			var image = texture.get_image()
			var frame_width = image.get_width() / hframes
			var frame_height = image.get_height() / vframes

			# Find valid (non-blank) columns for this row
			var valid_cols = []
			for col in range(hframes):
				if not is_frame_blank(image, col, row, frame_width, frame_height, blank_threshold):
					valid_cols.append(col)

			if valid_cols.is_empty():
				print("  Warning: No valid frames for '", anim_name, "' in group [", group.get("sprites", ["?"])[0], "] row ", row)
				continue

			var group_length = valid_cols.size() * frame_duration
			if group_length > longest_length:
				longest_length = group_length

			# Add one track per sprite in this group
			for sprite in sprites:
				var sprite_path = scene_root.get_path_to(sprite)
				var track_idx = anim.add_track(Animation.TYPE_VALUE)
				anim.track_set_path(track_idx, str(sprite_path) + ":frame")
				anim.track_set_interpolation_type(track_idx, Animation.INTERPOLATION_NEAREST)

				for i in range(valid_cols.size()):
					var col = valid_cols[i]
					var frame_index = row * hframes + col
					var time = i * frame_duration
					anim.track_insert_key(track_idx, time, frame_index)

				tracks_added += 1

		if tracks_added == 0:
			print("Skipping '", anim_name, "' — no valid tracks found across any group")
			continue

		anim.length = longest_length

		# Add or replace in library
		if library.has_animation(anim_name):
			library.remove_animation(anim_name)
		library.add_animation(anim_name, anim)
		print("OK: '", anim_name, "' (", tracks_added, " tracks, ", longest_length, "s)")

	print("Done! All animations generated.")


func is_frame_blank(image: Image, col: int, row: int, frame_width: int, frame_height: int, threshold: int) -> bool:
	var x_start = col * frame_width
	var y_start = row * frame_height
	var non_transparent_pixels = 0

	for x in range(x_start, x_start + frame_width):
		for y in range(y_start, y_start + frame_height):
			var pixel = image.get_pixel(x, y)
			if pixel.a > 0.1:
				non_transparent_pixels += 1
				if non_transparent_pixels >= threshold:
					return false
	return true
