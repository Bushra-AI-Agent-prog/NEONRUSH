class_name TouchControls
extends Node2D
## On-screen multitouch controls. Each button is a TouchScreenButton bound to an
## input action, so several can be held at once (steer + gas + boost).
## With emulate_touch_from_mouse enabled they also work with a mouse on desktop.

class Btn extends TouchScreenButton:
	var label := ""
	var radius := 70.0
	var tint := Color(0.0, 0.9, 1.0)
	var down := false
	var font_size := 26

	func setup_btn(text: String, r: float, col: Color, act: String) -> void:
		label = text
		radius = r
		tint = col
		action = act
		var sh := CircleShape2D.new()
		sh.radius = r
		shape = sh
		shape_centered = true
		passby_press = true
		pressed.connect(func():
			down = true
			queue_redraw())
		released.connect(func():
			down = false
			queue_redraw())

	func _draw() -> void:
		var fill := Color(tint.r, tint.g, tint.b, 0.55 if down else 0.16)
		draw_circle(Vector2.ZERO, radius, fill)
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(tint.r, tint.g, tint.b, 0.9), 3.0, true)
		var font := ThemeDB.fallback_font
		var sz := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		draw_string(font, Vector2(-sz.x / 2.0, sz.y / 4.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1, 1, 1, 0.95))

var buttons := {}

func _ready() -> void:
	var cyan := Color(0.0, 0.9, 1.0)
	var mag := Color(1.0, 0.15, 0.65)
	var amber := Color(1.0, 0.75, 0.1)
	var green := Color(0.3, 1.0, 0.5)
	_add("steer_left", "<", 84.0, cyan, 48)
	_add("steer_right", ">", 84.0, cyan, 48)
	_add("accelerate", "GAS", 104.0, green, 34)
	_add("brake", "BRAKE", 78.0, mag, 24)
	_add("handbrake", "HB", 52.0, amber, 24)
	_add("boost", "ION", 62.0, Color(0.6, 0.4, 1.0), 26)
	_add("cam", "CAM", 38.0, cyan, 18)
	_add("reset", "RST", 38.0, amber, 18)
	_add("horn", "HORN", 38.0, cyan, 16)
	_add("pause", "II", 38.0, Color.WHITE, 24)
	get_viewport().size_changed.connect(layout)
	layout()

func _add(action: String, text: String, r: float, col: Color, fs: int) -> void:
	var b := Btn.new()
	b.setup_btn(text, r, col, action)
	b.font_size = fs
	add_child(b)
	buttons[action] = b

func layout() -> void:
	var size := get_viewport().get_visible_rect().size
	var W := size.x
	var H := size.y
	var left_hand := bool(Save.setting("left_handed"))
	var tilt := bool(Save.setting("tilt"))
	# Right-handed layout: steer on the left, pedals on the right.
	var pos := {
		"steer_left": Vector2(120, H - 120),
		"steer_right": Vector2(320, H - 120),
		"accelerate": Vector2(W - 130, H - 135),
		"brake": Vector2(W - 330, H - 105),
		"handbrake": Vector2(W - 95, H - 320),
		"boost": Vector2(W - 245, H - 290),
		"pause": Vector2(W - 60, 60),
		"cam": Vector2(W - 60, 150),
		"reset": Vector2(W - 60, 232),
		"horn": Vector2(W - 60, 314),
	}
	for k in pos.keys():
		var p: Vector2 = pos[k]
		if left_hand and k != "pause":
			p.x = W - p.x
		(buttons[k] as Btn).position = p
	if left_hand:
		# keep the right-edge utility buttons on the right so they don't hide behind pedals
		for k in ["cam", "reset", "horn"]:
			(buttons[k] as Btn).position.x = W - 60
	buttons["steer_left"].visible = not tilt
	buttons["steer_right"].visible = not tilt
	buttons["steer_left"].process_mode = Node.PROCESS_MODE_INHERIT if not tilt else Node.PROCESS_MODE_DISABLED
	buttons["steer_right"].process_mode = Node.PROCESS_MODE_INHERIT if not tilt else Node.PROCESS_MODE_DISABLED
