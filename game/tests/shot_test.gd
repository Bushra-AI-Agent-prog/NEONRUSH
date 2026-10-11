extends Node
## Renders real frames (needs a display, e.g. xvfb + software GL) and saves PNGs.
## xvfb-run -a godot --rendering-driver opengl3 --path . res://tests/ShotTest.tscn -- OUTDIR
var out := "/tmp"
var stage := 0
var f := 0
var cur: Node
var tod_i := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: out = a[0]
	DisplayServer.window_set_size(Vector2i(1280, 720))
	_load("res://scenes/MainMenu.tscn")

func _load(path: String) -> void:
	if cur: cur.queue_free()
	cur = (load(path) as PackedScene).instantiate()
	add_child(cur)
	f = 0

func _snap(name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [out, name])
	print("[shot] %s %dx%d" % [name, img.get_width(), img.get_height()])

func _process(_d: float) -> void:
	f += 1
	match stage:
		0:
			if f == 40: _snap("1_menu"); stage = 1; _load("res://scenes/Garage.tscn")
		1:
			if f == 40: _snap("2_garage"); stage = 2; f = 0
		2:
			if f == 1:
				Save.set_setting("tod", tod_i); Save.set_setting("quality", 2)
				cur.queue_free(); cur = (load("res://scenes/World.tscn") as PackedScene).instantiate(); add_child(cur); Game.apply_quality(get_viewport())
				if tod_i == 2: cur.weather.set_kind(1, true)
				Input.action_press("accelerate")
			if f == 140:
				_snap("world_tod%d" % tod_i)
				Input.action_release("accelerate")
				print("[fps] %d" % int(Engine.get_frames_per_second()))
				tod_i += 1
				f = 0
				if tod_i > 2: get_tree().quit()
