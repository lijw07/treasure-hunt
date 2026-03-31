extends Node

## =========================================================================
##  InputManager  (Autoload singleton — access via InputManager)
##
##  Centralised input configuration for Treasure Hunt.
##    • Stores default and current key bindings
##    • Manages mouse sensitivity and inversion
##    • Manages music / SFX volume levels
##    • Persists user settings to disk via ConfigFile
## =========================================================================

# ── Signals ──────────────────────────────────────────────────────────
signal bindings_changed                 ## Emitted after any key rebind.
signal settings_changed                 ## Emitted after mouse / volume changes.
signal dirty_changed(is_dirty: bool)    ## Emitted when the unsaved-changes flag flips.

# ── Persistence ──────────────────────────────────────────────────────
const SAVE_PATH        := "user://settings.cfg"
const SETTINGS_VERSION := 3   # Bump when action_defs change to invalidate old saves.

# ── Mouse defaults ───────────────────────────────────────────────────
const MOUSE_SENS_DEFAULT   : float = 1.0
const MOUSE_INVERT_DEFAULT : bool  = false

# ── Volume defaults (0–100 slider range) ─────────────────────────────
const VOLUME_MUSIC_DEFAULT : float = 100.0
const VOLUME_SFX_DEFAULT   : float = 100.0

# ── Music dB curve ───────────────────────────────────────────────────
#   100 % → -15 dB  (matches the old 50 % level, which sounded right)
#     0 % → -45 dB  (effectively silent)
const MUSIC_DB_MIN : float = -45.0
const MUSIC_DB_MAX : float = -15.0

# ── SFX dB curve (quieter so effects never overpower music) ──────────
#   100 % → -20 dB
#     0 % → -50 dB
const SFX_DB_MIN : float = -50.0
const SFX_DB_MAX : float = -20.0

# ── Silent floor (both curves) ───────────────────────────────────────
const SILENT_DB : float = -80.0

# ── Runtime state ────────────────────────────────────────────────────
var mouse_sensitivity : float = MOUSE_SENS_DEFAULT
var mouse_inverted    : bool  = MOUSE_INVERT_DEFAULT
var volume_music      : float = VOLUME_MUSIC_DEFAULT
var volume_sfx        : float = VOLUME_SFX_DEFAULT

var action_defs : Dictionary = {}   # Built in _ready → _define_actions().
var _dirty      : bool       = false


# ═════════════════════════════════════════════════════════════════════
#  LIFECYCLE
# ═════════════════════════════════════════════════════════════════════

func _ready() -> void:
	_define_actions()
	_register_actions()
	load_settings()


# ═════════════════════════════════════════════════════════════════════
#  ACTION DEFINITIONS
# ═════════════════════════════════════════════════════════════════════

## Populate action_defs with every game action and its default binding.
## Category order here determines grouping in the Settings UI.
func _define_actions() -> void:
	action_defs = {
		# ── Movement ────────────────────────────────────────
		"move_up":    { "label": "Move Up",    "default": _key(KEY_W), "category": "Movement" },
		"move_down":  { "label": "Move Down",  "default": _key(KEY_S), "category": "Movement" },
		"move_left":  { "label": "Move Left",  "default": _key(KEY_A), "category": "Movement" },
		"move_right": { "label": "Move Right", "default": _key(KEY_D), "category": "Movement" },

		# ── Actions ─────────────────────────────────────────
		"jump":         { "label": "Jump",         "default": _key(KEY_SPACE),            "category": "Actions" },
		"dodge":        { "label": "Dodge",        "default": _key(KEY_CTRL),             "category": "Actions" },
		"basic_attack": { "label": "Basic Attack", "default": _mouse(MOUSE_BUTTON_LEFT),  "category": "Actions" },
		"heavy_attack": { "label": "Heavy Attack", "default": _mouse(MOUSE_BUTTON_RIGHT), "category": "Actions" },
		"interact":     { "label": "Interact",     "default": _key(KEY_F),                "category": "Actions" },

		# ── Utility ─────────────────────────────────────────
		"open_map": { "label": "Map",          "default": _key(KEY_M),      "category": "Utility" },
		"mount":    { "label": "Mount",        "default": _key(KEY_H),      "category": "Utility" },
		"pause":    { "label": "Pause / Menu", "default": _key(KEY_ESCAPE), "category": "Utility" },
	}


## Register (or re-register) every action in the Godot InputMap.
func _register_actions() -> void:
	for action_name in action_defs:
		if InputMap.has_action(action_name):
			InputMap.action_erase_events(action_name)
		else:
			InputMap.add_action(action_name)
		InputMap.action_add_event(action_name, action_defs[action_name]["default"])


# ═════════════════════════════════════════════════════════════════════
#  INPUT-EVENT FACTORIES
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
#  DIRTY FLAG  — tracks whether unsaved changes exist
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
#  QUERY  — read-only access to action metadata
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


## Category string for grouping in the settings UI.
func get_category(action_name: String) -> String:
	if action_defs.has(action_name):
		return action_defs[action_name]["category"]
	return "Other"


## Return all action names grouped by category, preserving definition order.
func get_actions_by_category() -> Dictionary:
	var grouped : Dictionary = {}   # category → Array[action_name]
	for action_name in action_defs:
		var cat : String = action_defs[action_name]["category"]
		if not grouped.has(cat):
			grouped[cat] = []
		grouped[cat].append(action_name)
	return grouped


# ═════════════════════════════════════════════════════════════════════
#  EVENT → TEXT  — human-readable binding names
# ═════════════════════════════════════════════════════════════════════

func _event_to_text(ev: InputEvent) -> String:
	if ev is InputEventKey:
		return _key_to_text(ev as InputEventKey)
	if ev is InputEventMouseButton:
		return _mouse_to_text(ev as InputEventMouseButton)
	return "?"


func _key_to_text(k: InputEventKey) -> String:
	var keycode := k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode
	match keycode:
		KEY_SPACE:  return "SPACE"
		KEY_CTRL:   return "CTRL"
		KEY_SHIFT:  return "SHIFT"
		KEY_ALT:    return "ALT"
		KEY_TAB:    return "TAB"
		KEY_ESCAPE: return "ESC"
		KEY_ENTER:  return "ENTER"
		_:          return OS.get_keycode_string(keycode).to_upper()


func _mouse_to_text(m: InputEventMouseButton) -> String:
	match m.button_index:
		MOUSE_BUTTON_LEFT:   return "LMB"
		MOUSE_BUTTON_RIGHT:  return "RMB"
		MOUSE_BUTTON_MIDDLE: return "MMB"
		_:                   return "MOUSE %d" % m.button_index


# ═════════════════════════════════════════════════════════════════════
#  REBIND  — change a key at runtime
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
	volume_music      = VOLUME_MUSIC_DEFAULT
	volume_sfx        = VOLUME_SFX_DEFAULT
	mouse_sensitivity = MOUSE_SENS_DEFAULT
	mouse_inverted    = MOUSE_INVERT_DEFAULT
	mark_dirty()
	bindings_changed.emit()
	settings_changed.emit()


# ═════════════════════════════════════════════════════════════════════
#  MOUSE HELPERS
# ═════════════════════════════════════════════════════════════════════

## Apply mouse sensitivity (and optional Y-invert) to a raw mouse delta.
func apply_mouse(raw_delta: Vector2) -> Vector2:
	var result := raw_delta * mouse_sensitivity
	if mouse_inverted:
		result.y = -result.y
	return result


# ═════════════════════════════════════════════════════════════════════
#  VOLUME HELPERS
# ═════════════════════════════════════════════════════════════════════

## Convert a 0–100 music slider value to decibels.
func volume_to_db(percent: float) -> float:
	if percent <= 0.0:
		return SILENT_DB
	return lerp(MUSIC_DB_MIN, MUSIC_DB_MAX, percent / 100.0)


## Convert a 0–100 SFX slider value to decibels (quieter curve).
func sfx_to_db(percent: float) -> float:
	if percent <= 0.0:
		return SILENT_DB
	return lerp(SFX_DB_MIN, SFX_DB_MAX, percent / 100.0)


# ═════════════════════════════════════════════════════════════════════
#  SAVE / LOAD  — persist to user://settings.cfg
# ═════════════════════════════════════════════════════════════════════

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("meta",  "version",     SETTINGS_VERSION)

	# Audio
	cfg.set_value("audio", "music",       volume_music)
	cfg.set_value("audio", "sfx",         volume_sfx)

	# Mouse
	cfg.set_value("mouse", "sensitivity", mouse_sensitivity)
	cfg.set_value("mouse", "inverted",    mouse_inverted)

	# Key bindings — store keycode / mouse-button index for portability.
	for action_name in action_defs:
		var events := InputMap.action_get_events(action_name)
		if events.is_empty():
			continue
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
		reset_to_defaults()
		clear_dirty()
		return

	# Discard outdated save files (e.g. actions were added / removed).
	var file_version : int = cfg.get_value("meta", "version", 0)
	if file_version < SETTINGS_VERSION:
		push_warning("Settings v%d < v%d — resetting to defaults." % [file_version, SETTINGS_VERSION])
		reset_to_defaults()
		save_settings()
		clear_dirty()
		return

	# Audio
	volume_music = cfg.get_value("audio", "music", VOLUME_MUSIC_DEFAULT)
	volume_sfx   = cfg.get_value("audio", "sfx",   VOLUME_SFX_DEFAULT)

	# Mouse
	mouse_sensitivity = cfg.get_value("mouse", "sensitivity", MOUSE_SENS_DEFAULT)
	mouse_inverted    = cfg.get_value("mouse", "inverted",    MOUSE_INVERT_DEFAULT)

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
