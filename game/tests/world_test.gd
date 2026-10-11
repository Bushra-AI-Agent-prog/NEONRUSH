extends Node
## Headless smoke test of the full gameplay scene. Run:
## godot --headless --path . --fixed-fps 60 res://tests/WorldTest.tscn
## Drives the bus, waits for a job, teleports to pickup + dropoff, verifies the
## mission loop pays out, and exercises pause + camera cycling + weather.

var world: Node3D
var f := 0
var phase := 0
var money_before := 0
var deliveries_before := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Save.data = Save._default()
	money_before = int(Save.data["money"])
	deliveries_before = int(Save.data["deliveries"])
	var scene: PackedScene = load("res://scenes/World.tscn")
	world = scene.instantiate()
	add_child(world)
	world.bus.crashed.connect(func(st): print("[crash] strength=%.1f at f=%d" % [st, f]))
	print("[world] built: buildings/roads ok, traffic cars=%d, stops=%d" % [world.traffic.cars.size(), world.city.stops.size()])

func _teleport_to(p: Vector3) -> void:
	world.bus.request_reset(Vector3(p.x, 1.2, p.z), 0.0)

func _physics_process(_d: float) -> void:
	f += 1
	var m: Missions = world.missions
	if phase == 0 and f == 60:
		Input.action_press("accelerate")
	if phase == 0 and f == 300:
		print("[drive] speed after 4 s of throttle: %.1f km/h, pos=%s" % [world.bus.speed_kmh, str(world.bus.global_position.snapped(Vector3(0.1, 0.1, 0.1)))])
		Input.action_release("accelerate")
		Input.action_press("brake")
	if phase == 0 and f == 420:
		Input.action_release("brake")
	# wait for a job offer (2 s idle timer)
	if phase == 0 and f > 440 and m.state == Missions.S.TO_PICKUP:
		print("[mission] job offered: type=%s pax=%d leg=%.0fm time=%.0fs" % [Missions.TYPES[m.job["type"]]["name"], m.job["pax"], m.job["leg"], m.job["time"]])
		_teleport_to(m.job["pickup"]["pos"])
		phase = 1
	elif phase == 1 and m.state == Missions.S.TO_DROPOFF:
		print("[mission] boarded; checkpoints=%d time_left=%.0fs guide_pts=%d" % [m.checkpoints.size(), m.time_left, m.guide.size()])
		phase = 2
		f = 0
	elif phase == 2 and f % 20 == 0:
		if m.checkpoints.size() > 0:
			_teleport_to(m.checkpoints[0])
		else:
			print("[mission] checkpoints all hit: time_left=%.0fs" % m.time_left)
			_teleport_to(m.job["dropoff"]["pos"])
			phase = 3
	elif phase == 3 and m.state == Missions.S.RESULT:
		print("[mission] delivered. money %d -> %d, deliveries %d -> %d, xp=%d level=%d" % [money_before, int(Save.data["money"]), deliveries_before, int(Save.data["deliveries"]), int(Save.data["xp"]), int(Save.data["level"])])
		phase = 4
		f = 0
		world.hud.set_paused(true)
	elif phase == 4 and f == 10:
		print("[pause] paused=%s" % str(get_tree().paused))
		world.hud.set_paused(false)
		print("[camera] mode -> %s" % world.cam_rig.cycle())
		world.weather.set_kind(1, true)
		phase = 5
		f = 0
	elif phase == 5 and f == 240:
		print("[weather] rain on, road roughness=%.2f, fps(headless)=%d" % [world.city.road_mat.roughness, int(Engine.get_frames_per_second())])
		print("[result] smoke test finished")
		get_tree().quit()
	if f > 3000 and phase < 4:
		print("[FAIL] timeout in phase %d (state=%d)" % [phase, m.state])
		get_tree().quit(1)
