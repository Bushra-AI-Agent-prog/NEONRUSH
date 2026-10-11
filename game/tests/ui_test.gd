extends Node
## Headless UI/economy test: menu + garage build, purchases, upgrades, save round-trip.
## godot --headless --path . res://tests/UITest.tscn
var fails := 0
func check(name: String, ok: bool) -> void:
	print("[%s] %s" % ["PASS" if ok else "FAIL", name])
	if not ok: fails += 1

func _ready() -> void:
	Save.data = Save._default()
	var menu: Control = (load("res://scenes/MainMenu.tscn") as PackedScene).instantiate()
	add_child(menu); await get_tree().process_frame
	check("main menu builds", menu.get_child_count() > 3)
	menu.queue_free(); await get_tree().process_frame

	var garage: Control = (load("res://scenes/Garage.tscn") as PackedScene).instantiate()
	add_child(garage); await get_tree().process_frame
	check("garage builds (cars tab default)", garage._list.get_child_count() == Cars.LIST.size())
	# level lock
	garage._tab = 4; garage._rebuild(); await get_tree().process_frame
	check("upgrade rows", garage._list.get_child_count() == Game.UPGRADES.size())
	var m0 := int(Save.data["money"])
	var cost := Game.upgrade_cost("engine", 0)
	check("engine upgrade affordable", m0 >= cost)
	Save.spend(cost); Save.data["upgrades"]["engine"] = 1
	check("money deducted", int(Save.data["money"]) == m0 - cost)
	check("cannot overspend", not Save.spend(10000000))
	# upgrade changes vehicle tuning
	var bus := Microbus.new(); bus.audio_enabled = false
	add_child(bus); await get_tree().process_frame
	var v1 := bus.max_speed_ms
	Save.data["upgrades"]["engine"] = 5; Save.data["upgrades"]["tires"] = 5
	bus.apply_upgrades()
	check("engine upgrade raises top speed (%.1f -> %.1f m/s)" % [v1, bus.max_speed_ms], bus.max_speed_ms > v1)
	check("tire upgrade raises grip (%.2f)" % bus.grip, bus.grip > 5.0)
	# car roster + purchase
	check("7 cars in roster", Cars.LIST.size() == 7)
	garage._tab = 0; garage._rebuild(); await get_tree().process_frame
	check("cars tab rows", garage._list.get_child_count() == Cars.LIST.size())
	check("kairo locked at level 1 (level %d)" % int(Save.data["level"]), int(Save.data["level"]) < int(Cars.spec(1)["level"]))
	Save.data["level"] = 2; Save.data["money"] = 5000
	garage._rebuild(); await get_tree().process_frame
	var kb: Button = garage._list.get_child(1).get_child(0).get_child(1)
	check("kairo buyable at level 2 (button '%s')" % kb.text, kb.text.begins_with("Buy") and not kb.disabled)
	kb.pressed.emit(); await get_tree().process_frame
	check("kairo purchased + equipped", int(Save.data["car"]) == 1 and (Save.data["owned_cars"] as Array).has(1) and int(Save.data["money"]) == 5000 - int(Cars.spec(1)["cost"]))
	check("showroom switched to kairo", garage._preview._car == 1 and garage._preview.model is CarModel)
	var kb2 := Microbus.new(); kb2.audio_enabled = false; add_child(kb2); await get_tree().process_frame
	check("vehicle spawns selected car", kb2.car_idx == 1 and kb2.model is CarModel and kb2.wheels.size() == 4)
	kb2.queue_free()
	Save.data["car"] = 0
	# xp / level
	var lv0 := int(Save.data["level"])
	var gained := Save.add_xp(Save.xp_for_level(lv0) + 5)
	check("xp levels up with bonus", gained == 1 and int(Save.data["level"]) == lv0 + 1)
	# save round trip
	Save.data["color"] = 1; Save.set_setting("quality", 2); Save.save_game()
	Save.data = Save._default(); Save.load_game()
	check("save round-trip", int(Save.data["color"]) == 1 and int(Save.setting("quality")) == 2 and int(Save.data["upgrades"]["engine"]) == 5)
	check("owned lists are ints after load (JSON float bug)", (Save.data["owned_colors"] as Array).has(0) and (Save.data["owned_colors"] as Array).has(1) and typeof((Save.data["owned_colors"] as Array)[0]) == TYPE_INT)
	garage._tab = 1; garage._rebuild(); await get_tree().process_frame
	var first_btn: Button = garage._list.get_child(0).get_child(0).get_child(2)
	check("owned item shows Equip/Equipped after reload, not Buy", not first_btn.text.begins_with("Buy"))
	# corrupted save must not crash
	var f := FileAccess.open(Save.PATH, FileAccess.WRITE); f.store_string("{not json"); f.close()
	Save.data = Save._default(); Save.load_game()
	check("corrupt save falls back to defaults", int(Save.data["money"]) == 300)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Save.PATH))
	print("[result] %d failure(s)" % fails)
	get_tree().quit(1 if fails > 0 else 0)
