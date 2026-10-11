class_name BusPreview
extends SubViewportContainer
## Rotating 3D showroom of the player's bus, used by the main menu and garage.

var model: Node3D
var _car := -1
var spin := true
var _pivot: Node3D
var _yaw := 25.0

func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = false
	vp.msaa_3d = Viewport.MSAA_2X if int(Save.setting("quality")) >= 2 else Viewport.MSAA_DISABLED
	add_child(vp)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.02, 0.07)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.45, 0.45, 0.7)
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = int(Save.setting("quality")) >= 1
	env.glow_intensity = 0.9
	env.glow_hdr_threshold = 1.2
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, -40, 0)
	key.light_energy = 1.1
	vp.add_child(key)
	var rim := OmniLight3D.new()
	rim.position = Vector3(-5, 3, -6)
	rim.light_color = Color(1.0, 0.2, 0.7)
	rim.light_energy = 3.0
	rim.omni_range = 18.0
	vp.add_child(rim)

	var floor_mat := MeshKit.mat(Color(0.03, 0.04, 0.09), 0.0, 0.0, 0.8)
	MeshKit.cyl(vp, 4.2, 0.1, Vector3(0, -0.85, 0), floor_mat, Vector3.ZERO, 48)
	MeshKit.cyl(vp, 4.3, 0.12, Vector3(0, -0.9, 0), MeshKit.mat(Color(0.0, 0.9, 1.0), 1.1), Vector3.ZERO, 48)

	_pivot = Node3D.new()
	vp.add_child(_pivot)
	_build_model(int(Save.data["car"]))

	var cam := Camera3D.new()
	cam.position = Vector3(0, 2.6, 9.0)
	cam.fov = 42.0
	vp.add_child(cam)
	cam.look_at(Vector3(0, 0.5, 0), Vector3.UP)
	cam.make_current()

func _build_model(car: int) -> void:
	if model != null:
		model.queue_free()
	_car = car
	model = Cars.make_model(car, 1)
	_pivot.add_child(model)
	Cars.add_static_wheels(model, car, model.neon_mat)
	# showroom floor top is at y = -0.8; the bus origin is 0.8 above its wheels' ground, cars are authored at ground = 0
	model.position.y = 0.0 if car == Cars.BUS else -0.8
	var L: float = Cars.spec(car)["len"]
	_pivot.scale = Vector3.ONE * clampf(4.8 / L, 0.8, 1.05)

## Re-read the saved customization (pass overrides; -1 = keep saved).
func refresh(color_i := -1, neon_i := -1, kit_i := -1, car_i := -1) -> void:
	var want := int(Save.data["car"]) if car_i < 0 else car_i
	if want != _car:
		_build_model(want)
	model.apply(
		int(Save.data["color"]) if color_i < 0 else color_i,
		int(Save.data["neon"]) if neon_i < 0 else neon_i,
		int(Save.data["kit"]) if kit_i < 0 else kit_i)

func _process(delta: float) -> void:
	if spin:
		_yaw += delta * 22.0
	_pivot.rotation_degrees.y = _yaw
