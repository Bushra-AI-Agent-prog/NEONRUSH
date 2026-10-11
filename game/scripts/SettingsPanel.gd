class_name SettingsPanel
extends PanelContainer
## Reusable settings UI (main menu and pause menu). Changes apply and save immediately.

signal closed

var _reset_btn: Button
var _reset_armed := false

func _ready() -> void:
	theme = Game.ui_theme
	process_mode = Node.PROCESS_MODE_ALWAYS
	custom_minimum_size = Vector2(820, 0)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	add_child(vb)

	var title := Label.new()
	title.text = "SETTINGS"
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0))
	vb.add_child(title)

	_slider(vb, "Music", "music", 0.0, 1.0)
	_slider(vb, "Effects", "sfx", 0.0, 1.0)
	_slider(vb, "Steering sensitivity", "steer_sens", 0.5, 1.5)
	_option(vb, "Graphics quality", "quality", Game.QUALITY_NAMES)
	_option(vb, "Time of day", "tod", Game.TOD_NAMES)
	_option(vb, "Default camera", "camera", ["Chase", "Hood", "Far"])
	_check(vb, "Left-handed layout", "left_handed")
	_check(vb, "Tilt steering (experimental)", "tilt")
	_check(vb, "Show FPS", "show_fps")

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	vb.add_child(row)
	_reset_btn = Game.make_button("Reset progress", Vector2(300, 64))
	_reset_btn.pressed.connect(_on_reset)
	row.add_child(_reset_btn)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var close := Game.make_button("Close", Vector2(220, 64))
	close.pressed.connect(func():
		Audio.play("click")
		Save.save_game()
		closed.emit())
	row.add_child(close)

func _row(parent: Node, text: String) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 16)
	var l := Label.new()
	l.text = text
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(l)
	parent.add_child(r)
	return r

func _slider(parent: Node, text: String, key: String, lo: float, hi: float) -> void:
	var r := _row(parent, text)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 0.05
	s.value = float(Save.setting(key))
	s.custom_minimum_size = Vector2(380, 44)
	s.focus_mode = Control.FOCUS_NONE
	s.value_changed.connect(func(v: float):
		Save.set_setting(key, v)
		Audio.apply_volumes()
		Game.apply_quality(get_viewport()))
	r.add_child(s)

func _option(parent: Node, text: String, key: String, items: Array) -> void:
	var r := _row(parent, text)
	var o := OptionButton.new()
	for it in items:
		o.add_item(it)
	o.selected = clampi(int(Save.setting(key)), 0, items.size() - 1)
	o.custom_minimum_size = Vector2(380, 56)
	o.focus_mode = Control.FOCUS_NONE
	o.item_selected.connect(func(i: int):
		Save.set_setting(key, i)
		Game.apply_quality(get_viewport()))
	r.add_child(o)

func _check(parent: Node, text: String, key: String) -> void:
	var r := _row(parent, text)
	var c := CheckButton.new()
	c.button_pressed = bool(Save.setting(key))
	c.focus_mode = Control.FOCUS_NONE
	c.toggled.connect(func(on: bool):
		Save.set_setting(key, on)
		Game.apply_quality(get_viewport()))
	r.add_child(c)

func _on_reset() -> void:
	if not _reset_armed:
		_reset_armed = true
		_reset_btn.text = "Tap again to confirm"
		return
	Save.reset_all()
	Audio.apply_volumes()
	Game.apply_quality(get_viewport())
	_reset_armed = false
	_reset_btn.text = "Progress reset"
