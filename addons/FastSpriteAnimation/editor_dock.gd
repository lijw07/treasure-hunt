@tool
extends Control

# ─────────────────────────────────────────────────────────────────────────────
# Fast Sprite Animation — Editor Dock
# Provides a visual UI for configuring and generating sprite-sheet animations
# with support for layered characters and merged animation tracks.
#
# Key feature: each sprite group has its own hframes/vframes/row mapping,
# so sprites with completely different sheet layouts (e.g. a 9x56 body sheet
# and a 4x9 sword sheet) can share animation names and be merged correctly.
# ─────────────────────────────────────────────────────────────────────────────

var editor_plugin: EditorPlugin

# ── Config state ──────────────────────────────────────────────────────────────
var config := {
	"animation_player_path": "Character/AnimationPlayer",
	"blank_threshold": 10,
	"frame_size": 64,
	"sprite_groups": []
}

const CONFIG_DIR = "res://addons/FastSpriteAnimation/configs/"
const LEGACY_CONFIG_PATH = "res://addons/FastSpriteAnimation/animation_config.json"
var current_profile: String = "default"

# ── UI references (built in _ready) ──────────────────────────────────────────
var profile_dropdown: OptionButton
var new_profile_edit: LineEdit
var anim_player_dropdown: OptionButton
var blank_threshold_spin: SpinBox
var frame_size_spin: SpinBox
var groups_container: VBoxContainer

# ── Validation colours ────────────────────────────────────────────────────────
const COLOR_VALID = Color(0.5, 1.0, 0.5, 0.15)
const COLOR_INVALID = Color(1.0, 0.3, 0.3, 0.15)
const COLOR_NONE = Color(0, 0, 0, 0)


# ─────────────────────────────────────────────────────────────────────────────
# INITIALIZATION
# ─────────────────────────────────────────────────────────────────────────────

func _ready():
	custom_minimum_size = Vector2(300, 400)
	_ensure_config_dir()
	_migrate_legacy_config()
	_build_ui()
	_load_config()
	_refresh_groups_ui()


# ─────────────────────────────────────────────────────────────────────────────
# HELPERS — editor-themed labels
# ─────────────────────────────────────────────────────────────────────────────

func _make_header(text: String) -> Label:
	var label = Label.new()
	label.text = text
	var bold_font = get_theme_font("bold", "EditorFonts")
	if bold_font:
		label.add_theme_font_override("font", bold_font)
	return label


func _make_label(text: String) -> Label:
	var label = Label.new()
	label.text = text
	return label


# ─────────────────────────────────────────────────────────────────────────────
# CONFIG DIRECTORY & PROFILE MANAGEMENT
# ─────────────────────────────────────────────────────────────────────────────

func _ensure_config_dir():
	if not DirAccess.dir_exists_absolute(CONFIG_DIR):
		DirAccess.make_dir_recursive_absolute(CONFIG_DIR)


func _migrate_legacy_config():
	# If old single config exists and no default profile yet, migrate it
	if FileAccess.file_exists(LEGACY_CONFIG_PATH):
		var default_path = CONFIG_DIR + "default.json"
		if not FileAccess.file_exists(default_path):
			var file = FileAccess.open(LEGACY_CONFIG_PATH, FileAccess.READ)
			if file:
				var content = file.get_as_text()
				file.close()
				var out = FileAccess.open(default_path, FileAccess.WRITE)
				if out:
					out.store_string(content)
					out.close()
				_log("Migrated legacy config to configs/default.json")


func _get_config_path() -> String:
	return CONFIG_DIR + current_profile + ".json"


func _list_profiles() -> Array:
	var profiles: Array = []
	var dir = DirAccess.open(CONFIG_DIR)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".json"):
				profiles.append(file_name.get_basename())
			file_name = dir.get_next()
		dir.list_dir_end()
	if profiles.is_empty():
		profiles.append("default")
	profiles.sort()
	return profiles


# ─────────────────────────────────────────────────────────────────────────────
# SCENE SCANNING — find nodes of a given type in the open scene
# ─────────────────────────────────────────────────────────────────────────────

func _scan_nodes_of_type(type_name: String) -> Array:
	var results: Array = []
	var scene_root = EditorInterface.get_edited_scene_root()
	if scene_root == null:
		return results
	_scan_recursive(scene_root, scene_root, type_name, results)
	return results


func _scan_recursive(node: Node, root: Node, type_name: String, results: Array):
	if node.is_class(type_name):
		var path = str(root.get_path_to(node))
		results.append(path)
	for child in node.get_children():
		_scan_recursive(child, root, type_name, results)


# ─────────────────────────────────────────────────────────────────────────────
# DROPDOWN HELPERS
# ─────────────────────────────────────────────────────────────────────────────

func _select_dropdown_item(dropdown: OptionButton, value: String):
	for i in range(dropdown.item_count):
		if dropdown.get_item_text(i) == value:
			dropdown.select(i)
			return
	if dropdown.item_count > 0:
		dropdown.select(0)


func _select_dropdown_by_metadata(dropdown: OptionButton, value: String):
	for i in range(dropdown.item_count):
		if str(dropdown.get_item_metadata(i)) == value:
			dropdown.select(i)
			return
	if dropdown.item_count > 0:
		dropdown.select(0)


# ─────────────────────────────────────────────────────────────────────────────
# VALIDATION
# ─────────────────────────────────────────────────────────────────────────────

func _validate_anim_player_dropdown():
	if anim_player_dropdown == null:
		return
	var scene_root = EditorInterface.get_edited_scene_root()
	var path = config["animation_player_path"]
	if scene_root == null or path == "":
		anim_player_dropdown.tooltip_text = ""
		return
	var node = scene_root.get_node_or_null(path)
	if node != null and node is AnimationPlayer:
		anim_player_dropdown.tooltip_text = "Valid AnimationPlayer found"
	else:
		if node == null:
			anim_player_dropdown.tooltip_text = "Node not found at this path"
		else:
			anim_player_dropdown.tooltip_text = "Node is %s, not AnimationPlayer" % node.get_class()


# ─────────────────────────────────────────────────────────────────────────────
# UI CONSTRUCTION
# ─────────────────────────────────────────────────────────────────────────────

func _build_ui():
	# Root scroll
	var scroll = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.follow_focus = true
	add_child(scroll)

	var margin = MarginContainer.new()
	margin.size_flags_horizontal = SIZE_EXPAND_FILL
	margin.size_flags_vertical = SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 4)
	margin.add_theme_constant_override("margin_right", 4)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	scroll.add_child(margin)

	var root_vbox = VBoxContainer.new()
	root_vbox.size_flags_horizontal = SIZE_EXPAND_FILL
	root_vbox.size_flags_vertical = SIZE_EXPAND_FILL
	margin.add_child(root_vbox)

	# ── Title ─────────────────────────────────────────────────────────────
	var title = _make_header("Fast Sprite Animation")
	root_vbox.add_child(title)
	root_vbox.add_child(HSeparator.new())

	# ── Config Profile ────────────────────────────────────────────────────
	root_vbox.add_child(_make_header("Config Profile"))

	var profile_row = HBoxContainer.new()
	profile_row.size_flags_horizontal = SIZE_EXPAND_FILL

	profile_dropdown = OptionButton.new()
	profile_dropdown.size_flags_horizontal = SIZE_EXPAND_FILL
	_refresh_profile_list()
	profile_dropdown.item_selected.connect(_on_profile_selected)
	profile_row.add_child(profile_dropdown)

	var save_profile_btn = Button.new()
	save_profile_btn.text = "Save"
	save_profile_btn.pressed.connect(_on_save_config)
	profile_row.add_child(save_profile_btn)

	var delete_profile_btn = Button.new()
	delete_profile_btn.text = "Delete"
	delete_profile_btn.pressed.connect(_on_delete_profile)
	profile_row.add_child(delete_profile_btn)

	root_vbox.add_child(profile_row)

	# Save-As row
	var save_as_row = HBoxContainer.new()
	save_as_row.size_flags_horizontal = SIZE_EXPAND_FILL

	save_as_row.add_child(_make_label("New:"))
	new_profile_edit = LineEdit.new()
	new_profile_edit.placeholder_text = "profile_name"
	new_profile_edit.size_flags_horizontal = SIZE_EXPAND_FILL
	save_as_row.add_child(new_profile_edit)

	var create_btn = Button.new()
	create_btn.text = "Create"
	create_btn.pressed.connect(_on_save_as_profile)
	save_as_row.add_child(create_btn)

	root_vbox.add_child(save_as_row)
	root_vbox.add_child(HSeparator.new())

	# ── Global Settings ───────────────────────────────────────────────────
	var settings_label = _make_header("Global Settings")
	root_vbox.add_child(settings_label)

	# AnimationPlayer picker
	root_vbox.add_child(_make_label("AnimationPlayer:"))

	anim_player_dropdown = OptionButton.new()
	anim_player_dropdown.size_flags_horizontal = SIZE_EXPAND_FILL
	anim_player_dropdown.get_popup().about_to_popup.connect(_refresh_anim_player_list)
	anim_player_dropdown.item_selected.connect(_on_anim_player_selected)
	root_vbox.add_child(anim_player_dropdown)

	# Populate initial list
	_refresh_anim_player_list()
	_select_dropdown_by_metadata(anim_player_dropdown, config["animation_player_path"])

	# Blank threshold + Frame size on one row
	var settings_grid = GridContainer.new()
	settings_grid.columns = 4
	settings_grid.size_flags_horizontal = SIZE_EXPAND_FILL

	settings_grid.add_child(_make_label("Blank Threshold:"))
	blank_threshold_spin = SpinBox.new()
	blank_threshold_spin.min_value = 1
	blank_threshold_spin.max_value = 1000
	blank_threshold_spin.value = config["blank_threshold"]
	blank_threshold_spin.size_flags_horizontal = SIZE_EXPAND_FILL
	blank_threshold_spin.value_changed.connect(_on_blank_threshold_changed)
	settings_grid.add_child(blank_threshold_spin)

	settings_grid.add_child(_make_label("Frame Size:"))
	frame_size_spin = SpinBox.new()
	frame_size_spin.min_value = 8
	frame_size_spin.max_value = 512
	frame_size_spin.value = config.get("frame_size", 64)
	frame_size_spin.suffix = "px"
	frame_size_spin.size_flags_horizontal = SIZE_EXPAND_FILL
	frame_size_spin.tooltip_text = "Used by Auto-Detect to calculate hframes/vframes from texture size"
	frame_size_spin.value_changed.connect(_on_frame_size_changed)
	settings_grid.add_child(frame_size_spin)

	root_vbox.add_child(settings_grid)
	root_vbox.add_child(HSeparator.new())

	# ── Sprite Groups header + Add button ─────────────────────────────────
	var groups_header = HBoxContainer.new()
	var groups_label = _make_header("Sprite Groups")
	groups_label.size_flags_horizontal = SIZE_EXPAND_FILL
	groups_header.add_child(groups_label)

	var add_group_btn = Button.new()
	add_group_btn.text = "+ Add Group"
	add_group_btn.pressed.connect(_on_add_group)
	groups_header.add_child(add_group_btn)
	root_vbox.add_child(groups_header)

	# Container that holds all group panels
	groups_container = VBoxContainer.new()
	groups_container.size_flags_horizontal = SIZE_EXPAND_FILL
	root_vbox.add_child(groups_container)

	root_vbox.add_child(HSeparator.new())

	# ── Generate button ───────────────────────────────────────────────────
	var generate_btn = Button.new()
	generate_btn.text = "Generate Animations"
	generate_btn.size_flags_horizontal = SIZE_EXPAND_FILL
	generate_btn.custom_minimum_size.y = 32
	generate_btn.pressed.connect(_on_generate)
	root_vbox.add_child(generate_btn)


# ─────────────────────────────────────────────────────────────────────────────
# REFRESH HELPERS — populate dropdowns
# ─────────────────────────────────────────────────────────────────────────────

func _refresh_profile_list():
	if profile_dropdown == null:
		return
	profile_dropdown.clear()
	var profiles = _list_profiles()
	for p in profiles:
		profile_dropdown.add_item(p)
	_select_dropdown_item(profile_dropdown, current_profile)


func _refresh_anim_player_list():
	if anim_player_dropdown == null:
		return
	var current_path = config["animation_player_path"]
	anim_player_dropdown.clear()

	var paths = _scan_nodes_of_type("AnimationPlayer")

	# If current config path not in discovered list, show it as a manual entry
	if current_path != "" and not paths.has(current_path):
		anim_player_dropdown.add_item(current_path + " (manual)")
		anim_player_dropdown.set_item_metadata(0, current_path)

	for path in paths:
		var idx = anim_player_dropdown.item_count
		anim_player_dropdown.add_item(path)
		anim_player_dropdown.set_item_metadata(idx, path)

	_select_dropdown_by_metadata(anim_player_dropdown, current_path)
	_validate_anim_player_dropdown()


func _refresh_sprite_dropdown(dropdown: OptionButton):
	dropdown.clear()
	var paths = _scan_nodes_of_type("Sprite2D")
	for path in paths:
		dropdown.add_item(path)


# ─────────────────────────────────────────────────────────────────────────────
# GROUP UI — each group is a panel with its own grid settings
# ─────────────────────────────────────────────────────────────────────────────

func _refresh_groups_ui():
	# Clear existing
	for child in groups_container.get_children():
		child.queue_free()

	for group_idx in range(config["sprite_groups"].size()):
		var group = config["sprite_groups"][group_idx]
		var panel = _build_group_panel(group_idx, group)
		groups_container.add_child(panel)


func _build_group_panel(group_idx: int, group: Dictionary) -> PanelContainer:
	var panel = PanelContainer.new()

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	# ── Group header ──────────────────────────────────────────────────────
	var header = HBoxContainer.new()

	var sprites_list: Array = group.get("sprites", [])
	var display_name = sprites_list[0].get_file() if sprites_list.size() > 0 else "(empty)"
	var group_label = _make_header("Group %d — %s" % [group_idx, display_name])
	group_label.size_flags_horizontal = SIZE_EXPAND_FILL
	header.add_child(group_label)

	var remove_group_btn = Button.new()
	remove_group_btn.text = "Remove"
	remove_group_btn.pressed.connect(_on_remove_group.bind(group_idx))
	header.add_child(remove_group_btn)
	vbox.add_child(header)

	# ── Sprite paths (list with dropdown picker) ─────────────────────────
	vbox.add_child(_make_label("Sprite Paths:"))

	# Current sprites shown as label + remove button rows
	var sprites_vbox = VBoxContainer.new()
	sprites_vbox.name = "SpritesContainer"
	for sprite_path in sprites_list:
		var sprite_row = _build_sprite_row(group_idx, sprite_path, sprites_vbox)
		sprites_vbox.add_child(sprite_row)
	vbox.add_child(sprites_vbox)

	# Dropdown picker + Add button
	var picker_row = HBoxContainer.new()
	picker_row.size_flags_horizontal = SIZE_EXPAND_FILL

	var sprite_dropdown = OptionButton.new()
	sprite_dropdown.size_flags_horizontal = SIZE_EXPAND_FILL
	sprite_dropdown.get_popup().about_to_popup.connect(_refresh_sprite_dropdown.bind(sprite_dropdown))
	_refresh_sprite_dropdown(sprite_dropdown)
	picker_row.add_child(sprite_dropdown)

	var add_sprite_btn = Button.new()
	add_sprite_btn.text = "+ Add"
	add_sprite_btn.pressed.connect(_on_add_sprite.bind(group_idx, sprite_dropdown, sprites_vbox))
	picker_row.add_child(add_sprite_btn)

	vbox.add_child(picker_row)

	# ── Sheet dimensions ──────────────────────────────────────────────────
	var dims_grid = GridContainer.new()
	dims_grid.columns = 6
	dims_grid.size_flags_horizontal = SIZE_EXPAND_FILL

	dims_grid.add_child(_make_label("H:"))
	var hf_spin = SpinBox.new()
	hf_spin.min_value = 1
	hf_spin.max_value = 100
	hf_spin.value = group.get("hframes", 9)
	hf_spin.size_flags_horizontal = SIZE_EXPAND_FILL
	hf_spin.value_changed.connect(_on_hframes_changed.bind(group_idx))
	dims_grid.add_child(hf_spin)

	dims_grid.add_child(_make_label("V:"))
	var vf_spin = SpinBox.new()
	vf_spin.min_value = 1
	vf_spin.max_value = 200
	vf_spin.value = group.get("vframes", 56)
	vf_spin.size_flags_horizontal = SIZE_EXPAND_FILL
	vf_spin.value_changed.connect(_on_vframes_changed.bind(group_idx))
	dims_grid.add_child(vf_spin)

	dims_grid.add_child(_make_label("Dur:"))
	var fd_spin = SpinBox.new()
	fd_spin.min_value = 0.01
	fd_spin.max_value = 2.0
	fd_spin.step = 0.01
	fd_spin.value = group.get("frame_duration", 0.1)
	fd_spin.suffix = "s"
	fd_spin.size_flags_horizontal = SIZE_EXPAND_FILL
	fd_spin.value_changed.connect(_on_frame_duration_changed.bind(group_idx))
	dims_grid.add_child(fd_spin)

	vbox.add_child(dims_grid)

	# ── Z-order option ───────────────────────────────────────────────────
	var z_row = HBoxContainer.new()
	z_row.size_flags_horizontal = SIZE_EXPAND_FILL

	var z_behind_cb = CheckBox.new()
	z_behind_cb.text = "Behind on Up"
	z_behind_cb.tooltip_text = "Draw sprites in this group behind other groups when animation faces up (fixes weapon/tool layering)"
	z_behind_cb.button_pressed = group.get("z_behind_on_up", false)
	z_behind_cb.toggled.connect(_on_z_behind_changed.bind(group_idx))
	z_row.add_child(z_behind_cb)

	vbox.add_child(z_row)

	# ── Auto-detect + Scan row ────────────────────────────────────────────
	var tool_grid = GridContainer.new()
	tool_grid.columns = 2
	tool_grid.size_flags_horizontal = SIZE_EXPAND_FILL

	var auto_detect_btn = Button.new()
	auto_detect_btn.text = "Auto-Detect Grid"
	auto_detect_btn.tooltip_text = "Read the first sprite's texture size and calculate hframes/vframes using the global Frame Size"
	auto_detect_btn.size_flags_horizontal = SIZE_EXPAND_FILL
	auto_detect_btn.pressed.connect(_on_auto_detect_grid.bind(group_idx))
	tool_grid.add_child(auto_detect_btn)

	var scan_btn = Button.new()
	scan_btn.text = "Scan Rows"
	scan_btn.tooltip_text = "Scan the sprite sheet to find which rows contain non-blank frames"
	scan_btn.size_flags_horizontal = SIZE_EXPAND_FILL
	scan_btn.pressed.connect(_on_scan_rows.bind(group_idx))
	tool_grid.add_child(scan_btn)

	vbox.add_child(tool_grid)

	# ── Grid info label (shows detected texture info) ─────────────────────
	var info_text: String = group.get("_info", "")
	if info_text != "":
		var info_label = _make_label(info_text)
		info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(info_label)

	# ── Animations list ───────────────────────────────────────────────────
	var anims_header = HBoxContainer.new()
	var anims_label = _make_header("Animations:")
	anims_label.size_flags_horizontal = SIZE_EXPAND_FILL
	anims_header.add_child(anims_label)

	# Container just for animation rows — so add/remove can target it
	var anims_container = VBoxContainer.new()
	anims_container.name = "AnimsContainer"

	var add_anim_btn = Button.new()
	add_anim_btn.text = "+ Add"
	add_anim_btn.pressed.connect(_on_add_animation.bind(group_idx, anims_container))
	anims_header.add_child(add_anim_btn)
	vbox.add_child(anims_header)

	var animations: Array = group.get("animations", [])
	for anim_entry in animations:
		var anim_row = _build_animation_row(group_idx, anim_entry)
		anims_container.add_child(anim_row)

	vbox.add_child(anims_container)
	vbox.add_child(HSeparator.new())
	return panel


func _build_sprite_row(group_idx: int, sprite_path: String, sprites_vbox: VBoxContainer) -> HBoxContainer:
	var hbox = HBoxContainer.new()
	hbox.size_flags_horizontal = SIZE_EXPAND_FILL

	var path_label = Label.new()
	path_label.text = sprite_path
	path_label.size_flags_horizontal = SIZE_EXPAND_FILL
	path_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	hbox.add_child(path_label)

	# Colour the path green/red based on whether it resolves to a Sprite2D
	var scene_root = EditorInterface.get_edited_scene_root()
	if scene_root:
		var node = scene_root.get_node_or_null(sprite_path)
		if node != null and node is Sprite2D:
			path_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
			path_label.tooltip_text = "Valid Sprite2D"
		else:
			path_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
			if node == null:
				path_label.tooltip_text = "Node not found"
			else:
				path_label.tooltip_text = "Node is %s, not Sprite2D" % node.get_class()

	var remove_btn = Button.new()
	remove_btn.text = "X"
	remove_btn.custom_minimum_size.x = 28
	remove_btn.pressed.connect(_on_remove_sprite.bind(group_idx, sprite_path, hbox, sprites_vbox))
	hbox.add_child(remove_btn)

	return hbox


func _build_animation_row(group_idx: int, anim_entry: Dictionary) -> HBoxContainer:
	# anim_entry is a reference — changes here go straight to config
	var hbox = HBoxContainer.new()
	hbox.set_meta("anim_entry", anim_entry)

	var name_edit = LineEdit.new()
	name_edit.text = anim_entry.get("name", "")
	name_edit.placeholder_text = "animation_name"
	name_edit.size_flags_horizontal = SIZE_EXPAND_FILL
	name_edit.text_submitted.connect(_on_anim_name_changed.bind(group_idx, anim_entry, name_edit))
	name_edit.focus_exited.connect(_on_anim_name_focus_lost.bind(group_idx, anim_entry, name_edit))
	hbox.add_child(name_edit)

	var row_label = _make_label("Row:")
	hbox.add_child(row_label)

	var row_spin = SpinBox.new()
	row_spin.min_value = 0
	row_spin.max_value = 200
	row_spin.value = anim_entry.get("row", 0)
	row_spin.custom_minimum_size.x = 60
	row_spin.value_changed.connect(_on_anim_row_changed.bind(anim_entry))
	hbox.add_child(row_spin)

	# Flip checkboxes
	var flip_h_cb = CheckBox.new()
	flip_h_cb.text = "H"
	flip_h_cb.tooltip_text = "Flip Horizontal — mirror this animation (e.g. right → left)"
	flip_h_cb.button_pressed = anim_entry.get("flip_h", false)
	flip_h_cb.toggled.connect(_on_anim_flip_h_changed.bind(anim_entry))
	hbox.add_child(flip_h_cb)

	var flip_v_cb = CheckBox.new()
	flip_v_cb.text = "V"
	flip_v_cb.tooltip_text = "Flip Vertical — invert this animation vertically"
	flip_v_cb.button_pressed = anim_entry.get("flip_v", false)
	flip_v_cb.toggled.connect(_on_anim_flip_v_changed.bind(anim_entry))
	hbox.add_child(flip_v_cb)

	var remove_btn = Button.new()
	remove_btn.text = "X"
	remove_btn.custom_minimum_size.x = 28
	remove_btn.pressed.connect(_on_remove_animation.bind(group_idx, anim_entry, hbox))
	hbox.add_child(remove_btn)

	return hbox


# ─────────────────────────────────────────────────────────────────────────────
# UI CALLBACKS — Profile Management
# ─────────────────────────────────────────────────────────────────────────────

func _on_profile_selected(idx: int):
	current_profile = profile_dropdown.get_item_text(idx)
	_load_config()
	_refresh_groups_ui()
	_log("Loaded profile: %s" % current_profile)


func _on_save_as_profile():
	var new_name = new_profile_edit.text.strip_edges().replace(" ", "_")
	if new_name == "" or not new_name.is_valid_identifier():
		_log("Invalid profile name. Use letters, numbers, and underscores only.")
		return
	current_profile = new_name
	_save_config()
	_refresh_profile_list()
	new_profile_edit.text = ""
	_log("Created and saved profile: %s" % current_profile)


func _on_delete_profile():
	if current_profile == "default":
		_log("Cannot delete the default profile.")
		return
	var path = _get_config_path()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
		_log("Deleted profile: %s" % current_profile)
	current_profile = "default"
	_refresh_profile_list()
	_load_config()
	_refresh_groups_ui()


# ─────────────────────────────────────────────────────────────────────────────
# UI CALLBACKS — Global Settings
# ─────────────────────────────────────────────────────────────────────────────

func _on_anim_player_selected(idx: int):
	var meta = anim_player_dropdown.get_item_metadata(idx)
	if meta != null:
		config["animation_player_path"] = str(meta)
	else:
		config["animation_player_path"] = anim_player_dropdown.get_item_text(idx)
	_validate_anim_player_dropdown()

func _on_blank_threshold_changed(value: float):
	config["blank_threshold"] = int(value)

func _on_frame_size_changed(value: float):
	config["frame_size"] = int(value)


# ─────────────────────────────────────────────────────────────────────────────
# UI CALLBACKS — Group Management
# ─────────────────────────────────────────────────────────────────────────────

func _on_add_group():
	config["sprite_groups"].append({
		"sprites": [],
		"hframes": 9,
		"vframes": 56,
		"frame_duration": 0.1,
		"z_behind_on_up": false,
		"animations": []
	})
	_refresh_groups_ui()


func _on_remove_group(group_idx: int):
	config["sprite_groups"].remove_at(group_idx)
	_refresh_groups_ui()


func _on_hframes_changed(value: float, group_idx: int):
	config["sprite_groups"][group_idx]["hframes"] = int(value)

func _on_vframes_changed(value: float, group_idx: int):
	config["sprite_groups"][group_idx]["vframes"] = int(value)

func _on_frame_duration_changed(value: float, group_idx: int):
	config["sprite_groups"][group_idx]["frame_duration"] = value

func _on_z_behind_changed(pressed: bool, group_idx: int):
	config["sprite_groups"][group_idx]["z_behind_on_up"] = pressed


# ─────────────────────────────────────────────────────────────────────────────
# UI CALLBACKS — Sprite Management (dropdown picker)
# ─────────────────────────────────────────────────────────────────────────────

func _on_add_sprite(group_idx: int, dropdown: OptionButton, sprites_vbox: VBoxContainer):
	if dropdown.selected < 0 or dropdown.item_count == 0:
		_log("No Sprite2D nodes found in scene. Open your player scene first.")
		return
	var path = dropdown.get_item_text(dropdown.selected)
	var sprites: Array = config["sprite_groups"][group_idx]["sprites"]
	# Don't add duplicates
	if sprites.has(path):
		_log("Sprite '%s' already in group %d." % [path, group_idx])
		return
	sprites.append(path)
	var sprite_row = _build_sprite_row(group_idx, path, sprites_vbox)
	sprites_vbox.add_child(sprite_row)


func _on_remove_sprite(group_idx: int, sprite_path: String, hbox: HBoxContainer, _sprites_vbox: VBoxContainer):
	var sprites: Array = config["sprite_groups"][group_idx]["sprites"]
	var idx = sprites.find(sprite_path)
	if idx >= 0:
		sprites.remove_at(idx)
	hbox.queue_free()


# ─────────────────────────────────────────────────────────────────────────────
# UI CALLBACKS — Animation Management
# ─────────────────────────────────────────────────────────────────────────────

func _on_add_animation(group_idx: int, anims_container: VBoxContainer):
	var anims: Array = config["sprite_groups"][group_idx]["animations"]
	# Generate a unique default name
	var idx = anims.size()
	var anim_name = "new_animation_%d" % idx
	while _anim_name_exists(anims, anim_name):
		idx += 1
		anim_name = "new_animation_%d" % idx
	var entry = {"name": anim_name, "row": 0, "flip_h": false, "flip_v": false}
	anims.append(entry)
	# Only add the new row — don't rebuild everything
	var anim_row = _build_animation_row(group_idx, entry)
	anims_container.add_child(anim_row)


func _on_remove_animation(group_idx: int, anim_entry: Dictionary, hbox: HBoxContainer):
	var anims: Array = config["sprite_groups"][group_idx]["animations"]
	var idx = anims.find(anim_entry)
	if idx >= 0:
		anims.remove_at(idx)
	hbox.queue_free()


func _on_anim_name_changed(new_name: String, group_idx: int, anim_entry: Dictionary, name_edit: LineEdit):
	_commit_anim_rename(group_idx, anim_entry, name_edit, new_name)

func _on_anim_name_focus_lost(group_idx: int, anim_entry: Dictionary, name_edit: LineEdit):
	_commit_anim_rename(group_idx, anim_entry, name_edit, name_edit.text)

func _commit_anim_rename(group_idx: int, anim_entry: Dictionary, name_edit: LineEdit, new_name: String):
	var old_name: String = anim_entry.get("name", "")
	var clean_name = new_name.strip_edges()
	if clean_name == "" or clean_name == old_name:
		return
	var anims: Array = config["sprite_groups"][group_idx]["animations"]
	if _anim_name_exists(anims, clean_name):
		# Name collision — revert the LineEdit text
		name_edit.text = old_name
		return
	anim_entry["name"] = clean_name


func _on_anim_row_changed(value: float, anim_entry: Dictionary):
	anim_entry["row"] = int(value)

func _on_anim_flip_h_changed(pressed: bool, anim_entry: Dictionary):
	anim_entry["flip_h"] = pressed

func _on_anim_flip_v_changed(pressed: bool, anim_entry: Dictionary):
	anim_entry["flip_v"] = pressed

func _anim_name_exists(anims: Array, name: String) -> bool:
	for entry in anims:
		if entry.get("name", "") == name:
			return true
	return false


func _anim_has_flip(sprite_groups: Array, anim_name: String) -> bool:
	for group in sprite_groups:
		for entry in group.get("animations", []):
			if entry.get("name", "") == anim_name:
				if entry.get("flip_h", false) or entry.get("flip_v", false):
					return true
	return false


# ─────────────────────────────────────────────────────────────────────────────
# AUTO-DETECT GRID — reads the first sprite's texture to calculate hframes/vframes
# ─────────────────────────────────────────────────────────────────────────────

func _on_auto_detect_grid(group_idx: int):
	var group = config["sprite_groups"][group_idx]
	var sprite_paths: Array = group.get("sprites", [])
	if sprite_paths.is_empty():
		_log("Auto-Detect: No sprites listed in group %d." % group_idx)
		return

	var scene_root = EditorInterface.get_edited_scene_root()
	if scene_root == null:
		_log("Auto-Detect: No scene open.")
		return

	var sprite = scene_root.get_node_or_null(str(sprite_paths[0]))
	if sprite == null:
		_log("Auto-Detect: Could not find node '%s'." % sprite_paths[0])
		return

	if not (sprite is Sprite2D):
		_log("Auto-Detect: Node '%s' is not a Sprite2D." % sprite_paths[0])
		return

	var texture = sprite.texture
	if texture == null:
		_log("Auto-Detect: No texture on '%s'." % sprite_paths[0])
		return

	var image = texture.get_image()
	if image == null:
		_log("Auto-Detect: Could not get image from texture.")
		return

	var frame_size: int = int(config.get("frame_size", 64))
	var tex_width = image.get_width()
	var tex_height = image.get_height()
	var detected_h = tex_width / frame_size
	var detected_v = tex_height / frame_size
	var remainder_w = tex_width % frame_size
	var remainder_h = tex_height % frame_size

	group["hframes"] = detected_h
	group["vframes"] = detected_v

	var info = "Texture: %dx%d | Grid: %dx%d" % [tex_width, tex_height, detected_h, detected_v]
	if remainder_w != 0 or remainder_h != 0:
		info += " (WARNING: %dpx remainder)" % max(remainder_w, remainder_h)
	group["_info"] = info

	_log("Auto-Detect group %d: %s -> %dx%d grid (%dpx frames)" % [
		group_idx, sprite_paths[0], detected_h, detected_v, frame_size])

	_refresh_groups_ui()


# ─────────────────────────────────────────────────────────────────────────────
# SCAN ROWS — scans the sprite sheet to show which rows have content
# ─────────────────────────────────────────────────────────────────────────────

func _on_scan_rows(group_idx: int):
	var group = config["sprite_groups"][group_idx]
	var sprite_paths: Array = group.get("sprites", [])
	if sprite_paths.is_empty():
		_log("Scan: No sprites listed in group %d." % group_idx)
		return

	var scene_root = EditorInterface.get_edited_scene_root()
	if scene_root == null:
		_log("Scan: No scene open.")
		return

	var sprite = scene_root.get_node_or_null(str(sprite_paths[0]))
	if sprite == null or not (sprite is Sprite2D):
		_log("Scan: Could not find Sprite2D at '%s'." % sprite_paths[0])
		return

	var texture = sprite.texture
	if texture == null:
		_log("Scan: No texture on '%s'." % sprite_paths[0])
		return

	var image = texture.get_image()
	if image == null:
		_log("Scan: Could not get image from texture.")
		return

	var hframes: int = int(group.get("hframes", 9))
	var vframes: int = int(group.get("vframes", 56))
	var blank_threshold: int = int(config["blank_threshold"])
	var frame_width: int = image.get_width() / hframes
	var frame_height: int = image.get_height() / vframes

	_log("")
	_log("=== Scanning group %d: %s (%dx%d grid) ===" % [group_idx, sprite_paths[0], hframes, vframes])

	for row_idx in range(vframes):
		var valid_cols := []
		for col in range(hframes):
			if not _is_frame_blank(image, col, row_idx, frame_width, frame_height, blank_threshold):
				valid_cols.append(col)
		if valid_cols.size() > 0:
			_log("  Row %2d: %d frames (cols %d-%d)" % [row_idx, valid_cols.size(), valid_cols[0], valid_cols[-1]])

	_log("=== Scan complete ===")
	_log("")


# ─────────────────────────────────────────────────────────────────────────────
# SAVE / LOAD CONFIG
# ─────────────────────────────────────────────────────────────────────────────

func _on_save_config():
	_save_config()
	_log("Config saved to: %s" % _get_config_path())


func _save_config():
	_ensure_config_dir()
	# Build a clean copy without internal-only keys (like _info)
	var save_data := {
		"animation_player_path": config["animation_player_path"],
		"blank_threshold": config["blank_threshold"],
		"frame_size": config.get("frame_size", 64),
		"sprite_groups": []
	}
	for group in config["sprite_groups"]:
		var clean_group := {}
		clean_group["sprites"] = group.get("sprites", [])
		clean_group["hframes"] = group.get("hframes", 9)
		clean_group["vframes"] = group.get("vframes", 56)
		clean_group["frame_duration"] = group.get("frame_duration", 0.1)
		clean_group["z_behind_on_up"] = group.get("z_behind_on_up", false)
		# Save animations as ordered array
		var clean_anims: Array = []
		for entry in group.get("animations", []):
			clean_anims.append({
				"name": entry.get("name", ""),
				"row": entry.get("row", 0),
				"flip_h": entry.get("flip_h", false),
				"flip_v": entry.get("flip_v", false),
			})
		clean_group["animations"] = clean_anims
		save_data["sprite_groups"].append(clean_group)

	var json_str = JSON.stringify(save_data, "\t")
	var file = FileAccess.open(_get_config_path(), FileAccess.WRITE)
	if file:
		file.store_string(json_str)
		file.close()
	else:
		_log("ERROR: Could not write config to %s" % _get_config_path())


func _load_config():
	var path = _get_config_path()
	if not FileAccess.file_exists(path):
		return

	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		printerr("[FastSpriteAnim] Could not open config: ", path)
		return

	var json_str = file.get_as_text()
	file.close()

	var json = JSON.new()
	var err = json.parse(json_str)
	if err != OK:
		printerr("[FastSpriteAnim] JSON parse error: ", json.get_error_message())
		return

	var data = json.data
	if not (data is Dictionary):
		printerr("[FastSpriteAnim] Config root is not a Dictionary.")
		return

	config["animation_player_path"] = data.get("animation_player_path", config["animation_player_path"])
	config["blank_threshold"] = int(data.get("blank_threshold", config["blank_threshold"]))
	config["frame_size"] = int(data.get("frame_size", 64))

	# Rebuild sprite_groups to ensure proper typing
	var groups_raw = data.get("sprite_groups", [])
	var groups: Array = []
	for g in groups_raw:
		if not (g is Dictionary):
			continue
		var group := {}
		group["sprites"] = Array(g.get("sprites", []))
		group["hframes"] = int(g.get("hframes", 9))
		group["vframes"] = int(g.get("vframes", 56))
		group["frame_duration"] = float(g.get("frame_duration", 0.1))
		group["z_behind_on_up"] = bool(g.get("z_behind_on_up", false))
		# Parse animations — support both old dict format and new array format
		var raw_anims = g.get("animations", [])
		var anims: Array = []
		if raw_anims is Array:
			for entry in raw_anims:
				if entry is Dictionary:
					anims.append({
						"name": str(entry.get("name", "")),
						"row": int(entry.get("row", 0)),
						"flip_h": bool(entry.get("flip_h", false)),
						"flip_v": bool(entry.get("flip_v", false)),
					})
		elif raw_anims is Dictionary:
			# Backwards compat: old {"name": row} dict format
			for key in raw_anims.keys():
				anims.append({
					"name": str(key),
					"row": int(raw_anims[key]),
					"flip_h": false,
					"flip_v": false,
				})
		group["animations"] = anims
		groups.append(group)
	config["sprite_groups"] = groups

	# Update UI fields
	if anim_player_dropdown:
		_refresh_anim_player_list()
		_select_dropdown_by_metadata(anim_player_dropdown, config["animation_player_path"])
	if blank_threshold_spin:
		blank_threshold_spin.value = config["blank_threshold"]
	if frame_size_spin:
		frame_size_spin.value = config.get("frame_size", 64)


# ─────────────────────────────────────────────────────────────────────────────
# ANIMATION GENERATION
# ─────────────────────────────────────────────────────────────────────────────

func _on_generate():
	_log("Starting animation generation...")

	var scene_root = EditorInterface.get_edited_scene_root()
	if scene_root == null:
		_log("ERROR: No scene open. Open your player scene first.")
		return

	# Get AnimationPlayer
	var anim_player = scene_root.get_node_or_null(config["animation_player_path"])
	if anim_player == null:
		_log("ERROR: AnimationPlayer not found at: %s" % config["animation_player_path"])
		return

	if not (anim_player is AnimationPlayer):
		_log("ERROR: Node at '%s' is not an AnimationPlayer." % config["animation_player_path"])
		return

	# Get or create AnimationLibrary
	var library: AnimationLibrary
	if anim_player.has_animation_library(""):
		library = anim_player.get_animation_library("")
	else:
		library = AnimationLibrary.new()
		anim_player.add_animation_library("", library)

	var blank_threshold: int = config["blank_threshold"]
	var sprite_groups: Array = config["sprite_groups"]

	# ── STEP 1: Sync hframes/vframes on all Sprite2D nodes ────────────────
	_log("Syncing Sprite2D hframes/vframes from config...")
	for group in sprite_groups:
		var hframes: int = int(group.get("hframes", 9))
		var vframes: int = int(group.get("vframes", 56))
		for path in group.get("sprites", []):
			var sprite = scene_root.get_node_or_null(str(path))
			if sprite == null or not (sprite is Sprite2D):
				continue
			if sprite.hframes != hframes or sprite.vframes != vframes:
				_log("  Updating '%s': %dx%d -> %dx%d" % [
					path, sprite.hframes, sprite.vframes, hframes, vframes])
				sprite.hframes = hframes
				sprite.vframes = vframes

	# ── STEP 2: Collect all unique animation names (preserving order) ─────
	var all_anim_names: Array = []
	var seen_names := {}
	for group in sprite_groups:
		for entry in group.get("animations", []):
			var aname = entry.get("name", "")
			if aname != "" and not seen_names.has(aname):
				all_anim_names.append(aname)
				seen_names[aname] = true

	if all_anim_names.is_empty():
		_log("WARNING: No animations defined in any group. Nothing to generate.")
		return

	var generated_count := 0

	# ── STEP 3: Generate animations, merging tracks across groups ─────────
	for anim_name in all_anim_names:
		var anim = Animation.new()
		anim.loop_mode = Animation.LOOP_LINEAR
		var longest_length := 0.0
		var tracks_added := 0

		for group in sprite_groups:
			# Find this animation's entry in this group (if any)
			var anim_entry: Dictionary = {}
			for entry in group.get("animations", []):
				if entry.get("name", "") == anim_name:
					anim_entry = entry
					break
			if anim_entry.is_empty():
				continue

			var row: int = int(anim_entry.get("row", 0))
			var flip_h: bool = anim_entry.get("flip_h", false)
			var flip_v: bool = anim_entry.get("flip_v", false)
			var z_behind_on_up: bool = group.get("z_behind_on_up", false)
			var hframes: int = int(group.get("hframes", 9))
			var vframes: int = int(group.get("vframes", 56))
			var frame_duration: float = float(group.get("frame_duration", 0.1))
			var sprite_paths: Array = group.get("sprites", [])

			# Get sprite nodes
			var sprites := []
			var all_found := true
			for path in sprite_paths:
				var sprite = scene_root.get_node_or_null(str(path))
				if sprite == null:
					_log("  WARNING: Sprite not found at '%s' — skipping." % path)
					all_found = false
					break
				sprites.append(sprite)
			if not all_found:
				continue

			# Use first sprite to detect blank frames
			if sprites.is_empty():
				continue
			var texture = sprites[0].texture
			if texture == null:
				_log("  WARNING: No texture on '%s' — skipping group." % sprite_paths[0])
				continue

			var image = texture.get_image()
			if image == null:
				_log("  WARNING: Could not get image from '%s' — skipping." % sprite_paths[0])
				continue

			var frame_width: int = image.get_width() / hframes
			var frame_height: int = image.get_height() / vframes

			# Validate row is within bounds
			if row >= vframes:
				_log("  WARNING: Row %d out of range for '%s' (max %d) — skipping." % [row, anim_name, vframes - 1])
				continue

			# Find valid (non-blank) columns for this row
			var valid_cols := []
			for col in range(hframes):
				if not _is_frame_blank(image, col, row, frame_width, frame_height, blank_threshold):
					valid_cols.append(col)

			if valid_cols.is_empty():
				_log("  WARNING: No valid frames for '%s' in '%s' row %d" % [anim_name, sprite_paths[0], row])
				continue

			var group_length: float = valid_cols.size() * frame_duration
			if group_length > longest_length:
				longest_length = group_length

			# Add tracks per sprite in this group
			for sprite in sprites:
				var sprite_path = scene_root.get_path_to(sprite)

				# Frame track
				var track_idx = anim.add_track(Animation.TYPE_VALUE)
				anim.track_set_path(track_idx, str(sprite_path) + ":frame")
				anim.track_set_interpolation_type(track_idx, Animation.INTERPOLATION_NEAREST)

				for i in range(valid_cols.size()):
					var col = valid_cols[i]
					var frame_index = row * hframes + col
					var time = i * frame_duration
					anim.track_insert_key(track_idx, time, frame_index)

				# flip_h track — always set so switching anims resets flip
				var fh_idx = anim.add_track(Animation.TYPE_VALUE)
				anim.track_set_path(fh_idx, str(sprite_path) + ":flip_h")
				anim.track_set_interpolation_type(fh_idx, Animation.INTERPOLATION_NEAREST)
				anim.track_insert_key(fh_idx, 0.0, flip_h)

				# flip_v track
				var fv_idx = anim.add_track(Animation.TYPE_VALUE)
				anim.track_set_path(fv_idx, str(sprite_path) + ":flip_v")
				anim.track_set_interpolation_type(fv_idx, Animation.INTERPOLATION_NEAREST)
				anim.track_insert_key(fv_idx, 0.0, flip_v)

				# z_index track — draw behind other groups on up-facing animations
				if z_behind_on_up:
					var z_idx = anim.add_track(Animation.TYPE_VALUE)
					anim.track_set_path(z_idx, str(sprite_path) + ":z_index")
					anim.track_set_interpolation_type(z_idx, Animation.INTERPOLATION_NEAREST)
					var is_up = anim_name.ends_with("_up") or "_up_" in anim_name
					anim.track_insert_key(z_idx, 0.0, -1 if is_up else 0)

				tracks_added += 1

		if tracks_added == 0:
			_log("  SKIP: '%s' — no valid tracks found across any group." % anim_name)
			continue

		anim.length = longest_length if longest_length > 0.0 else 0.1

		# Add or replace in library
		if library.has_animation(anim_name):
			library.remove_animation(anim_name)
		library.add_animation(anim_name, anim)
		generated_count += 1
		var flip_note = ""
		if _anim_has_flip(sprite_groups, anim_name):
			flip_note = " [flipped]"
		_log("  OK: '%s' — %d tracks, %.2fs%s" % [anim_name, tracks_added, anim.length, flip_note])

	_log("")
	_log("Done! Generated %d animation(s)." % generated_count)

	# Mark the scene as modified so the user gets prompted to save
	if editor_plugin:
		EditorInterface.mark_scene_as_unsaved()


# ─────────────────────────────────────────────────────────────────────────────
# BLANK FRAME DETECTION
# ─────────────────────────────────────────────────────────────────────────────

func _is_frame_blank(image: Image, col: int, row: int, frame_width: int, frame_height: int, threshold: int) -> bool:
	var x_start = col * frame_width
	var y_start = row * frame_height
	var non_transparent := 0

	for x in range(x_start, x_start + frame_width):
		for y in range(y_start, y_start + frame_height):
			var pixel = image.get_pixel(x, y)
			if pixel.a > 0.1:
				non_transparent += 1
				if non_transparent >= threshold:
					return false
	return true


# ─────────────────────────────────────────────────────────────────────────────
# LOGGING
# ─────────────────────────────────────────────────────────────────────────────

func _log(msg: String):
	print("[FastSpriteAnim] ", msg)
