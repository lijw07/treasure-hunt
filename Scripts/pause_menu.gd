extends CanvasLayer

const P_BG            := Color("#181c14")
const P_FRAME_OUTER   := Color("#c89248")
const P_FRAME_INNER   := Color("#7c4428")
const P_FRAME_BORDER  := Color("#4c2810")
const P_FRAME_HILITE  := Color("#e8b468")

const P_BTN           := Color("#48883c")
const P_BTN_HOVER     := Color("#5ca84c")
const P_BTN_PRESS     := Color("#346828")
const P_BTN_BORDER    := Color("#284e1c")

const P_EXIT          := Color("#884040")
const P_EXIT_HOVER    := Color("#a85454")
const P_EXIT_PRESS    := Color("#6c2c2c")
const P_EXIT_BORDER   := Color("#4c1c1c")

const P_GOLD          := Color("#ffd860")
const P_GOLD_DIM      := Color("#c8a040")
const P_TEXT          := Color("#f8f0e0")
const P_TEXT_DIM      := Color("#a89880")
const P_OVERLAY       := Color(0.0, 0.0, 0.0, 0.7)
const P_KEY_BG        := Color("#3c5830")

const PANEL_W         := 260
const BTN_W           := 220
const BTN_H           := 30
const BTN_GAP         := 8
const BORDER          := 3
const CORNER          := 1

const POPUP_FADE_IN   := 0.15
const POPUP_SCALE_IN  := 0.15
const POPUP_FADE_OUT  := 0.12
const POPUP_SCALE_OUT := 0.12

var font_main        : Font
var input_mgr        : Node
var root_control     : Control
var overlay          : ColorRect
var main_panel       : PanelContainer
var settings_panel   : PanelContainer
var confirm_panel    : PanelContainer
var menu_buttons     : Array[Button] = []
var sfx_player       : AudioStreamPlayer
var sfx_hover        : AudioStream
var sfx_click        : AudioStream
var sfx_back         : AudioStream
var _active_popup    : PanelContainer = null
var _rebind_action   : String = ""
var _rebind_btn      : Button = null
var _rebind_buttons  : Dictionary = {}
var _slider_music    : HSlider = null
var _slider_sfx      : HSlider = null
var _slider_sens     : HSlider = null
var _invert_btn      : CheckButton = null
var _dirty_cb        : Callable
var _settings_scroll : ScrollContainer
var _is_open         : bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	input_mgr = get_node("/root/InputManager")
	font_main = load("res://Assets/Cute_Fantasy_UI/Fonts/VT323.ttf")
	_load_audio()
	_build_ui()
	root_control.visible = false


func _load_audio() -> void:
	sfx_hover = load("res://Assets/Audio/UI/hover.wav")
	sfx_click = load("res://Assets/Audio/UI/click.wav")
	sfx_back  = load("res://Assets/Audio/UI/back.wav")
	sfx_player = AudioStreamPlayer.new()
	sfx_player.bus = "Master"
	sfx_player.volume_db = input_mgr.sfx_to_db(input_mgr.volume_sfx)
	add_child(sfx_player)


func _play_sfx(stream: AudioStream) -> void:
	sfx_player.stream = stream
	sfx_player.play()


func _input(event: InputEvent) -> void:
	if _is_in_main_menu():
		return

	if _rebind_action != "":
		_handle_rebind_input(event)
		return

	if event.is_action_pressed("pause"):
		_handle_pause_input()


func _handle_rebind_input(event: InputEvent) -> void:
	if _rebind_action != "pause" and event is InputEventKey and event.is_pressed():
		var key := (event as InputEventKey).physical_keycode
		if key == KEY_NONE:
			key = (event as InputEventKey).keycode
		var is_cancel := (key == KEY_ESCAPE)
		if not is_cancel and InputMap.has_action("pause"):
			is_cancel = InputMap.event_is_action(event, "pause")
		if is_cancel:
			_cancel_rebind()
			_play_sfx(sfx_back)
			get_viewport().set_input_as_handled()
			return

	var accepted := false
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		input_mgr.rebind_action(_rebind_action, event)
		accepted = true
	elif event is InputEventMouseButton and event.is_pressed():
		var mb := (event as InputEventMouseButton).button_index
		if mb != MOUSE_BUTTON_WHEEL_UP and mb != MOUSE_BUTTON_WHEEL_DOWN \
				and mb != MOUSE_BUTTON_WHEEL_LEFT and mb != MOUSE_BUTTON_WHEEL_RIGHT:
			input_mgr.rebind_action(_rebind_action, event)
			accepted = true

	if accepted:
		if is_instance_valid(_rebind_btn):
			_rebind_btn.text = input_mgr.get_binding_text(_rebind_action)
			_rebind_btn.add_theme_color_override("font_color", P_GOLD)
		_play_sfx(sfx_click)
		_rebind_action = ""
		_rebind_btn = null
	get_viewport().set_input_as_handled()


func _handle_pause_input() -> void:
	if confirm_panel and is_instance_valid(confirm_panel) and confirm_panel.visible:
		_play_sfx(sfx_back)
		_close_confirm()
		get_viewport().set_input_as_handled()
		return
	if _active_popup == settings_panel:
		_play_sfx(sfx_back)
		_try_close_settings()
		get_viewport().set_input_as_handled()
		return
	if _is_open:
		_resume()
	else:
		_pause()
	get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not _is_open:
		return
	var mapping := {
		"move_up": "ui_up",
		"move_down": "ui_down",
		"move_left": "ui_left",
		"move_right": "ui_right",
	}
	for game_action in mapping:
		if event.is_action_pressed(game_action):
			var ui_ev := InputEventAction.new()
			ui_ev.action = mapping[game_action]
			ui_ev.pressed = true
			Input.parse_input_event(ui_ev)
			get_viewport().set_input_as_handled()
			return


func _is_in_main_menu() -> bool:
	var current := get_tree().current_scene
	if current == null:
		return true
	var path := current.scene_file_path
	return path.find("main_menu") >= 0 or path.find("start_menu") >= 0


func _build_ui() -> void:
	root_control = Control.new()
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_control)

	overlay = ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = P_OVERLAY
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	root_control.add_child(overlay)

	_build_main_panel()
	_build_settings_panel()
	main_panel.visible = false
	settings_panel.visible = false


func _build_main_panel() -> void:
	main_panel = _popup_shell("Paused")
	var box : VBoxContainer = main_panel.get_meta("content")
	menu_buttons.clear()

	var b_resume := _make_button("Resume", false)
	b_resume.pressed.connect(_resume)
	box.add_child(b_resume)
	menu_buttons.append(b_resume)

	var b_settings := _make_button("Settings", false)
	b_settings.pressed.connect(_on_settings)
	box.add_child(b_settings)
	menu_buttons.append(b_settings)

	box.add_child(_spacer(4))

	var b_quit := _make_button("Quit to Menu", true)
	b_quit.pressed.connect(_on_quit)
	box.add_child(b_quit)
	menu_buttons.append(b_quit)

	main_panel.set_meta("close_btn", b_resume)
	_wire_focus(menu_buttons)


func _build_settings_panel() -> void:
	settings_panel = _popup_shell("Settings")
	var box : VBoxContainer = settings_panel.get_meta("content")

	var clip_wrapper := Control.new()
	clip_wrapper.custom_minimum_size = Vector2(280, 360)
	clip_wrapper.clip_contents = true
	clip_wrapper.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	clip_wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(clip_wrapper)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.follow_focus = false
	clip_wrapper.add_child(scroll)
	_settings_scroll = scroll

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 4)
	scroll.add_child(content)

	_build_volume_section(content)
	_build_mouse_section(content)
	_build_controls_section(content)
	_build_pinned_buttons(box)


func _build_volume_section(content: VBoxContainer) -> void:
	content.add_child(_section_header("Volume"))
	content.add_child(_divider())
	content.add_child(_spacer(4))

	var music_row := _make_slider_row("Music", 0, 100, 5, input_mgr.volume_music, func(val: float):
		input_mgr.volume_music = val
		input_mgr.mark_dirty()
		input_mgr.settings_changed.emit()
		_play_sfx(sfx_hover))
	content.add_child(music_row)
	_slider_music = _find_slider_in_row(music_row)

	var sfx_row := _make_slider_row("SFX", 0, 100, 5, input_mgr.volume_sfx, func(val: float):
		input_mgr.volume_sfx = val
		input_mgr.mark_dirty()
		sfx_player.volume_db = input_mgr.sfx_to_db(val)
		_play_sfx(sfx_hover))
	content.add_child(sfx_row)
	_slider_sfx = _find_slider_in_row(sfx_row)
	content.add_child(_spacer(6))


func _build_mouse_section(content: VBoxContainer) -> void:
	content.add_child(_section_header("Mouse"))
	content.add_child(_divider())
	content.add_child(_spacer(4))

	var sens_row := _make_slider_row("Sensitivity", 10, 300, 10,
		int(input_mgr.mouse_sensitivity * 100), func(val: float):
			input_mgr.mouse_sensitivity = val / 100.0
			input_mgr.mark_dirty()
			_play_sfx(sfx_hover))
	content.add_child(sens_row)
	_slider_sens = _find_slider_in_row(sens_row)

	var invert_row := HBoxContainer.new()
	invert_row.add_theme_constant_override("separation", 8)
	content.add_child(invert_row)

	var inv_lbl := Label.new()
	inv_lbl.text = "Invert Y"
	inv_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inv_lbl.add_theme_font_override("font", font_main)
	inv_lbl.add_theme_font_size_override("font_size", 16)
	inv_lbl.add_theme_color_override("font_color", P_TEXT)
	invert_row.add_child(inv_lbl)

	var inv_btn := CheckButton.new()
	inv_btn.button_pressed = input_mgr.mouse_inverted
	inv_btn.focus_mode = Control.FOCUS_ALL
	inv_btn.add_theme_color_override("font_color", P_TEXT)
	inv_btn.toggled.connect(func(on: bool):
		input_mgr.mouse_inverted = on
		input_mgr.mark_dirty()
		_play_sfx(sfx_click))
	invert_row.add_child(inv_btn)
	_invert_btn = inv_btn
	content.add_child(_spacer(6))


func _build_controls_section(content: VBoxContainer) -> void:
	_rebind_buttons.clear()
	var categories : Dictionary = input_mgr.get_actions_by_category()
	for cat_name in categories:
		content.add_child(_section_header(cat_name))
		content.add_child(_divider())
		content.add_child(_spacer(2))

		for action_name in categories[cat_name]:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			row.clip_contents = true
			content.add_child(row)

			var lbl := Label.new()
			lbl.text = input_mgr.get_label(action_name)
			lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			lbl.clip_text = true
			lbl.add_theme_font_override("font", font_main)
			lbl.add_theme_font_size_override("font_size", 16)
			lbl.add_theme_color_override("font_color", P_TEXT)
			row.add_child(lbl)

			var bind_btn := _make_rebind_button(action_name)
			row.add_child(bind_btn)
			_rebind_buttons[action_name] = bind_btn

		content.add_child(_spacer(4))


func _build_pinned_buttons(box: VBoxContainer) -> void:
	box.add_child(_spacer(6))

	var reset_btn := _make_button("Reset Defaults", true)
	reset_btn.custom_minimum_size = Vector2(160, 26)
	reset_btn.pressed.connect(func():
		_play_sfx(sfx_click)
		_cancel_rebind()
		input_mgr.reset_to_defaults()
		_sync_settings_ui()
		sfx_player.volume_db = input_mgr.sfx_to_db(input_mgr.volume_sfx)
		reset_btn.grab_focus())
	var rc := CenterContainer.new()
	rc.add_child(reset_btn)
	box.add_child(rc)

	box.add_child(_spacer(6))

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 12)

	var save_btn := _make_button("Save", false)
	save_btn.custom_minimum_size = Vector2(100, 26)
	save_btn.pressed.connect(func():
		_cancel_rebind()
		input_mgr.save_settings()
		_play_sfx(sfx_click)
		_close_settings_to_main())

	if _dirty_cb.is_valid() and input_mgr.dirty_changed.is_connected(_dirty_cb):
		input_mgr.dirty_changed.disconnect(_dirty_cb)

	_dirty_cb = func(dirty: bool):
		if not is_instance_valid(save_btn):
			return
		save_btn.disabled = not dirty
		save_btn.focus_mode = Control.FOCUS_ALL if dirty else Control.FOCUS_NONE
		save_btn.mouse_filter = Control.MOUSE_FILTER_STOP if dirty else Control.MOUSE_FILTER_IGNORE
	input_mgr.dirty_changed.connect(_dirty_cb)

	save_btn.disabled = true
	save_btn.focus_mode = Control.FOCUS_NONE
	save_btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn_row.add_child(save_btn)

	var back_btn := _make_button("Back", false)
	back_btn.custom_minimum_size = Vector2(100, 26)
	back_btn.pressed.connect(func():
		_play_sfx(sfx_back)
		_try_close_settings())
	btn_row.add_child(back_btn)

	var cc := CenterContainer.new()
	cc.add_child(btn_row)
	box.add_child(cc)
	settings_panel.set_meta("close_btn", back_btn)

	input_mgr.clear_dirty()
	save_btn.disabled = true
	save_btn.focus_mode = Control.FOCUS_NONE
	save_btn.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _sync_settings_ui() -> void:
	if is_instance_valid(_slider_music):
		_slider_music.set_value_no_signal(input_mgr.volume_music)
		_update_slider_pct(_slider_music)
	if is_instance_valid(_slider_sfx):
		_slider_sfx.set_value_no_signal(input_mgr.volume_sfx)
		_update_slider_pct(_slider_sfx)
	if is_instance_valid(_slider_sens):
		_slider_sens.set_value_no_signal(int(input_mgr.mouse_sensitivity * 100))
		_update_slider_pct(_slider_sens)
	if is_instance_valid(_invert_btn):
		_invert_btn.set_pressed_no_signal(input_mgr.mouse_inverted)
	for action_name in _rebind_buttons:
		var btn : Button = _rebind_buttons[action_name]
		if is_instance_valid(btn):
			btn.text = input_mgr.get_binding_text(action_name)


func _pause() -> void:
	_is_open = true
	get_tree().paused = true
	root_control.visible = true
	main_panel.visible = true
	settings_panel.visible = false
	_active_popup = null

	overlay.modulate.a = 0.0
	main_panel.scale = Vector2(0.92, 0.92)
	main_panel.pivot_offset = main_panel.size * 0.5

	var tw := create_tween().set_parallel(true)
	tw.tween_property(overlay, "modulate:a", 1.0, POPUP_FADE_IN)
	tw.tween_property(main_panel, "scale", Vector2.ONE, POPUP_SCALE_IN) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	if menu_buttons.size() > 0:
		menu_buttons[0].call_deferred("grab_focus")


func _resume() -> void:
	_cancel_rebind()
	_is_open = false
	_active_popup = null

	var tw := create_tween().set_parallel(true)
	tw.tween_property(overlay, "modulate:a", 0.0, POPUP_FADE_OUT)
	tw.tween_property(main_panel, "scale", Vector2(0.95, 0.95), POPUP_SCALE_OUT) \
		.set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(func():
		root_control.visible = false
		main_panel.visible = false
		get_tree().paused = false)


func _on_settings() -> void:
	_play_sfx(sfx_click)
	_sync_settings_ui()
	input_mgr.clear_dirty()
	main_panel.visible = false
	settings_panel.visible = true
	_active_popup = settings_panel

	settings_panel.scale = Vector2(0.92, 0.92)
	settings_panel.pivot_offset = settings_panel.size * 0.5
	var tw := create_tween()
	tw.tween_property(settings_panel, "scale", Vector2.ONE, POPUP_SCALE_IN) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	var close_btn = settings_panel.get_meta("close_btn", null)
	if close_btn:
		(close_btn as Button).call_deferred("grab_focus")


func _close_settings_to_main() -> void:
	_cancel_rebind()
	_active_popup = null
	settings_panel.visible = false
	main_panel.visible = true

	main_panel.scale = Vector2(0.92, 0.92)
	main_panel.pivot_offset = main_panel.size * 0.5
	var tw := create_tween()
	tw.tween_property(main_panel, "scale", Vector2.ONE, POPUP_SCALE_IN) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	if menu_buttons.size() > 0:
		menu_buttons[0].call_deferred("grab_focus")


func _try_close_settings() -> void:
	_cancel_rebind()
	if input_mgr.is_dirty():
		_show_confirm()
	else:
		_close_settings_to_main()


func _on_quit() -> void:
	_play_sfx(sfx_click)
	_is_open = false
	_active_popup = null
	root_control.visible = false
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Scenes/main_menu_scene.tscn")


func _show_confirm() -> void:
	if confirm_panel and is_instance_valid(confirm_panel):
		confirm_panel.get_parent().queue_free()

	var wrapper := CenterContainer.new()
	wrapper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wrapper.mouse_filter = Control.MOUSE_FILTER_STOP
	root_control.add_child(wrapper)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(240, 0)
	var ps := StyleBoxFlat.new()
	ps.bg_color = P_FRAME_INNER
	ps.border_color = P_FRAME_BORDER
	ps.set_border_width_all(BORDER)
	ps.set_corner_radius_all(CORNER + 1)
	ps.content_margin_left = 18;  ps.content_margin_right = 18
	ps.content_margin_top = 14;   ps.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", ps)
	wrapper.add_child(panel)

	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 10)
	panel.add_child(vb)

	var msg := Label.new()
	msg.text = "You have unsaved changes."
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD
	msg.add_theme_font_override("font", font_main)
	msg.add_theme_font_size_override("font_size", 16)
	msg.add_theme_color_override("font_color", P_TEXT)
	vb.add_child(msg)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 10)
	vb.add_child(btn_row)

	var save_btn := _make_button("Save", false)
	save_btn.custom_minimum_size = Vector2(90, 26)
	save_btn.pressed.connect(func():
		_play_sfx(sfx_click)
		input_mgr.save_settings()
		_close_confirm()
		_close_settings_to_main())
	btn_row.add_child(save_btn)

	var discard_btn := _make_button("Discard", true)
	discard_btn.custom_minimum_size = Vector2(90, 26)
	discard_btn.pressed.connect(func():
		_play_sfx(sfx_back)
		input_mgr.load_settings()
		sfx_player.volume_db = input_mgr.sfx_to_db(input_mgr.volume_sfx)
		_sync_settings_ui()
		_close_confirm()
		_close_settings_to_main())
	btn_row.add_child(discard_btn)

	confirm_panel = panel

	panel.modulate.a = 0.0
	panel.scale = Vector2(0.92, 0.92)
	panel.pivot_offset = panel.size * 0.5
	var tw := create_tween().set_parallel(true)
	tw.tween_property(panel, "modulate:a", 1.0, POPUP_FADE_IN)
	tw.tween_property(panel, "scale", Vector2.ONE, POPUP_SCALE_IN) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	save_btn.call_deferred("grab_focus")


func _close_confirm() -> void:
	if confirm_panel and is_instance_valid(confirm_panel):
		var wrapper_node := confirm_panel.get_parent()
		if wrapper_node:
			wrapper_node.queue_free()
	confirm_panel = null


func _make_rebind_button(action_name: String) -> Button:
	var btn := Button.new()
	btn.text = input_mgr.get_binding_text(action_name)
	btn.custom_minimum_size = Vector2(120, 22)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	btn.clip_text = true
	btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	btn.expand_icon = true
	btn.focus_mode = Control.FOCUS_ALL
	btn.add_theme_font_override("font", font_main)
	btn.add_theme_font_size_override("font_size", 14)
	btn.add_theme_color_override("font_color", P_GOLD)
	btn.add_theme_color_override("font_hover_color", P_GOLD)
	btn.add_theme_color_override("font_pressed_color", P_TEXT)
	btn.add_theme_color_override("font_focus_color", P_GOLD)

	var sn := StyleBoxFlat.new()
	sn.bg_color = P_KEY_BG
	sn.border_color = P_BTN_BORDER
	sn.set_border_width_all(2)
	sn.set_corner_radius_all(CORNER)
	sn.content_margin_left = 6
	sn.content_margin_right = 6
	sn.content_margin_top = 2
	sn.content_margin_bottom = 2
	btn.add_theme_stylebox_override("normal", sn)

	var sh := sn.duplicate()
	sh.border_color = P_FRAME_HILITE
	btn.add_theme_stylebox_override("hover", sh)

	var sf := sn.duplicate()
	sf.border_color = P_GOLD
	btn.add_theme_stylebox_override("focus", sf)

	var sp := sn.duplicate()
	sp.bg_color = P_FRAME_BORDER
	sp.border_color = P_GOLD
	btn.add_theme_stylebox_override("pressed", sp)

	btn.pressed.connect(func():
		_start_rebind(action_name, btn))
	return btn


func _start_rebind(action_name: String, btn: Button) -> void:
	_cancel_rebind()
	_rebind_action = action_name
	_rebind_btn = btn
	var cancel_key = str(input_mgr.get_binding_text("pause"))
	if action_name == "pause":
		btn.text = "Press a key..."
	else:
		btn.text = "... %s to cancel" % cancel_key
	btn.add_theme_color_override("font_color", P_GOLD)
	_play_sfx(sfx_click)


func _cancel_rebind() -> void:
	if _rebind_btn and is_instance_valid(_rebind_btn) and _rebind_action != "":
		_rebind_btn.text = input_mgr.get_binding_text(_rebind_action)
		_rebind_btn.add_theme_color_override("font_color", P_GOLD)
	_rebind_action = ""
	_rebind_btn = null


func _popup_shell(title_text: String) -> PanelContainer:
	var wrapper := CenterContainer.new()
	wrapper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_control.add_child(wrapper)

	var outer := PanelContainer.new()
	outer.custom_minimum_size = Vector2(300, 0)
	var os := StyleBoxFlat.new()
	os.bg_color = P_FRAME_OUTER
	os.border_color = P_FRAME_BORDER
	os.set_border_width_all(BORDER)
	os.set_corner_radius_all(CORNER + 1)
	os.content_margin_left = 4
	os.content_margin_right = 4
	os.content_margin_top = 4
	os.content_margin_bottom = 4
	outer.add_theme_stylebox_override("panel", os)
	wrapper.add_child(outer)

	var inner := PanelContainer.new()
	inner.clip_contents = true
	var ins := StyleBoxFlat.new()
	ins.bg_color = P_FRAME_INNER
	ins.border_color = Color(P_FRAME_BORDER, 0.5)
	ins.set_border_width_all(2)
	ins.set_corner_radius_all(CORNER)
	ins.content_margin_left = 16
	ins.content_margin_right = 16
	ins.content_margin_top = 12
	ins.content_margin_bottom = 12
	inner.add_theme_stylebox_override("panel", ins)
	outer.add_child(inner)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	vbox.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	inner.add_child(vbox)

	var t := Label.new()
	t.text = title_text
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_override("font", font_main)
	t.add_theme_font_size_override("font_size", 24)
	t.add_theme_color_override("font_color", P_GOLD)
	t.add_theme_constant_override("outline_size", 2)
	t.add_theme_color_override("font_outline_color", P_FRAME_BORDER)
	vbox.add_child(t)
	vbox.add_child(_spacer(4))

	outer.set_meta("content", vbox)
	return outer


func _make_button(label_text: String, is_exit: bool) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.custom_minimum_size = Vector2(BTN_W, BTN_H)
	btn.focus_mode = Control.FOCUS_ALL
	btn.add_theme_font_override("font", font_main)
	btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_color_override("font_color", P_TEXT)
	btn.add_theme_color_override("font_hover_color", P_TEXT)
	btn.add_theme_color_override("font_pressed_color", P_TEXT)
	btn.add_theme_color_override("font_focus_color", P_TEXT)

	var base := P_EXIT if is_exit else P_BTN
	var hover := P_EXIT_HOVER if is_exit else P_BTN_HOVER
	var press := P_EXIT_PRESS if is_exit else P_BTN_PRESS
	var border := P_EXIT_BORDER if is_exit else P_BTN_BORDER
	var hilite := Color("#c86060") if is_exit else P_FRAME_HILITE

	var sn := StyleBoxFlat.new()
	sn.bg_color = base
	sn.border_color = border
	sn.set_border_width_all(2)
	sn.border_width_bottom = 4
	sn.set_corner_radius_all(CORNER)
	sn.content_margin_left = 8
	sn.content_margin_right = 8
	sn.content_margin_top = 4
	sn.content_margin_bottom = 6
	btn.add_theme_stylebox_override("normal", sn)

	var sh := sn.duplicate()
	sh.bg_color = hover
	sh.border_color = hilite
	btn.add_theme_stylebox_override("hover", sh)

	var sp := sn.duplicate()
	sp.bg_color = press
	sp.border_width_bottom = 2
	sp.content_margin_top = 6
	sp.content_margin_bottom = 4
	btn.add_theme_stylebox_override("pressed", sp)

	var sf := sh.duplicate()
	sf.border_color = P_GOLD
	btn.add_theme_stylebox_override("focus", sf)

	var sd := sn.duplicate()
	sd.bg_color = Color(base, 0.4)
	sd.border_color = Color(border, 0.3)
	btn.add_theme_stylebox_override("disabled", sd)
	btn.add_theme_color_override("font_disabled_color", Color(P_TEXT, 0.35))

	btn.mouse_entered.connect(func():
		if not is_instance_valid(btn):
			return
		btn.grab_focus()
		btn.pivot_offset = btn.size * 0.5
		create_tween().tween_property(btn, "scale", Vector2(1.04, 1.04), 0.08))
	btn.mouse_exited.connect(func():
		if not is_instance_valid(btn):
			return
		btn.pivot_offset = btn.size * 0.5
		create_tween().tween_property(btn, "scale", Vector2.ONE, 0.08))
	return btn


func _make_slider_row(label_text: String, min_val: float, max_val: float,
		step_val: float, initial: float, on_change: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size.x = 80
	lbl.add_theme_font_override("font", font_main)
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", P_TEXT)
	row.add_child(lbl)

	var slider := HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.step = step_val
	slider.value = initial
	slider.custom_minimum_size = Vector2(110, 16)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.focus_mode = Control.FOCUS_ALL

	var track := StyleBoxFlat.new()
	track.bg_color = P_FRAME_BORDER
	track.set_corner_radius_all(1)
	track.content_margin_top = 6
	track.content_margin_bottom = 6
	slider.add_theme_stylebox_override("slider", track)

	var fill := StyleBoxFlat.new()
	fill.bg_color = P_BTN
	fill.set_corner_radius_all(1)
	fill.content_margin_top = 6
	fill.content_margin_bottom = 6
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill)

	slider.add_theme_icon_override("grabber", _make_grabber_texture(P_BTN, P_BTN_BORDER))
	slider.add_theme_icon_override("grabber_highlight", _make_grabber_texture(P_BTN_HOVER, P_FRAME_HILITE))
	row.add_child(slider)

	var pct := Label.new()
	pct.text = "%d%%" % int(initial)
	pct.custom_minimum_size.x = 42
	pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pct.add_theme_font_override("font", font_main)
	pct.add_theme_font_size_override("font_size", 14)
	pct.add_theme_color_override("font_color", P_TEXT_DIM)
	row.add_child(pct)

	slider.value_changed.connect(func(val: float):
		if is_instance_valid(pct):
			pct.text = "%d%%" % int(val)
		on_change.call(val))
	return row


func _find_slider_in_row(row: HBoxContainer) -> HSlider:
	for child in row.get_children():
		if child is HSlider:
			return child
	return null


func _update_slider_pct(slider: HSlider) -> void:
	var row := slider.get_parent()
	if row == null:
		return
	var idx := slider.get_index()
	if idx + 1 < row.get_child_count():
		var pct := row.get_child(idx + 1)
		if pct is Label:
			pct.text = "%d%%" % int(slider.value)


func _make_grabber_texture(fill_col: Color, border_col: Color) -> ImageTexture:
	var tex_size := 10
	var img := Image.create(tex_size, tex_size, false, Image.FORMAT_RGBA8)
	img.fill(border_col)
	for y in range(2, tex_size - 2):
		for x in range(2, tex_size - 2):
			img.set_pixel(x, y, fill_col)
	return ImageTexture.create_from_image(img)


func _wire_focus(buttons: Array[Button]) -> void:
	for i in buttons.size():
		var btn := buttons[i]
		var prev := buttons[(i - 1) % buttons.size()]
		var nxt := buttons[(i + 1) % buttons.size()]
		btn.focus_neighbor_top = prev.get_path()
		btn.focus_neighbor_bottom = nxt.get_path()
		btn.focus_neighbor_left = btn.get_path()
		btn.focus_neighbor_right = btn.get_path()
		btn.focus_previous = prev.get_path()
		btn.focus_next = nxt.get_path()
		btn.focus_entered.connect(_on_btn_focus)


func _on_btn_focus() -> void:
	_play_sfx(sfx_hover)


func _section_header(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_override("font", font_main)
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", P_GOLD)
	return lbl


func _divider() -> ColorRect:
	var div := ColorRect.new()
	div.custom_minimum_size = Vector2(0, 1)
	div.color = P_FRAME_OUTER
	div.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return div


func _spacer(h: float) -> Control:
	var s := Control.new()
	s.custom_minimum_size.y = h
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return s
