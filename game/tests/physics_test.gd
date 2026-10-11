extends Node
## Headless vehicle calibration. Run:
## godot --headless --path . --fixed-fps 60 res://tests/PhysicsTest.tscn

var bus: Microbus
var f := 0
var brake_start_pos := Vector3.ZERO
var brake_start_speed := 0.0
var steer_start_yaw := 0.0
var rotated_flag := false

func _ready() -> void:
	var ground := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(6000, 2, 6000)
	cs.shape = bs
	cs.position.y = -1
	ground.add_child(cs)
	add_child(ground)
	bus = Microbus.new()
	bus.position = Vector3(0, 1.2, 0)
	bus.audio_enabled = false
	add_child(bus)

func _physics_process(_d: float) -> void:
	f += 1
	if f == 120:
		print("[settle] y=%.2f" % bus.global_position.y)
		Input.action_press("accelerate")
	if f > 120 and f <= 120 + 900 and f % 120 == 0:
		print("[accel] t=%.1fs speed=%.1f km/h pos_z=%.1f" % [(f - 120) / 60.0, bus.speed_kmh, bus.global_position.z])
	if f == 120 + 900:
		Input.action_release("accelerate")
		Input.action_press("brake")
		brake_start_pos = bus.global_position
		brake_start_speed = bus.speed_kmh
		print("[brake] start speed=%.1f km/h" % brake_start_speed)
	if f > 1020 and f <= 1020 + 600 and bus.speed_kmh < 1.0 and brake_start_speed > 0.0:
		print("[brake] stopped after %.1f m at t=%.2fs" % [bus.global_position.distance_to(brake_start_pos), (f - 1020) / 60.0])
		brake_start_speed = -1.0
	if f == 1020 + 600:
		Input.action_release("brake")
		Input.action_press("accelerate")
		print("[steer] re-accelerating")
	if f == 1020 + 600 + 240:
		Input.action_release("accelerate")
		steer_start_yaw = bus.global_rotation.y
		Input.action_press("steer_right")
		Input.action_press("accelerate", 0.4)
		print("[steer] begin right turn at %.1f km/h yaw=%.2f x=%.1f" % [bus.speed_kmh, steer_start_yaw, bus.global_position.x])
	if f == 1020 + 600 + 240 + 180:
		print("[steer] after 3s yaw=%.2f x=%.1f (right turn => x>0 expected, speed=%.1f)" % [bus.global_rotation.y, bus.global_position.x, bus.speed_kmh])
		Input.action_release("steer_right")
		Input.action_release("accelerate")
		# flip it and test recovery
		bus.global_transform = Transform3D(Basis(Vector3(0, 0, 1), PI), bus.global_position + Vector3(0, 3, 0))
		bus.linear_velocity = Vector3.ZERO
		bus.angular_velocity = Vector3.ZERO
	if f == 1020 + 600 + 240 + 180 + 120:
		print("[flip] up.y=%.2f (flipped before recovery)" % bus.global_transform.basis.y.y)
	if f == 1020 + 600 + 240 + 180 + 420:
		print("[flip] up.y=%.2f after 5s (should be ~1.0 = recovered)" % bus.global_transform.basis.y.y)
		get_tree().quit()

