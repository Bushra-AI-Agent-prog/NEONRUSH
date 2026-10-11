class_name HUD
extends CanvasLayer
## Driving HUD: speedometer + ION boost, rotating minimap with route, direction
## arrow, mission panel, toasts, banners, touch controls and the pause menu.

# ----------------------------------------------------------------------------
class MiniMap extends Control:
	var bus: Microbus
	var missions: Missions
	const SCALE := 0.36

	func _ready() -> void:
		custom_minimum_size = Vector2(230, 230)
		clip_contents = true
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_d: float) -> void:
		queue_redraw()

	func _w2m(p: Vector3) -> Vector2:
		var f := -bus.global_transform.basis.z
		var fv := Vector2(f.x, f.z).normalized()
		var r := Vector2(-fv.y, fv.x)
		var rel := Vector2(p.x - bus.global_position.x, p.z - bus.global_position.z)
		return size / 2.0 + Vector2(rel.dot(r), -rel.dot(fv)) * SCALE

	func _draw() -> void:
		if bus == null:
			return
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.03, 0.08, 0.82))
		var half := (City.N * City.P + City.ROAD) / 2.0
		for k in City.N + 1:
			var cc := City.c(k)
			draw_line(_w2m(Vector3(-half, 0, cc)), _w2m(Vector3(half, 0, cc)), Color(0.2, 0.26, 0.4), City.ROAD * SCALE)
			draw_line(_w2m(Vector3(cc, 0, -half)), _w2m(Vector3(cc, 0, half)), Color(0.2, 0.26, 0.4), City.ROAD * SCALE)
		if missions != null:
			if missions.guide.size() > 0:
				var pts := PackedVector2Array()
				pts.append(_w2m(bus.global_position))
				for g in missions.guide:
					pts.append(_w2m(g))
				draw_polyline(pts, Color(0.3, 1.0, 0.6, 0.9), 4.0, true)
			for cp in missions.checkpoints:
				draw_circle(_w2m(cp), 5.0, Color(1.0, 0.9, 0.2))
			var tp := missions.target_pos()
			if tp != Vector3.INF:
				var q := _w2m(tp)
				var inset := Rect2(Vector2(12, 12), size - Vector2(24, 24))
				var clamped := Vector2(clampf(q.x, inset.position.x, inset.end.x), clampf(q.y, inset.position.y, inset.end.y))
				var col := Color(0.2, 1.0, 0.6) if (missions.state == Missions.S.TO_PICKUP or missions.state == Missions.S.BOARDING) else Color(1.0, 0.25, 0.7)
				draw_circle(clamped, 9.0, col)
				draw_arc(clamped, 12.0, 0.0, TAU, 20, Color.WHITE, 2.0)
		var c := size / 2.0
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -14), c + Vector2(9, 11), c + Vector2(0, 5), c + Vector2(-9, 11)]), Color(0.0, 0.95, 1.0))
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.9, 1.0, 0.8), false, 3.0)

# ----------------------------------------------------------------------------
class NavArrow extends Control:
	var bus: Microbus
	var missions: Missions

	func _ready() -> void:
		custom_minimum_size = Vector2(200, 120)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if bus == null or missions == null or not missions.active():
			return
		var wp := missions.next_waypoint()
		if wp == Vector3.INF:
			return
		var f := -bus.global_transform.basis.z
		var fv := Vector2(f.x, f.z).normalized()
		var r := Vector2(-fv.y, fv.x)
		var dir := Vector2(wp.x - bus.global_position.x, wp.z - bus.global_position.z)
		var ang := atan2(dir.dot(r), dir.dot(fv))
		var col := Color(0.3, 1.0, 0.6) if (missions.state == Missions.S.TO_PICKUP or missions.state == Missions.S.BOARDING) else Color(1.0, 0.3, 0.75)
		draw_set_transform(Vector2(size.x / 2.0, 46), ang)
		draw_colored_polygon(PackedVector2Array([Vector2(0, -34), Vector2(28, 24), Vector2(0, 10), Vector2(-28, 24)]), col)
		draw_polyline(PackedVector2Array([Vector2(0, -34), Vector2(28, 24), Vector2(0, 10), Vector2(-28, 24), Vector2(0, -34)]), Color.WHITE, 2.0)
		draw_set_transform(Vector2.ZERO, 0.0)
		var txt := "%d m" % int(missions.route_dist)
		var font := ThemeDB.fallback_font
		var sz := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 28)
		draw_string(font, Vector2((size.x - sz.x) / 2.0, 108), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color.WHITE)

# ----------------------------------------------------------------------------
class Speedo extends Control:
	var bus: Microbus

	func _ready() -> void:
		custom_minimum_size = Vector2(280, 200)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if bus == null:
			return
		var c := Vector2(size.x / 2.0, 100)
		var a0 := deg_to_rad(145.0)
		var a1 := deg_to_rad(395.0)
		var ratio := clampf(bus.speed_kmh / 200.0, 0.0, 1.0)
		draw_arc(c, 88.0, a0, a1, 48, Color(0.1, 0.14, 0.24, 0.8), 14.0, true)
		var col := Color(0.0, 0.9, 1.0).lerp(Color(1.0, 0.15, 0.65), ratio)
		if ratio > 0.01:
			draw_arc(c, 88.0, a0, a0 + (a1 - a0) * ratio, 48, col, 14.0, true)
		var font := ThemeDB.fallback_font
		var s := "%d" % int(bus.speed_kmh)
		var sz := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 64)
		draw_string(font, Vector2(c.x - sz.x / 2.0, c.y + 18), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 64, Color.WHITE)
		var u := "km/h"
		var usz := font.get_string_size(u, HORIZONTAL_ALIGNMENT_LEFT, -1, 22)
		draw_string(font, Vector2(c.x - usz.x / 2.0, c.y + 44), u, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.7, 0.85, 1.0))
		# ION boost bar
		var bx := c.x - 100.0
		draw_rect(Rect2(bx, 178, 200, 14), Color(0.1, 0.12, 0.2, 0.85))
		var bc := Color(0.7, 0.5, 1.0) if not bus.boosting else Color(1.0, 0.9, 0.4)
		draw_rect(Rect2(bx, 178, 200.0 * bus.boost_energy, 14), bc)
		draw_rect(Rect2(bx, 178, 200, 14), Color(0.6, 0.4, 1.0, 0.9), false, 2.0)

# ----------------------------------------------------------------------------
signal garage_requested

var bus: Microbus
var missions: Missions
var city: City
var cam_rig: CameraRig
var weather: Weather
var touch: TouchControls

var _root: Control
var _money: Label
var _level: Label
var _xp: ProgressBar
var _m_title: Label
var _m_timer: Label
var _m_status: Label
var _m_prog: ProgressBar
var _m_info: Label
var _mission_panel: PanelContainer
var _toasts: VBoxContainer
var _banner: Label
var _fps: Label
var _pause: Control
var _pause_menu: Control
var _settings: SettingsPanel
var _weather_label: Label
var _flash: ColorRect
var _fps_t := 0.0

func setup(b: Microbus, m: Missions, c: City, cr: CameraRig, w: Weather) -> void:
	bus = b
	missions = m
	city = c
	cam_rig = cr
	weather = w
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	missions.toast.connect(show_toast)
	missions.completed.connect(_on_completed)
	missions.failed.connect(_on_failed)
	weather.changed.connect(func(n: String): show_toast("Weather: " + n, Color(0.7, 0.85, 1.0)))
	Game.quality_changed.connect(_on_settings_changed)
	_on_settings_changed()

func _build() -> void:
	_root = Control.new()
	_root.theme = Game.ui_theme
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# Damage flash
	_flash = ColorRect.new()
	_flash.color = Color(1, 0.1, 0.1, 0.0)
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_flash)

	# Top-left: money / level
	var tl := PanelContainer.new()
	tl.position = Vector2(16, 14)
	tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(tl)
	var tlv := VBoxContainer.new()
	tlv.add_theme_constant_override("separation", 4)
	tl.add_child(tlv)
	_money = Label.new()
	_money.add_theme_font_size_override("font_size", 34)
	_money.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	tlv.add_child(_money)
	_level = Label.new()
	_level.add_theme_font_size_override("font_size", 22)
	tlv.add_child(_level)
	_xp = ProgressBar.new()
	_xp.custom_minimum_size = Vector2(220, 12)
	_xp.show_percentage = false
	tlv.add_child(_xp)

	# Mission panel (top centre)
	_mission_panel = PanelContainer.new()
	_mission_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_mission_panel.offset_left = -270
	_mission_panel.offset_right = 270
	_mission_panel.offset_top = 12
	_mission_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_mission_panel)
	var mv := VBoxContainer.new()
	mv.add_theme_constant_override("separation", 4)
	_mission_panel.add_child(mv)
	var r1 := HBoxContainer.new()
	mv.add_child(r1)
	_m_title = Label.new()
	_m_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_m_title.add_theme_font_size_override("font_size", 28)
	r1.add_child(_m_title)
	_m_timer = Label.new()
	_m_timer.add_theme_font_size_override("font_size", 30)
	r1.add_child(_m_timer)
	_m_status = Label.new()
	_m_status.add_theme_font_size_override("font_size", 22)
	mv.add_child(_m_status)
	_m_prog = ProgressBar.new()
	_m_prog.custom_minimum_size = Vector2(0, 14)
	_m_prog.show_percentage = false
	_m_prog.max_value = 1.0
	mv.add_child(_m_prog)
	_m_info = Label.new()
	_m_info.add_theme_font_size_override("font_size", 20)
	_m_info.add_theme_color_override("font_color", Color(0.75, 0.88, 1.0))
	mv.add_child(_m_info)

	# Nav arrow
	var nav := NavArrow.new()
	nav.bus = bus
	nav.missions = missions
	nav.set_anchors_preset(Control.PRESET_CENTER_TOP)
	nav.offset_left = -100
	nav.offset_right = 100
	nav.offset_top = 150
	nav.offset_bottom = 270
	_root.add_child(nav)

	# Minimap (left, above steering)
	var mm := MiniMap.new()
	mm.bus = bus
	mm.missions = missions
	mm.position = Vector2(16, 158)
	_root.add_child(mm)
	_weather_label = Label.new()
	_weather_label.position = Vector2(20, 392)
	_weather_label.add_theme_font_size_override("font_size", 18)
	_root.add_child(_weather_label)

	# Speedo (bottom centre)
	var sp := Speedo.new()
	sp.bus = bus
	sp.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	sp.offset_left = -140
	sp.offset_right = 140
	sp.offset_top = -205
	sp.offset_bottom = -5
	_root.add_child(sp)

	# Toasts + banner
	_toasts = VBoxContainer.new()
	_toasts.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toasts.offset_left = -300
	_toasts.offset_right = 300
	_toasts.offset_top = 285
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_toasts)
	_banner = Label.new()
	_banner.set_anchors_preset(Control.PRESET_CENTER)
	_banner.offset_left = -420
	_banner.offset_right = 420
	_banner.offset_top = -90
	_banner.offset_bottom = 90
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override("font_size", 54)
	_banner.add_theme_constant_override("outline_size", 10)
	_banner.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_banner.modulate.a = 0.0
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_banner)

	_fps = Label.new()
	_fps.position = Vector2(250, 20)
	_fps.add_theme_font_size_override("font_size", 18)
	_root.add_child(_fps)

	# Touch controls
	touch = TouchControls.new()
	add_child(touch)

	_build_pause()

func _build_pause() -> void:
	_pause = Control.new()
	_pause.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause.visible = false
	_pause.process_mode = Node.PROCESS_MODE_ALWAYS
	_root.add_child(_pause)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.05, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause.add_child(center)

	_pause_menu = PanelContainer.new()
	center.add_child(_pause_menu)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	_pause_menu.add_child(vb)
	var t := Label.new()
	t.text = "PAUSED"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 52)
	t.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0))
	vb.add_child(t)
	var items := [
		["Resume", func(): set_paused(false)],
		["Skip current job", func():
			missions.skip_job()
			set_paused(false)],
		["Garage", func():
			Game.garage_return = "res://scenes/World.tscn"
			Game.go("res://scenes/Garage.tscn")],
		["Settings", func():
			_pause_menu.visible = false
			_settings.visible = true],
		["Main menu", func(): Game.go("res://scenes/MainMenu.tscn")],
	]
	for it in items:
		var b := Game.make_button(it[0], Vector2(420, 68))
		var cb: Callable = it[1]
		b.pressed.connect(func():
			Audio.play("click")
			cb.call())
		vb.add_child(b)

	_settings = SettingsPanel.new()
	_settings.visible = false
	_settings.closed.connect(func():
		_settings.visible = false
		_pause_menu.visible = true)
	center.add_child(_settings)

# ------------------------------------------------------------------ public

func set_paused(p: bool) -> void:
	get_tree().paused = p
	_pause.visible = p
	_pause_menu.visible = p
	_settings.visible = false
	touch.visible = not p
	Audio.engine_on(not p)
	if p:
		Save.save_game()

func is_paused() -> bool:
	return get_tree().paused

func show_toast(text: String, color: Color = Color.WHITE) -> void:
	while _toasts.get_child_count() >= 3:
		var old := _toasts.get_child(0)
		_toasts.remove_child(old)
		old.queue_free()
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 28)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_toasts.add_child(l)
	var tw := l.create_tween()
	tw.tween_interval(2.2)
	tw.tween_property(l, "modulate:a", 0.0, 0.6)
	tw.tween_callback(l.queue_free)

func show_banner(text: String, color: Color) -> void:
	_banner.text = text
	_banner.add_theme_color_override("font_color", color)
	_banner.modulate.a = 1.0
	_banner.pivot_offset = _banner.size / 2.0
	_banner.scale = Vector2(0.6, 0.6)
	var tw := _banner.create_tween()
	tw.tween_property(_banner, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(2.4)
	tw.tween_property(_banner, "modulate:a", 0.0, 0.6)

func flash_damage() -> void:
	_flash.color.a = 0.28
	_flash.create_tween().tween_property(_flash, "color:a", 0.0, 0.5)

# ------------------------------------------------------------------ events

func _on_completed(fare: int, xp: int, levels: int) -> void:
	var txt := "DELIVERED!\n+$%d   +%d XP" % [fare, xp]
	if levels > 0:
		txt += "\nLEVEL UP! Lv %d" % int(Save.data["level"])
	show_banner(txt, Color(0.4, 1.0, 0.6))

func _on_failed(reason: String) -> void:
	show_banner("JOB FAILED\n" + reason, Color(1.0, 0.4, 0.35))

func _on_settings_changed() -> void:
	if _fps != null:
		_fps.visible = bool(Save.setting("show_fps"))
	if touch != null:
		touch.layout()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		set_paused(not get_tree().paused)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("cam") and not get_tree().paused:
		show_toast("Camera: " + cam_rig.cycle(), Color(0.7, 0.9, 1.0))

# ------------------------------------------------------------------ per-frame

func _process(delta: float) -> void:
	_money.text = "$ %d" % int(Save.data["money"])
	var lvl := int(Save.data["level"])
	_level.text = "LEVEL %d" % lvl
	_xp.max_value = Save.xp_for_level(lvl)
	_xp.value = int(Save.data["xp"])
	_weather_label.text = Weather.NAMES[weather.kind]

	var m := missions
	var has_job := m.state != Missions.S.IDLE and not m.job.is_empty()
	_mission_panel.visible = true
	if m.state == Missions.S.IDLE or m.state == Missions.S.RESULT or m.job.is_empty():
		_m_title.text = "Taxi dispatch"
		_m_title.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
		_m_timer.text = ""
		_m_status.text = m.status_text()
		_m_prog.visible = false
		_m_info.text = ""
	elif has_job:
		var ty: Dictionary = Missions.TYPES[m.job["type"]]
		_m_title.text = ty["name"]
		_m_title.add_theme_color_override("font_color", ty["color"])
		_m_status.text = m.status_text()
		var boarding := m.state == Missions.S.BOARDING or m.state == Missions.S.UNLOADING
		_m_prog.visible = boarding
		_m_prog.value = m.progress
		if m.state == Missions.S.TO_DROPOFF or m.state == Missions.S.UNLOADING:
			var tl := maxf(m.time_left, 0.0)
			_m_timer.text = "%d:%02d" % [int(tl) / 60, int(tl) % 60]
			_m_timer.add_theme_color_override("font_color", Color(1, 0.35, 0.3) if tl < 15.0 else Color.WHITE)
			_m_info.text = "Comfort %d%%   Fare ~$%d" % [int(m.comfort), m.estimate_fare()]
		else:
			_m_timer.text = ""
			_m_info.text = "%d passenger%s waiting" % [m.job["pax"], "" if m.job["pax"] == 1 else "s"]

	if _fps.visible:
		_fps_t -= delta
		if _fps_t <= 0.0:
			_fps_t = 0.5
			_fps.text = "%d FPS" % int(Engine.get_frames_per_second())
