extends Node3D
## Gameplay scene root: environment, city, bus, camera, traffic, missions, weather, HUD.

var env: Environment
var sun: DirectionalLight3D
var city: City
var bus: Microbus
var cam_rig: CameraRig
var traffic: Traffic
var missions: Missions
var weather: Weather
var hud: HUD

func _ready() -> void:
	_build_environment()

	city = City.new()
	add_child(city)
	city.build()

	bus = Microbus.new()
	bus.transform = city.spawn_transform()
	add_child(bus)

	cam_rig = CameraRig.new()
	add_child(cam_rig)
	cam_rig.target = bus

	traffic = Traffic.new()
	add_child(traffic)
	traffic.setup(city, bus)
	traffic.spawn(int(Game.quality()["traffic"]))

	missions = Missions.new()
	add_child(missions)
	missions.setup(city, bus)

	weather = Weather.new()
	add_child(weather)
	weather.setup(env, city, cam_rig)
	weather.fog_base = float(TOD[clampi(int(Save.setting("tod")), 0, 2)][10])
	weather.set_kind(0, true)
	apply_tod()
	_apply_shadows()

	hud = HUD.new()
	add_child(hud)
	hud.setup(bus, missions, city, cam_rig, weather)

	bus.crashed.connect(_on_crash)
	bus.reset_done.connect(cam_rig.snap)
	Game.quality_changed.connect(_on_quality)
	Game.apply_quality(get_viewport())
	get_tree().paused = false
	hud.show_toast("Drive to the green ring to pick up passengers", Color(0.4, 1.0, 0.7))

# [sun pitch, sun yaw, sun colour, sun energy, sky top, sky horizon, ground horizon, ground bottom,
#  ambient energy, fog colour, fog density, night amount, sky energy]
const TOD: Array = [
	[-55.0, 30.0, Color(1.0, 0.96, 0.88), 1.6, Color(0.17, 0.37, 0.75), Color(0.66, 0.78, 0.92), Color(0.58, 0.62, 0.64), Color(0.27, 0.28, 0.3), 1.0, Color(0.64, 0.74, 0.87), 0.0009, 0.0, 1.0],
	[-9.0, 60.0, Color(1.0, 0.6, 0.3), 1.5, Color(0.14, 0.2, 0.45), Color(0.98, 0.52, 0.28), Color(0.6, 0.36, 0.3), Color(0.15, 0.12, 0.14), 0.85, Color(0.8, 0.5, 0.4), 0.0015, 0.55, 1.0],
	[-32.0, 35.0, Color(0.5, 0.6, 1.0), 0.35, Color(0.008, 0.012, 0.05), Color(0.1, 0.08, 0.22), Color(0.07, 0.05, 0.14), Color(0.01, 0.01, 0.03), 0.55, Color(0.06, 0.05, 0.14), 0.0018, 1.0, 1.0],
]

var sky_mat: ProceduralSkyMaterial

func _build_environment() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sky_curve = 0.18
	sky_mat.ground_curve = 0.05
	sky_mat.sun_angle_max = 25.0
	sky_mat.sun_curve = 0.1
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 6.0
	env.fog_enabled = true
	env.fog_aerial_perspective = 0.0
	env.glow_enabled = bool(Game.quality()["glow"])
	env.glow_intensity = 0.7
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.1
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.08
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	sun = DirectionalLight3D.new()
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 120.0
	sun.shadow_blur = 1.4
	sun.light_angular_distance = 0.4
	add_child(sun)
	apply_tod()
	_apply_shadows()

## Apply the saved time-of-day preset to sky, sun, fog and city lighting.
func apply_tod() -> void:
	var t: Array = TOD[clampi(int(Save.setting("tod")), 0, 2)]
	sun.rotation_degrees = Vector3(t[0], t[1], 0)
	sun.light_color = t[2]
	sun.light_energy = t[3]
	sky_mat.sky_top_color = t[4]
	sky_mat.sky_horizon_color = t[5]
	sky_mat.ground_horizon_color = t[6]
	sky_mat.ground_bottom_color = t[7]
	sky_mat.sky_energy_multiplier = t[12]
	env.ambient_light_energy = t[8]
	env.fog_light_color = t[9]
	env.fog_density = t[10]
	if city != null:
		city.set_night(t[11])
	if weather != null:
		weather.fog_base = float(t[10])
		env.fog_density = weather.fog_base * Weather.FOG_MULT[weather.kind]

func _apply_shadows() -> void:
	var q := int(Save.setting("quality"))
	sun.shadow_enabled = q >= 1
	if city != null:
		city.set_building_shadows(q >= 2)

func _on_quality() -> void:
	var q := Game.quality()
	env.glow_enabled = bool(q["glow"])
	apply_tod()
	_apply_shadows()
	bus.apply_upgrades()

func _on_crash(strength: float) -> void:
	missions.on_crash(strength)
	cam_rig.shake(strength)
	if missions.state == Missions.S.TO_DROPOFF or missions.state == Missions.S.UNLOADING:
		hud.flash_damage()

func _notification(what: int) -> void:
	if hud == null:
		return
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		hud.set_paused(not get_tree().paused)
	elif what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		if not get_tree().paused:
			hud.set_paused(true)
		Save.save_game()
