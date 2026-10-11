extends Control
## Title screen: showroom bus, Play / Garage / Settings / Quit, career stats.

var _menu: Control
var _settings: SettingsPanel
var _about: Control

func _ready() -> void:
	theme = Game.ui_theme
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Game.apply_quality(get_viewport())
	Audio.engine_on(false)
	Audio.rain_on(false)
	Audio.apply_volumes()

	var preview := BusPreview.new()
	preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(preview)

	# Title
	var title := VBoxContainer.new()
	title.position = Vector2(60, 36)
	add_child(title)
	var t := Label.new()
	t.text = "NEON BUS"
	t.add_theme_font_size_override("font_size", 96)
	t.add_theme_color_override("font_color", Color(0.0, 0.95, 1.0))
	t.add_theme_constant_override("outline_size", 14)
	t.add_theme_color_override("font_outline_color", Color(1.0, 0.1, 0.65, 0.85))
	title.add_child(t)
	var sub := Label.new()
	sub.text = "Futuristic microbus taxi  -  Dhaka 2090"
	sub.add_theme_font_size_override("font_size", 28)
	sub.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	title.add_child(sub)

	# Career stats
	var stats := PanelContainer.new()
	stats.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	stats.offset_left = 40
	stats.offset_bottom = -34
	stats.offset_top = -190
	stats.offset_right = 420
	add_child(stats)
	var sl := Label.new()
	sl.add_theme_font_size_override("font_size", 24)
	sl.text = "Level %d\nMoney  $%d\nDeliveries  %d\nBest fare  $%d" % [
		int(Save.data["level"]), int(Save.data["money"]), int(Save.data["deliveries"]), int(Save.data["best_fare"])]
	stats.add_child(sl)

	# Buttons (right side)
	_menu = VBoxContainer.new()
	_menu.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_menu.offset_left = -440
	_menu.offset_right = -50
	_menu.offset_top = -190
	_menu.offset_bottom = 190
	_menu.add_theme_constant_override("separation", 16)
	add_child(_menu)
	_add_btn("DRIVE", func(): Game.go("res://scenes/World.tscn"), Vector2(390, 96))
	_add_btn("Garage", func():
		Game.garage_return = "res://scenes/MainMenu.tscn"
		Game.go("res://scenes/Garage.tscn"))
	_add_btn("Settings", func():
		_menu.visible = false
		_settings.visible = true)
	_add_btn("How to play", func():
		_menu.visible = false
		_about.visible = true)
	if OS.get_name() != "Android" and OS.get_name() != "iOS":
		_add_btn("Quit", func():
			Save.save_game()
			get_tree().quit())

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_settings = SettingsPanel.new()
	_settings.visible = false
	_settings.closed.connect(func():
		_settings.visible = false
		_menu.visible = true)
	center.add_child(_settings)
	_about = _build_about()
	_about.visible = false
	center.add_child(_about)

func _add_btn(text: String, cb: Callable, size := Vector2(390, 76)) -> void:
	var b := Game.make_button(text, size)
	if text == "DRIVE":
		b.add_theme_font_size_override("font_size", 44)
	b.pressed.connect(func():
		Audio.play("click")
		cb.call())
	_menu.add_child(b)

func _build_about() -> PanelContainer:
	var p := PanelContainer.new()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	var h := Label.new()
	h.text = "HOW TO PLAY"
	h.add_theme_font_size_override("font_size", 40)
	h.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0))
	v.add_child(h)
	var body := Label.new()
	body.custom_minimum_size = Vector2(820, 0)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 24)
	body.text = "Follow the arrow and minimap to the GREEN ring and stop inside it to board passengers. " \
		+ "Then drive to the PINK ring before the timer runs out. Yellow checkpoint rings add time and cash.\n\n" \
		+ "Drive on the LEFT. Bumps lower passenger comfort and your fare. VIP riders leave if you drive too roughly. " \
		+ "Express runs pay more but are tight.\n\n" \
		+ "ION boost needs throttle and drains a bar that recharges. If you flip over, tap RST. " \
		+ "Spend money in the Garage on paint, neon, body kits and performance upgrades.\n\n" \
		+ "Keyboard: W/S gas-brake, A/D steer, Space handbrake, Shift boost, C camera, R reset, H horn, Esc pause."
	v.add_child(body)
	var back := Game.make_button("Back", Vector2(220, 64))
	back.pressed.connect(func():
		Audio.play("click")
		p.visible = false
		_menu.visible = true)
	v.add_child(back)
	return p
