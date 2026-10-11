class_name CameraRig
extends Node3D
## Chase / hood / far camera with speed FOV and crash shake.

var target: Microbus
var cam: Camera3D
var mode := 0
var _yaw := 0.0
var _shake := 0.0
var _pos := Vector3.ZERO
var _initialized := false

func _ready() -> void:
	cam = Camera3D.new()
	cam.fov = 70.0
	cam.near = 0.15
	cam.far = float(Game.quality()["far"])
	add_child(cam)
	cam.make_current()
	mode = int(Save.setting("camera"))
	Game.quality_changed.connect(func(): cam.far = float(Game.quality()["far"]))

func cycle() -> String:
	mode = (mode + 1) % 3
	Save.set_setting("camera", mode)
	return ["Chase", "Hood", "Far"][mode]

func shake(strength: float) -> void:
	_shake = clampf(_shake + strength * 0.03, 0.0, 0.6)

func snap() -> void:
	_initialized = false

func _process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	var tb := target.global_transform
	var fwd := -tb.basis.z
	fwd.y = 0.0
	if fwd.length() < 0.01:
		fwd = Vector3.FORWARD
	fwd = fwd.normalized()
	var want_yaw := atan2(-fwd.x, -fwd.z)
	if not _initialized:
		_yaw = want_yaw
		_initialized = true
		_pos = tb.origin
	_yaw = lerp_angle(_yaw, want_yaw, 1.0 - exp(-delta * 4.5))

	var speed := target.speed_kmh
	var speed_t := clampf(speed / 130.0, 0.0, 1.0)
	var fov_goal := lerpf(68.0, 84.0, speed_t) + (8.0 if target.boosting else 0.0)
	cam.fov = lerpf(cam.fov, fov_goal, 1.0 - exp(-delta * 4.0))

	var shake_off := Vector3.ZERO
	if _shake > 0.001:
		shake_off = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * _shake
		_shake = maxf(0.0, _shake - delta * 1.6)

	if mode == 1:
		# Hood / driver view: rigidly attached.
		var hy := 1.3
		var hz := -0.7
		if target.car_idx != Cars.BUS:
			var sp: Dictionary = target.spec
			hy = float(sp["roof"]) * 0.9 - float(sp["oh"])
			hz = -float(sp["len"]) * 0.5 + (float(sp["c0"]) + 0.3 * (float(sp["c1"]) - float(sp["c0"]))) * float(sp["len"])
		cam.global_transform = tb * Transform3D(Basis(), Vector3(0, hy, hz))
		cam.global_position += shake_off * 0.3
		return

	var cs: float = float(target.spec.get("cam", 1.0))
	var dist := (8.2 if mode == 0 else 15.0) * cs
	var height := (3.3 if mode == 0 else 8.5) * lerpf(1.0, cs, 0.7)
	var yaw_basis := Basis(Vector3.UP, _yaw)
	var goal := tb.origin + yaw_basis * Vector3(0, height, dist + speed_t * 1.5)
	_pos = _pos.lerp(goal, 1.0 - exp(-delta * 9.0))
	var look_at_pt := tb.origin + Vector3(0, 1.4, 0) + fwd * (4.0 + speed_t * 5.0)
	cam.global_position = _pos + shake_off
	cam.look_at(look_at_pt, Vector3.UP)
