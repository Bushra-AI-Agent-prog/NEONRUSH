extends Node
## Persistent save data (JSON in user://). Autoload "Save".

const PATH := "user://neonbus_save.json"

var data: Dictionary = {}

func _default() -> Dictionary:
	return {
		"money": 300,
		"xp": 0,
		"level": 1,
		"deliveries": 0,
		"best_fare": 0,
		"total_earned": 0,
		"color": 0,
		"neon": 0,
		"kit": 0,
		"car": 0,
		"owned_cars": [0],
		"owned_colors": [0, 1],
		"owned_neons": [0, 1],
		"owned_kits": [0],
		"upgrades": {"engine": 0, "tires": 0, "brakes": 0, "suspension": 0, "battery": 0},
		"settings": {
			"quality": 1, "tod": 1, "music": 0.55, "sfx": 0.8, "steer_sens": 1.0,
			"left_handed": false, "tilt": false, "camera": 0, "show_fps": false,
		},
	}

func _ready() -> void:
	data = _default()
	load_game()

func load_game() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		_merge(data, parsed)
		_normalize()

## JSON has no int type: numbers come back as floats, which breaks Array.has(int).
func _normalize() -> void:
	for key in ["owned_colors", "owned_neons", "owned_kits", "owned_cars"]:
		var fixed: Array = []
		for v in data[key]:
			var i := int(v)
			if not fixed.has(i):
				fixed.append(i)
		data[key] = fixed
	for key in ["money", "xp", "level", "deliveries", "best_fare", "total_earned", "color", "neon", "kit", "car"]:
		data[key] = int(data[key])
	for key in data["upgrades"].keys():
		data["upgrades"][key] = int(data["upgrades"][key])

func save_game() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Save: cannot write " + PATH)
		return
	f.store_string(JSON.stringify(data))

## Recursively copy values from src into dst, keeping dst's defaults for missing keys.
func _merge(dst: Dictionary, src: Dictionary) -> void:
	for k in src.keys():
		if not dst.has(k):
			continue
		if dst[k] is Dictionary and src[k] is Dictionary:
			_merge(dst[k], src[k])
		elif typeof(dst[k]) == typeof(src[k]) or (dst[k] is float or dst[k] is int) and (src[k] is float or src[k] is int):
			dst[k] = src[k]

func setting(key: String) -> Variant:
	return data["settings"][key]

func set_setting(key: String, value: Variant) -> void:
	data["settings"][key] = value

func upgrade_level(key: String) -> int:
	return int(data["upgrades"].get(key, 0))

func add_money(amount: int) -> void:
	data["money"] = int(data["money"]) + amount
	if amount > 0:
		data["total_earned"] = int(data["total_earned"]) + amount

func spend(amount: int) -> bool:
	if int(data["money"]) < amount:
		return false
	data["money"] = int(data["money"]) - amount
	return true

## XP needed to go from `lvl` to `lvl+1`.
func xp_for_level(lvl: int) -> int:
	return 100 + (lvl - 1) * 80

## Adds XP; returns number of levels gained.
func add_xp(amount: int) -> int:
	data["xp"] = int(data["xp"]) + amount
	var gained := 0
	while int(data["xp"]) >= xp_for_level(int(data["level"])):
		data["xp"] = int(data["xp"]) - xp_for_level(int(data["level"]))
		data["level"] = int(data["level"]) + 1
		gained += 1
		add_money(150 * int(data["level"]))
	return gained

func reset_all() -> void:
	data = _default()
	save_game()
