extends Node3D
## Renders each roster car in a daylight studio: xvfb-run godot --rendering-driver opengl3 res://tests/CarShot.tscn -- OUTDIR
var out := "/tmp"
var idx := 1
var f := 0
var model: Node3D
var cam: Camera3D
func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: out = a[0]
	DisplayServer.window_set_size(Vector2i(960, 540))
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new(); var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.25, 0.45, 0.8); sm.sky_horizon_color = Color(0.7, 0.8, 0.9); sm.ground_horizon_color = Color(0.6, 0.62, 0.65); sm.ground_bottom_color = Color(0.3, 0.3, 0.32)
	sky.sky_material = sm; env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	var we := WorldEnvironment.new(); we.environment = env; add_child(we)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-40, -35, 0); sun.light_energy = 1.4; sun.shadow_enabled = true; add_child(sun)
	var floor_ := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(60, 60); floor_.mesh = pm
	floor_.material_override = _flat(); add_child(floor_)
	cam = Camera3D.new(); add_child(cam); cam.make_current()
	_spawn()
func _spawn() -> void:
	if model: model.queue_free()
	Save.data["color"] = [0, 1, 2, 3, 4, 5, 6][idx % 7]
	model = Cars.make_model(idx, 1)
	add_child(model)
	Cars.add_static_wheels(model, idx, MeshKit.mat(Color(0.7, 0.7, 0.75), 0, 1.0, 0.2))
	model.apply(int(Cars.spec(idx)["paint"]), 0, 3 if idx == 5 else 0)
	var L: float = Cars.spec(idx)["len"]
	cam.position = Vector3(-L * 0.62, 1.15, -L * 0.72)
	cam.fov = 42.0
	cam.look_at(Vector3(0, 0.55, 0.1), Vector3.UP)
	f = 0
func _process(_d: float) -> void:
	f += 1
	if f == 12:
		get_viewport().get_texture().get_image().save_png("%s/car_%d.png" % [out, idx])
		print("[car] %d %s" % [idx, Cars.spec(idx)["name"]])
		idx += 1
		if idx >= Cars.LIST.size(): get_tree().quit()
		else: _spawn()

func _flat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = Color(0.33, 0.34, 0.36); m.roughness = 1.0; m.metallic_specular = 0.0
	return m
