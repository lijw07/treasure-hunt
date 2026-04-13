extends CanvasLayer

var selected_index: int = 0
var _slots: Array[Panel] = []
var _icons: Array[TextureRect] = []
var _key_labels: Array[Label] = []
var _items: Array[Dictionary] = []

const SLOT_SIZE: int = 48
const ICON_PADDING: int = 6
const BOTTOM_MARGIN: int = 12


func _ready() -> void:
	add_to_group("toolbar")
	_load_assets()
	_build_ui()
	_update_selection()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key_index = event.keycode - KEY_1
		if key_index >= 0 and key_index < _items.size():
			selected_index = key_index
			_update_selection()
			get_viewport().set_input_as_handled()

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			selected_index = (selected_index - 1) if selected_index > 0 else _items.size() - 1
			_update_selection()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			selected_index = (selected_index + 1) % _items.size()
			_update_selection()
			get_viewport().set_input_as_handled()


func get_selected_item() -> Dictionary:
	return _items[selected_index]


func _load_assets() -> void:
	var tool_icons = load("res://Assets/Cute_Fantasy/Icons/Outline/Tool_Icons_Outline.png")

	_items = [
		{"name": "sword", "anim_prefix": "sword_combo", "hold": false, "icon": _atlas(tool_icons, Rect2(64, 0, 16, 16))},
		{"name": "bow", "anim_prefix": "bow", "hold": false, "icon": _atlas(tool_icons, Rect2(0, 0, 16, 16))},
		{"name": "axe", "anim_prefix": "tool_axe", "hold": false, "icon": _atlas(tool_icons, Rect2(48, 0, 16, 16))},
		{"name": "pickaxe", "anim_prefix": "tool_pickaxe", "hold": false, "icon": _atlas(tool_icons, Rect2(32, 0, 16, 16))},
		{"name": "fishing_rod", "anim_prefix": "fish_cast", "hold": false, "icon": _atlas(tool_icons, Rect2(112, 0, 16, 16))},
		{"name": "hoe", "anim_prefix": "tool_hoe", "hold": false, "icon": _atlas(tool_icons, Rect2(96, 0, 16, 16))},
		{"name": "watering_can", "anim_prefix": "tool_watercan", "hold": false, "icon": _atlas(tool_icons, Rect2(80, 0, 16, 16))},
	]


func _atlas(source: Texture2D, region: Rect2) -> AtlasTexture:
	var tex = AtlasTexture.new()
	tex.atlas = source
	tex.region = region
	return tex


func _build_ui() -> void:
	var root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Single toolbar background bar
	var total_width = SLOT_SIZE * _items.size()
	var bar = Panel.new()
	bar.custom_minimum_size = Vector2(total_width, SLOT_SIZE)
	bar.anchor_left = 0.5
	bar.anchor_right = 0.5
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	bar.offset_left = -total_width / 2.0
	bar.offset_right = total_width / 2.0
	bar.offset_top = -(SLOT_SIZE + BOTTOM_MARGIN)
	bar.offset_bottom = -BOTTOM_MARGIN
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Dark background style for the whole bar
	var bar_style = StyleBoxFlat.new()
	bar_style.bg_color = Color(0.12, 0.1, 0.15, 0.9)
	bar_style.border_color = Color(0.45, 0.35, 0.25, 1.0)
	bar_style.set_border_width_all(2)
	bar_style.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("panel", bar_style)
	root.add_child(bar)

	for i in range(_items.size()):
		# Each cell is a Panel inside the bar, positioned manually
		var slot = Panel.new()
		slot.position = Vector2(i * SLOT_SIZE, 0)
		slot.size = Vector2(SLOT_SIZE, SLOT_SIZE)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.add_child(slot)
		_slots.append(slot)

		var icon = TextureRect.new()
		icon.texture = _items[i].icon
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.position = Vector2(ICON_PADDING, ICON_PADDING)
		icon.size = Vector2(SLOT_SIZE - ICON_PADDING * 2, SLOT_SIZE - ICON_PADDING * 2)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(icon)
		_icons.append(icon)

		var label = Label.new()
		label.text = str(i + 1)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		label.position = Vector2(3, 1)
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
		label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
		label.add_theme_constant_override("shadow_offset_x", 1)
		label.add_theme_constant_override("shadow_offset_y", 1)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(label)
		_key_labels.append(label)


func _update_selection() -> void:
	for i in range(_slots.size()):
		var style = StyleBoxFlat.new()
		if i == selected_index:
			style.bg_color = Color(0.85, 0.65, 0.2, 0.4)
		else:
			style.bg_color = Color(0, 0, 0, 0)
		# Add divider lines between cells
		style.border_color = Color(0.45, 0.35, 0.25, 0.6)
		if i > 0:
			style.border_width_left = 1
		if i < _slots.size() - 1:
			style.border_width_right = 1
		_slots[i].add_theme_stylebox_override("panel", style)
