class_name Weather
extends Node
## Cycles clear / rain / fog. Rain is a camera-following particle field and
## makes the roads reflective.

signal changed(name: String)

const NAMES := ["Clear", "Rain", "Fog"]
const FOG_MULT := [1.0, 1.5, 4.25]
var fog_base := 0.0016

var env: Environment
var city: City
var cam_rig: CameraRig
var kind := 0
var _wet := 0.0
var _target_wet := 0.0
var _timer := 70.0
var _rain: GPUParticles3D
var _rng := RandomNumberGenerator.new()

func setup(e: Environment, c: City, cr: CameraRig) -> void:
	env = e
	city = c
	cam_rig = cr
	_rng.randomize()
	_build_rain()
	Game.quality_changed.connect(_on_quality)
	_on_quality()

func _build_rain() -> void:
	_rain = GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(24, 0.5, 24)
	pm.direction = Vector3(0.08, -1, 0)
	pm.spread = 2.0
	pm.initial_velocity_min = 38.0
	pm.initial_velocity_max = 46.0
	pm.gravity = Vector3(0, -8, 0)
	_rain.process_material = pm
	var bm := BoxMesh.new()
	bm.size = Vector3(0.022, 0.8, 0.022)
	_rain.draw_pass_1 = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.7, 0.9, 1.0, 0.55)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.material = m
	_rain.lifetime = 0.95
	_rain.visibility_aabb = AABB(Vector3(-40, -40, -40), Vector3(80, 80, 80))
	_rain.local_coords = false
	_rain.emitting = false
	_rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_rain)

func _on_quality() -> void:
	_rain.amount = int(Game.quality()["rain"])

func set_kind(k: int, instant := false) -> void:
	kind = k
	_rain.emitting = (k == 1)
	_target_wet = 1.0 if k == 1 else 0.0
	Audio.rain_on(k == 1)
	if instant:
		env.fog_density = fog_base * FOG_MULT[k]
	else:
		create_tween().tween_property(env, "fog_density", fog_base * FOG_MULT[k], 6.0)
	changed.emit(NAMES[k])

func _process(delta: float) -> void:
	if cam_rig != null and cam_rig.cam != null:
		_rain.global_position = cam_rig.cam.global_position + Vector3(0, 13, 0)
	_wet = move_toward(_wet, _target_wet, delta * 0.12)
	city.set_wet(_wet)
	_timer -= delta
	if _timer <= 0.0:
		_timer = _rng.randf_range(80.0, 150.0)
		var nk := _rng.randi() % 3
		if nk == kind:
			nk = 0
		set_kind(nk)
