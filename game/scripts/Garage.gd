extends Control
## Garage: buy/equip paint, neon, body kits; buy performance upgrades.

var _preview: BusPreview
var _money: Label
var _list: VBoxContainer
var _tab := 0
var _tab_btns: Array[Button] = []

const TABS := ["Cars", "Paint", "Neon", "Kits", "Upgrades"]

func _ready() -> void:
	theme = Game.ui_theme
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Audio.engine_on(false)
	Game.apply_quality(get_viewport())

	_preview = BusPreview.new()
	_preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_preview)

	var head := Label.new()
	head.text = "GARAGE"
	head.position = Vector2(50, 24)
	head.add_theme_font_size_override("font_size", 64)
	head.add_theme_color_override("font_color", Color(0.0, 0.95, 1.0))
	add_child(head)
	_money = Label.new()
	_money.position = Vector2(54, 106)
	_money.add_theme_font_size_override("font_size", 38)
	_money.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	add_child(_money)

	var back := Game.make_button("< Back", Vector2(230, 70))
	back.position = Vector2(50, 0)
	back.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	back.offset_left = 40
	back.offset_top = -100
	back.offset_right = 270
	back.offset_bottom = -30
	back.pressed.connect(func():
		Audio.play("click")
		Game.go(Game.garage_return))
	add_child(back)

	# Right-hand panel with tabs and scrolling list
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	panel.offset_left = -640
	panel.offset_right = -24
	panel.offset_top = 20
	panel.offset_bottom = -20
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	v.add_child(tabs)
	for i in TABS.size():
		var b := Game.make_button(TABS[i], Vector2(112, 60))
		b.add_theme_font_size_override("font_size", 20)
		var idx := i
		b.pressed.connect(func():
			Audio.play("click")
			_tab = idx
			_rebuild())
		tabs.add_child(b)
		_tab_btns.append(b)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_list)
	_rebuild()

func _rebuild() -> void:
	for ch in _list.get_children():
		ch.queue_free()
	for i in _tab_btns.size():
		_tab_btns[i].disabled = (i == _tab)
	_money.text = "$ %d     Level %d" % [int(Save.data["money"]), int(Save.data["level"])]
	_preview.refresh()
	match _tab:
		0:
			_car_rows()
		1:
			_cosmetic_rows(Game.COLORS, "color", "owned_colors")
		2:
			_cosmetic_rows(Game.NEONS, "neon", "owned_neons")
		3:
			_cosmetic_rows(Game.KITS, "kit", "owned_kits")
		4:
			_upgrade_rows()

func _row(title: String, sub: String, btn_text: String, enabled: bool, cb: Callable, swatch := Color(0, 0, 0, 0)) -> void:
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_child(p)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	p.add_child(h)
	if swatch.a > 0.0:
		var sw := ColorRect.new()
		sw.color = swatch
		sw.custom_minimum_size = Vector2(36, 36)
		h.add_child(sw)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(col)
	var t := Label.new()
	t.text = title
	t.add_theme_font_size_override("font_size", 26)
	col.add_child(t)
	var s := Label.new()
	s.text = sub
	s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	s.custom_minimum_size = Vector2(300, 0)
	s.add_theme_font_size_override("font_size", 18)
	s.add_theme_color_override("font_color", Color(0.7, 0.8, 0.95))
	col.add_child(s)
	var b := Game.make_button(btn_text, Vector2(190, 58))
	b.add_theme_font_size_override("font_size", 22)
	b.disabled = not enabled
	b.pressed.connect(cb)
	h.add_child(b)

func _cosmetic_rows(items: Array, key: String, owned_key: String) -> void:
	var lvl := int(Save.data["level"])
	for i in items.size():
		var it: Dictionary = items[i]
		var owned: bool = (Save.data[owned_key] as Array).has(i)
		var equipped: bool = int(Save.data[key]) == i
		var sw: Color = it["color"] if it.has("color") else Color(0, 0, 0, 0)
		var idx := i
		if owned:
			_row(it["name"], "Equipped" if equipped else "Owned", "Equipped" if equipped else "Equip", not equipped, func():
				Save.data[key] = idx
				Audio.play("click")
				Save.save_game()
				_rebuild(), sw)
		elif lvl < int(it["level"]):
			_row(it["name"], "Unlocks at level %d" % it["level"], "Locked", false, func(): pass, sw)
		else:
			var cost := int(it["cost"])
			_row(it["name"], "$%d" % cost, "Buy $%d" % cost, int(Save.data["money"]) >= cost, func():
				if Save.spend(cost):
					(Save.data[owned_key] as Array).append(idx)
					Save.data[key] = idx
					Audio.play("coin")
					Save.save_game()
					_rebuild(), sw)

func _upgrade_rows() -> void:
	for key in Game.UPGRADES.keys():
		var u: Dictionary = Game.UPGRADES[key]
		var lv := Save.upgrade_level(key)
		var k: String = key
		if lv >= Game.MAX_UPGRADE:
			_row("%s  [MAX]" % u["name"], u["desc"], "Maxed", false, func(): pass)
		else:
			var cost := Game.upgrade_cost(k, lv)
			_row("%s  Lv %d/%d" % [u["name"], lv, Game.MAX_UPGRADE], u["desc"], "Upgrade $%d" % cost, int(Save.data["money"]) >= cost, func():
				if Save.spend(cost):
					Save.data["upgrades"][k] = lv + 1
					Audio.play("levelup", -4.0)
					Save.save_game()
					_rebuild())

func _car_rows() -> void:
	var lvl := int(Save.data["level"])
	for i in Cars.LIST.size():
		var c: Dictionary = Cars.LIST[i]
		var owned: bool = (Save.data["owned_cars"] as Array).has(i)
		var equipped: bool = int(Save.data["car"]) == i
		var stats := "%d km/h  |  %s" % [int(c["kmh"]), c["desc"]]
		var idx := i
		if owned:
			_row(c["name"], stats, "Driving" if equipped else "Drive", not equipped, func():
				Save.data["car"] = idx
				Audio.play("click")
				Save.save_game()
				_rebuild())
		elif lvl < int(c["level"]):
			_row(c["name"], "Unlocks at level %d  |  %s" % [c["level"], stats], "Locked", false, func(): pass)
		else:
			var cost := int(c["cost"])
			_row(c["name"], stats, "Buy $%d" % cost, int(Save.data["money"]) >= cost, func():
				if Save.spend(cost):
					(Save.data["owned_cars"] as Array).append(idx)
					Save.data["car"] = idx
					Audio.play("coin")
					Save.save_game()
					_rebuild())
