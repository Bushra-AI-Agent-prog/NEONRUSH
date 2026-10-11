class_name Microbus
extends VehicleBody3D
## Drivable futuristic microbus: arcade-tuned VehicleBody3D with upgrades,
## ION boost, crash events and automatic recovery. Forward is -Z.

signal crashed(strength: float)
signal reset_done

var model: Node3D   # BusModel or CarModel (same duck-typed API)
var car_idx := -1   # set before add_child; -1 = the player's selected car
var spec: Dictionary
var wheels: Array[VehicleWheel3D] = []

var speed_kmh := 0.0
var forward_speed := 0.0
var boost_energy := 1.0
var boosting := false
var braking := false
var control_enabled := true
var audio_enabled := true

# Tuned values (set by apply_upgrades)
var max_speed_ms := 36.0
var power := 3000.0
var brake_power := 30.0
var grip := 5.0
var steer_sens := 1.0
var boost_drain := 0.35

var _prev_vel := Vector3.ZERO
var _crash_cd := 0.0
var _flip_time := 0.0
var _boost_cd := 0.0
var _pending_reset := false
var _reset_pos := Vector3.ZERO
var _reset_yaw := 0.0
var _safe_pos := Vector3.ZERO
var _safe_timer := 0.0

func _ready() -> void:
	if car_idx < 0:
		car_idx = int(Save.data["car"])
	spec = Cars.spec(car_idx)
	mass = float(spec["mass"])
	can_sleep = false
	linear_damp = 0.02
	angular_damp = 1.2
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = spec["com"]
	collision_layer = 2
	collision_mask = 1 | 2

	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = spec["box"]
	cs.shape = shape
	cs.position = Vector3(0, float(spec["box_y"]), 0)
	add_child(cs)

	model = Cars.make_model(car_idx, 1)
	model.position.y = -float(spec["oh"])
	add_child(model)
	refresh_customization()

	var wx: float = spec["wx"]
	var wy: float = spec["wy"]
	for z in [spec["wzf"], spec["wzr"]]:
		for sx in [-1.0, 1.0]:
			var x := wx if car_idx == Cars.BUS else CarBuilder.wheel_x(spec, float(z))
			_add_wheel(Vector3(float(sx) * x, wy, float(z)), float(z) < 0.0)

	apply_upgrades()
	_safe_pos = global_position
	_prev_vel = Vector3.ZERO
	Game.quality_changed.connect(_on_quality)
	_on_quality()
	if audio_enabled:
		Audio.engine_on(true)

func _exit_tree() -> void:
	Audio.engine_on(false)

func _on_quality() -> void:
	model.set_lights_quality(int(Save.setting("quality")))

func _add_wheel(pos: Vector3, front: bool) -> void:
	var w := VehicleWheel3D.new()
	w.position = pos
	w.use_as_steering = front
	w.use_as_traction = true
	w.wheel_radius = float(spec["wr"]) + (0.0 if car_idx == Cars.BUS else 0.035)
	w.wheel_rest_length = float(spec["rest"])
	w.suspension_travel = 0.3
	w.suspension_stiffness = float(spec["stiff"])
	w.suspension_max_force = 16000.0
	w.wheel_roll_influence = float(spec["roll"])
	w.wheel_friction_slip = grip
	if car_idx == Cars.BUS:
		MeshKit.wheel_visual(w, 0.4, 0.3, model.neon_mat)
	else:
		CarBuilder.wheel_visual(w, spec, 1)
	add_child(w)
	wheels.append(w)

func refresh_customization() -> void:
	model.apply(int(Save.data["color"]), int(Save.data["neon"]), int(Save.data["kit"]))

func apply_upgrades() -> void:
	var e := Save.upgrade_level("engine")
	var t := Save.upgrade_level("tires")
	var b := Save.upgrade_level("brakes")
	var s := Save.upgrade_level("suspension")
	var c := Save.upgrade_level("battery")
	max_speed_ms = (float(spec["top"]) + 16.0 * e) * 1.27 / 3.6
	power = float(spec["power"]) * (1.0 + 0.13 * e)
	brake_power = float(spec["brake"]) * (1.0 + 0.16 * b)
	grip = float(spec["grip"]) + 0.55 * t
	boost_drain = 0.35 / (1.0 + 0.22 * c)
	steer_sens = float(Save.setting("steer_sens"))
	for w in wheels:
		w.wheel_friction_slip = grip
		w.suspension_stiffness = float(spec["stiff"]) + 4.0 * s
		w.wheel_roll_influence = maxf(0.03, float(spec["roll"]) - 0.015 * s)

## Request an upright teleport. Pass Vector3.INF to reuse the current spot.
func request_reset(pos := Vector3.INF, yaw := NAN) -> void:
	_reset_pos = (global_position + Vector3(0, 1.4, 0)) if pos == Vector3.INF else pos
	_reset_yaw = global_rotation.y if is_nan(yaw) else yaw
	_pending_reset = true

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if _pending_reset:
		_pending_reset = false
		state.transform = Transform3D(Basis(Vector3.UP, _reset_yaw), _reset_pos)
		state.linear_velocity = Vector3.ZERO
		state.angular_velocity = Vector3.ZERO
		_prev_vel = Vector3.ZERO
		_flip_time = 0.0
		reset_physics_interpolation()
		reset_done.emit()

func _physics_process(delta: float) -> void:
	forward_speed = linear_velocity.dot(-global_transform.basis.z)
	speed_kmh = linear_velocity.length() * 3.6
	_crash_cd = maxf(0.0, _crash_cd - delta)

	var throttle := 0.0
	var brake_in := 0.0
	var steer_in := 0.0
	var hand := false
	var want_boost := false
	if control_enabled:
		throttle = Input.get_action_strength("accelerate")
		brake_in = Input.get_action_strength("brake")
		steer_in = Input.get_axis("steer_left", "steer_right")
		hand = Input.is_action_pressed("handbrake")
		want_boost = Input.is_action_pressed("boost")
		if Input.is_action_just_pressed("horn"):
			honk()
		if Input.is_action_just_pressed("reset"):
			request_reset()
		if bool(Save.setting("tilt")):
			steer_in = clampf(Input.get_accelerometer().y / 5.0, -1.0, 1.0)

	# ION boost
	boosting = want_boost and boost_energy > 0.02 and throttle > 0.1
	if boosting:
		boost_energy = maxf(0.0, boost_energy - boost_drain * delta)
		_boost_cd = 1.2
	else:
		_boost_cd = maxf(0.0, _boost_cd - delta)
		if _boost_cd <= 0.0:
			boost_energy = minf(1.0, boost_energy + 0.12 * delta)

	var vmax := max_speed_ms * (1.3 if boosting else 1.0)
	var f := 0.0
	var brk := 0.0
	braking = false
	if throttle > 0.01:
		if forward_speed < -1.5:
			brk = brake_power * throttle
			braking = true
		else:
			var s := clampf(forward_speed / vmax, 0.0, 1.0)
			f = power * throttle * (1.0 - s * s * s)
			if boosting:
				f *= 1.8
	if brake_in > 0.01:
		if forward_speed > 1.5:
			brk = maxf(brk, brake_power * brake_in)
			braking = true
		elif throttle < 0.01:
			var sr := clampf(-forward_speed / 9.0, 0.0, 1.0)
			f = -power * 0.5 * brake_in * (1.0 - sr * sr)
	if throttle < 0.01 and brake_in < 0.01:
		brk = brake_power * 0.05

	for i in wheels.size():
		var w := wheels[i]
		var rear := i >= 2
		w.engine_force = -f # VehicleBody3D drives toward +Z for positive force; this bus faces -Z
		w.brake = brk + (brake_power * 1.4 if (hand and rear) else 0.0)
		w.wheel_friction_slip = grip * (0.5 if (hand and rear) else 1.0)

	# Steering (positive Godot steering = left turn)
	var limit := lerpf(0.45, 0.07, clampf(speed_kmh / 120.0, 0.0, 1.0)) * steer_sens * float(spec["steer"])
	var target := -steer_in * limit
	var rate := 3.2 if absf(target) > absf(steering) else 5.5
	steering = move_toward(steering, target, delta * rate)

	# Aero downforce keeps the tall van planted at speed
	var v := linear_velocity.length()
	apply_central_force(Vector3.DOWN * float(spec["downforce"]) * v * v)

	model.set_brake_light(braking or brake_in > 0.01)

	# Crash detection from sudden velocity change
	var dv := (linear_velocity - _prev_vel).length()
	if dv > 3.5 and _crash_cd <= 0.0 and not _pending_reset:
		_crash_cd = 0.5
		crashed.emit(dv)
		if audio_enabled:
			Audio.play("crash", clampf(dv - 12.0, -12.0, 0.0))
	_prev_vel = linear_velocity

	# Recovery: flipped or fell out of the world
	if global_transform.basis.y.y < 0.3:
		_flip_time += delta
		if _flip_time > 2.5:
			request_reset()
	else:
		_flip_time = 0.0
	_safe_timer += delta
	if _safe_timer > 0.5 and global_transform.basis.y.y > 0.8 and wheels[0].is_in_contact():
		_safe_timer = 0.0
		_safe_pos = global_position
	if global_position.y < -6.0:
		request_reset(_safe_pos + Vector3(0, 1.4, 0))

	if audio_enabled:
		Audio.set_engine(absf(forward_speed) / max_speed_ms, throttle)

func honk() -> void:
	if audio_enabled:
		Audio.play("horn", -4.0)
