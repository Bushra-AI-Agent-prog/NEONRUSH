extends Node
## Headless per-car calibration: ride height, 0-100, top speed, braking, steering, flip recovery.
## godot --headless --path . --fixed-fps 60 res://tests/CarsTest.tscn
var idx := 0
var f := 0
var bus: Microbus
var t100 := -1.0
var fails := 0
var top := 0.0
var brk_pos := Vector3.ZERO

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var g := StaticBody3D.new(); var cs := CollisionShape3D.new(); var bs := BoxShape3D.new()
	bs.size = Vector3(8000, 2, 8000); cs.shape = bs; cs.position.y = -1; g.add_child(cs); add_child(g)
	Save.data = Save._default()
	_spawn()

func _spawn() -> void:
	if bus: bus.queue_free()
	Input.action_release("accelerate"); Input.action_release("brake"); Input.action_release("steer_right")
	bus = Microbus.new(); bus.car_idx = idx; bus.audio_enabled = false
	bus.position = Vector3(0, 1.2, 0)
	add_child(bus)
	f = 0; t100 = -1.0; top = 0.0

func _physics_process(_d: float) -> void:
	f += 1
	var name: String = Cars.spec(idx)["name"]
	if f == 90 or f == 150:
		print("[%s] t=%d body y=%.3f vel_y=%.2f" % [name, f, bus.global_position.y, bus.linear_velocity.y])
	if f == 240:
		var wy := 0.0
		for w in bus.wheels: wy += w.global_position.y
		wy /= bus.wheels.size()
		print("[%s] SUGGESTED oh=%.3f" % [name, bus.global_position.y + float(bus.spec["wr"]) - wy])
		print("[%s] settled body y=%.3f (spec oh=%.2f), wheel centre y=%.3f (wr=%.2f)" % [name, bus.global_position.y, float(bus.spec["oh"]), wy, float(bus.spec["wr"])])
		Input.action_press("accelerate")
	if f > 240 and f < 240 + 1200:
		top = maxf(top, bus.speed_kmh)
		if t100 < 0.0 and bus.speed_kmh >= 100.0: t100 = (f - 240) / 60.0
		if bus.global_transform.basis.y.y < 0.5:
			print("[FAIL] %s flipped while accelerating" % name); fails += 1
	if f == 240 + 1200:
		print("[%s] 0-100 km/h: %s s, top speed %.0f km/h (target %.0f)" % [name, ("%.1f" % t100) if t100 > 0 else "n/a", top, float(bus.spec["top"])])
		Input.action_release("accelerate"); Input.action_press("brake"); brk_pos = bus.global_position
	if f == 240 + 1200 + 420:
		print("[%s] braking distance from top: %.0f m, now %.1f km/h" % [name, bus.global_position.distance_to(brk_pos), bus.speed_kmh])
		Input.action_release("brake")
		bus.global_transform = Transform3D(Basis(Vector3(0, 0, 1), PI), bus.global_position + Vector3(0, 3, 0))
		bus.linear_velocity = Vector3.ZERO; bus.angular_velocity = Vector3.ZERO
	if f == 240 + 1200 + 420 + 420:
		var up := bus.global_transform.basis.y.y
		print("[%s] flip recovery up.y=%.2f" % [name, up])
		if up < 0.8: fails += 1; print("[FAIL] %s did not recover" % name)
		idx += 1
		if idx >= Cars.LIST.size():
			print("[result] %d failure(s)" % fails)
			get_tree().quit(1 if fails > 0 else 0)
		else:
			_spawn()
