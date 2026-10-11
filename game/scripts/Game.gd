extends Node
## Shared data, input map, UI theme, quality presets, scene switching. Autoload "Game".

signal quality_changed

const COLORS: Array = [
	{"name": "Plasma White", "color": Color(0.92, 0.94, 0.98), "level": 1, "cost": 0},
	{"name": "Dhaka Yellow", "color": Color(1.0, 0.76, 0.08), "level": 1, "cost": 0},
	{"name": "Volt Cyan", "color": Color(0.04, 0.78, 0.95), "level": 2, "cost": 400},
	{"name": "Magenta Pulse", "color": Color(0.95, 0.13, 0.62), "level": 3, "cost": 600},
	{"name": "Jade Chrome", "color": Color(0.08, 0.72, 0.42), "level": 4, "cost": 800},
	{"name": "Crimson Ion", "color": Color(0.85, 0.08, 0.14), "level": 5, "cost": 1000},
	{"name": "Void Black", "color": Color(0.05, 0.05, 0.08), "level": 6, "cost": 1500},
	{"name": "Aurora Violet", "color": Color(0.5, 0.25, 0.95), "level": 8, "cost": 2500},
]

const NEONS: Array = [
	{"name": "Cyan", "color": Color(0.0, 0.9, 1.0), "level": 1, "cost": 0},
	{"name": "Magenta", "color": Color(1.0, 0.1, 0.65), "level": 1, "cost": 0},
	{"name": "Lime", "color": Color(0.5, 1.0, 0.1), "level": 2, "cost": 250},
	{"name": "Amber", "color": Color(1.0, 0.6, 0.0), "level": 3, "cost": 350},
	{"name": "Violet", "color": Color(0.6, 0.3, 1.0), "level": 4, "cost": 450},
	{"name": "Ice", "color": Color(0.85, 0.95, 1.0), "level": 6, "cost": 700},
]

const KITS: Array = [
	{"name": "Stock", "level": 1, "cost": 0},
	{"name": "Spoiler", "level": 3, "cost": 700},
	{"name": "Sport Wing", "level": 5, "cost": 1400},
	{"name": "Aero Pack", "level": 7, "cost": 2200},
]

const UPGRADES: Dictionary = {
	"engine": {"name": "Ion Motor", "desc": "More power and top speed", "base": 300},
	"tires": {"name": "Grip Tires", "desc": "Better traction and cornering", "base": 220},
	"brakes": {"name": "Mag Brakes", "desc": "Shorter stopping distance", "base": 200},
	"suspension": {"name": "Smart Suspension", "desc": "Stability and smoother ride", "base": 260},
	"battery": {"name": "Boost Cell", "desc": "Longer, cheaper ION boost", "base": 280},
}
const MAX_UPGRADE := 5

const TOD_NAMES := ["Day", "Golden hour", "Night"]
const QUALITY_NAMES := ["Low", "Medium", "High"]
## Per quality: render scale, msaa, glow, shadows, traffic count, rain amount, fps overlay hint.
const QUALITY: Array = [
	{"scale": 0.6, "msaa": 0, "glow": false, "shadows": false, "traffic": 8, "rain": 250, "far": 330.0},
	{"scale": 0.8, "msaa": 0, "glow": true, "shadows": false, "traffic": 16, "rain": 500, "far": 480.0},
	{"scale": 1.0, "msaa": 1, "glow": true, "shadows": true, "traffic": 26, "rain": 900, "far": 650.0},
]

var ui_theme: Theme
## Scene the Garage returns to (set by whoever opens it).
var garage_return := "res://scenes/MainMenu.tscn"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	ui_theme = _make_theme()
	get_tree().set_auto_accept_quit(false)

func upgrade_cost(key: String, current_level: int) -> int:
	return int(UPGRADES[key]["base"] * pow(1.75, current_level))

func quality() -> Dictionary:
	return QUALITY[clampi(int(Save.setting("quality")), 0, 2)]

func apply_quality(vp: Viewport) -> void:
	var q := quality()
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	vp.scaling_3d_scale = q["scale"]
	vp.msaa_3d = Viewport.MSAA_2X if q["msaa"] > 0 else Viewport.MSAA_DISABLED
	quality_changed.emit()

func go(path: String) -> void:
	get_tree().paused = false
	Save.save_game()
	get_tree().change_scene_to_file(path)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		Save.save_game()
		get_tree().quit()

# ---------------------------------------------------------------- input map

func _setup_input() -> void:
	_bind("accelerate", [KEY_W, KEY_UP])
	_bind("brake", [KEY_S, KEY_DOWN])
	_bind("steer_left", [KEY_A, KEY_LEFT])
	_bind("steer_right", [KEY_D, KEY_RIGHT])
	_bind("handbrake", [KEY_SPACE])
	_bind("boost", [KEY_SHIFT])
	_bind("cam", [KEY_C])
	_bind("reset", [KEY_R])
	_bind("pause", [KEY_ESCAPE, KEY_P])
	_bind("horn", [KEY_H])

func _bind(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)
	for k in keys:
		var e := InputEventKey.new()
		e.physical_keycode = k as Key
		InputMap.action_add_event(action, e)

# ---------------------------------------------------------------- UI theme

func _box(bg: Color, border: Color, radius := 14, bw := 2) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 22
	s.content_margin_right = 22
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	return s

func _make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 26
	var cyan := Color(0.0, 0.9, 1.0)
	t.set_color("font_color", "Label", Color(0.92, 0.97, 1.0))
	t.set_color("font_color", "Button", Color(0.92, 0.97, 1.0))
	t.set_color("font_hover_color", "Button", Color(1, 1, 1))
	t.set_color("font_pressed_color", "Button", Color(0.0, 0.0, 0.1))
	t.set_color("font_disabled_color", "Button", Color(0.5, 0.55, 0.6))
	t.set_stylebox("normal", "Button", _box(Color(0.05, 0.08, 0.16, 0.9), cyan.darkened(0.4)))
	t.set_stylebox("hover", "Button", _box(Color(0.08, 0.14, 0.26, 0.95), cyan))
	t.set_stylebox("pressed", "Button", _box(cyan, Color.WHITE))
	t.set_stylebox("disabled", "Button", _box(Color(0.06, 0.07, 0.1, 0.8), Color(0.25, 0.28, 0.32)))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_stylebox("panel", "PanelContainer", _box(Color(0.03, 0.05, 0.11, 0.88), cyan.darkened(0.3), 18))
	t.set_stylebox("panel", "Panel", _box(Color(0.03, 0.05, 0.11, 0.88), cyan.darkened(0.3), 18))
	var fill := _box(cyan, cyan, 6, 0)
	var bg := _box(Color(0.1, 0.12, 0.2), Color(0.1, 0.12, 0.2), 6, 0)
	t.set_stylebox("fill", "ProgressBar", fill)
	t.set_stylebox("background", "ProgressBar", bg)
	t.set_stylebox("slider", "HSlider", _slider_bg())
	t.set_stylebox("grabber_area", "HSlider", _slider_fill(cyan))
	t.set_stylebox("grabber_area_highlight", "HSlider", _slider_fill(cyan))
	return t

func _slider_bg() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.1, 0.13, 0.22)
	s.set_corner_radius_all(6)
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s

func _slider_fill(c: Color) -> StyleBoxFlat:
	var s := _slider_bg()
	s.bg_color = c
	return s

## Convenience: a styled Button.
func make_button(text: String, min_size := Vector2(260, 70)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE
	return b
