extends Node

## =========================================================================
##  InputManager  (Autoload singleton — access anywhere via InputManager)
##
##  Centralised input configuration for Treasure Hunt.
##  - Stores default & current key bindings
##  - Manages mouse sensitivity and invert mouse
##  - Manages volume levels
##  - Persists user settings to disk via ConfigFile
## =========================================================================

# ── Signals ──────────────────────────────────────────────────────────
signal bindings_changed            # emitted after any rebind
signal settings_changed            # emitted after mouse/volume changes
signal dirty_changed(is_dirty: bool)  # emitted when unsaved-changes flag flips

# ── Settings file path ───────────────────────────────────────────────
const SAVE_PATH := "user://settings.cfg"

# ── Mouse ────────────────────────────────────────────────────────────
var mouse_sensitivity : float = 1.0    # 0.1 – 3.0
var mouse_inverted    : bool  = false

# ── Volume (0–100, converted to dB when applied) ────────────────────
var volume_music : float = 50.0
var volume_sfx   : float = 50.0

# ── Dirty flag (unsaved changes) ────────────────────────────────────
var _dirty : bool = false

# ── Action definitions ───────────────────────────────────────────────
# Each entry:  action_name → { "label": display text,
#                               "default": InputEvent,
#                               "category": group name }
# Category order defines how they appear in the Settings UI.

var action_defs : Dictionary = {}      # built in _ready


# ═════════════════════════════════════════════════════════════════════
#  SETUP
# ═════════════════════════════════════════════════════════════════════
func _ready() -> void:
	_define_actions()
	_register_actions()
	load_settings()


## Define every game action and its default key / button.
func _define_actions() -> void:
	action_defs = {
		# ── Movement ────────────────────────────────────────────
		"move_up": {
			"label": "Move Up",
			"default": _key(KEY_W),
			"category": "Movement",
		},
		"move_down": {
			"label": "Move Down",
			"default": _key(KEY_S),
			"category": "Movement",
		},
		"move_left": {
			"label": "Move Left",
			"default": _key(KEY_A),
			"category": "Movement",
		},
		"move_right": {
			"label": "Move Right",
			"default": _key(KEY_D),
			"category": "Movement",
		},

		# ── Actions ─────────────────────────────────────────────
		"jump": {
			"label": "Jump",
			"default": _key(KEY_SPACE),
			"category": "Actions",
		},
		"dodge": {
			"label": "Dodge",
			"default": _key(KEY_CTRL),
			"category": "Actions",
		},
		"basic_attack": {
			"label": "Basic Attack",
			"default": _mouse(MOUSE_BUTTON_LEFT),
			"category": "Actions",
		},
		"heavy_attack": {
			"label": "Heavy Attack",
			"default": _mouse(MOUSE_BUTTON_RIGHT),
			"category": "Actions",
		},

		# ── Utility ─────────────────────────────────────────────
		"open_map": {
			"label": "Map",
			"default": _key(KEY_M),
			"category": "Utility",
		},
		"mount": {
			"label": "Mount",
			"default": _key(KEY_H),
			"category": "Utility",
		},
	}


## Register (or re-register) all actions in the Godot InputMap.
func _register_actions() -> void:
	for action_name in action_defs:
		if InputMap.has_action(action_name):
			InputMap.action_erase_events(action_name)
		else:
			InputMap.add_action(action_name)
		InputMap.action_add_event(action_name, action_defs[action_name]["default"])


# ═════════════════════════════════════════════════════════════════════
#  HELPERS — create InputEvent objects
# ═════════════════════════════════════════════════════════════════════
func _key(keycode: Key) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	return ev

func _mouse(button: MouseButton) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	ev.pressed = true
	return ev


# ═════════════════════════════════════════════════════════════════════
#  DIRTY FLAG — track unsaved changes
# ═════════════════════════════════════════════════════════════════════

func is_dirty() -> bool:
	return _dirty

func mark_dirty() -> void:
	if not _dirty:
		_dirty = true
		dirty_changed.emit(true)

func clear_dirty() -> void:
	if _dirty:
		_dirty = false
		dirty_changed.emit(false)


# ═════════════════════════════════════════════════════════════════════
#  QUERY — get info about an action
# ═════════════════════════════════════════════════════════════════════

## Human-readable label for an action (e.g. "Move Up").
func get_label(action_name: String) -> String:
	if action_defs.has(action_name):
		return action_defs[action_name]["label"]
	return action_name


## Short display string for the currently bound key (e.g. "W", "LMB").
func get_binding_text(action_name: String) -> String:
	var events := InputMap.action_get_events(action_name)
	if events.is_empty():
		return "—"
	return _event_to_text(events[0])


## Category for grouping in settings UI.
func get_category(action_name: String) -> String:
	if action_defs.has(action_name):
		return action_defs[action_name]["category"]
	return "Other"


## Return all action names grouped by category, in definition order.
func get_actions_by_category() -> Dictionary:
	var grouped : Dictionary = {}   # category → Array[action_name]
	for action_name in action_defs:
		var cat : String = action_defs[action_name]["category"]
		if not grouped.has(cat):
			grouped[cat] = []
		grouped[cat].append(action_name)
	return grouped


## Convert an InputEvent to a short human-readable string.
func _event_to_text(ev: InputEvent) -> String:
	if ev is InputEventKey:
		var k := ev as InputEventKey
		var keycode := k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode
		match keycode:
			KEY_SPACE: return "SPACE"
			KEY_CTRL:  return "CTRL"
			KEY_SHIFT: return "SHIFT"
			KEY_ALT:   return "ALT"
			KEY_TAB:   return "TAB"
			KEY_ESCAPE: return "ESC"
			KEY_ENTER: return "ENTER"
			_: return OS.get_keycode_string(keycode).to_upper()
	if ev is InputEventMouseButton:
		var m := ev as InputEventMouseButton
		match m.button_index:
			MOUSE_BUTTON_LEFT:   return "LMB"
			MOUSE_BUTTON_RIGHT:  return "RMB"
			MOUSE_BUTTON_MIDDLE: return "MMB"
			_: return "MOUSE %d" % m.button_index
	return "?"


# ═════════════════════════════════════════════════════════════════════
#  REBIND — change a key at runtime (for future rebind UI)
# ═════════════════════════════════════════════════════════════════════
func rebind_action(action_name: String, new_event: InputEvent) -> void:
	if not action_defs.has(action_name):
		return
	InputMap.action_erase_events(action_name)
	InputMap.action_add_event(action_name, new_event)
	mark_dirty()
	bindings_changed.emit()


func reset_to_defaults() -> void:
	_register_actions()
	mark_dirty()
	bindings_changed.emit()


# ═════════════════════════════════════════════════════════════════════
#  MOUSE HELPERS
# ═════════════════════════════════════════════════════════════════════

## Apply mouse sensitivity to a raw mouse delta.
func apply_mouse(raw_delta: Vector2) -> Vector2:
	var result := raw_delta * mouse_sensitivity
	if mouse_inverted:
		result.y = -result.y
	return result


# ═════════════════════════════════════════════════════════════════════
#  VOLUME HELPERS
# ═════════════════════════════════════════════════════════════════════

## Convert a 0–100 slider value to decibels (muted below 1).
func volume_to_db(percent: float) -> float:
	if percent <= 0.0:
		return -80.0
	return lerp(-30.0, 0.0, percent / 100.0)


# ═════════════════════════════════════════════════════════════════════
#  SAVE / LOAD
# ═════════════════════════════════════════════════════════════════════
func save_settings() -> void:
	var cfg := ConfigFile.new()

	# Volume
	cfg.set_value("audio", "music", volume_music)
	cfg.set_value("audio", "sfx",   volume_sfx)

	# Mouse
	cfg.set_value("mouse", "sensitivity", mouse_sensitivity)
	cfg.set_value("mouse", "inverted",    mouse_inverted)

	# Key bindings — store as keycode / mouse button index
	for action_name in action_defs:
		var events := InputMap.action_get_events(action_name)
		if events.size() > 0:
			var ev := events[0]
			if ev is InputEventKey:
				var k := ev as InputEventKey
				cfg.set_value("bindings", action_name, {
					"type": "key",
					"code": k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode,
				})
			elif ev is InputEventMouseButton:
				var m := ev as InputEventMouseButton
				cfg.set_value("bindings", action_name, {
					"type": "mouse",
					"button": m.button_index,
				})

	cfg.save(SAVE_PATH)
	clear_dirty()


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		# No saved settings yet — revert to defaults
		reset_to_defaults()
		clear_dirty()
		return

	# Volume
	volume_music = cfg.get_value("audio", "music", volume_music)
	volume_sfx   = cfg.get_value("audio", "sfx",   volume_sfx)

	# Mouse
	mouse_sensitivity = cfg.get_value("mouse", "sensitivity", mouse_sensitivity)
	mouse_inverted    = cfg.get_value("mouse", "inverted",    mouse_inverted)

	# Key bindings
	for action_name in action_defs:
		var data = cfg.get_value("bindings", action_name, null)
		if data == null:
			continue
		var ev : InputEvent = null
		if data["type"] == "key":
			ev = _key(data["code"] as Key)
		elif data["type"] == "mouse":
			ev = _mouse(data["button"] as MouseButton)
		if ev:
			InputMap.action_erase_events(action_name)
			InputMap.action_add_event(action_name, ev)

	clear_dirty()
	settings_changed.emit()
