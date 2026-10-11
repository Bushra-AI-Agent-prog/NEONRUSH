class_name Missions
extends Node3D
## Passenger jobs: drive to the pick-up ring, board, deliver within the time
## limit through optional checkpoints, earn fare + XP. Jobs chain automatically.

signal toast(text: String, color: Color)
signal completed(fare: int, xp: int, levels: int)
signal failed(reason: String)
signal job_changed

enum S { IDLE, TO_PICKUP, BOARDING, TO_DROPOFF, UNLOADING, RESULT }

const TYPES: Array = [
	{"name": "Standard Fare", "mult": 1.0, "speed": 7.5, "buffer": 32.0, "strict": 1.0, "color": Color(0.3, 1.0, 0.6)},
	{"name": "Express Run", "mult": 1.7, "speed": 10.5, "buffer": 18.0, "strict": 1.0, "color": Color(1.0, 0.75, 0.1)},
	{"name": "VIP Smooth Ride", "mult": 1.5, "speed": 6.8, "buffer": 40.0, "strict": 1.8, "color": Color(0.75, 0.5, 1.0)},
]

var city: City
var bus: Microbus
var state: int = S.IDLE
var job: Dictionary = {}
var time_left := 0.0
var comfort := 100.0
var progress := 0.0
var route_dist := 0.0
var guide := PackedVector3Array()
var checkpoints: Array[Vector3] = []
var rng := RandomNumberGenerator.new()

var _timer := 2.0
var _guide_t := 0.0
var _markers: Array[Node3D] = []
var _pulse_t := 0.0
var _pickup_marker: Node3D
var _drop_marker: Node3D
var _cp_markers: Array[Node3D] = []

func setup(c: City, b: Microbus) -> void:
	city = c
	bus = b
	rng.randomize()

# ------------------------------------------------------------------ queries for HUD / minimap

func active() -> bool:
	return state != S.IDLE and state != S.RESULT

func target_pos() -> Vector3:
	match state:
		S.TO_PICKUP, S.BOARDING:
			return job["pickup"]["pos"]
		S.TO_DROPOFF, S.UNLOADING:
			return job["dropoff"]["pos"]
	return Vector3.INF

func next_waypoint() -> Vector3:
	if guide.is_empty():
		return Vector3.INF
	var flat := Vector3(bus.global_position.x, 0, bus.global_position.z)
	for p in guide:
		if Vector2(p.x - flat.x, p.z - flat.z).length() > 14.0:
			return p
	return guide[guide.size() - 1]

## Fare the player would earn if the job ended right now.
func estimate_fare() -> int:
	if job.is_empty():
		return 0
	var ty: Dictionary = TYPES[job["type"]]
	var base: float = 40.0 + float(job["leg"]) * 0.35 + float(job["pax"]) * 12.0
	var time_bonus: float = maxf(time_left, 0.0) * (2.4 if int(job["type"]) == 1 else 1.2)
	return int((base * float(ty["mult"]) + time_bonus) * clampf(comfort / 100.0, 0.4, 1.0))

func status_text() -> String:
	match state:
		S.IDLE:
			return "Looking for a passenger..."
		S.TO_PICKUP:
			return "Pick up %d passenger%s" % [job["pax"], "" if job["pax"] == 1 else "s"]
		S.BOARDING:
			return "Boarding... hold still"
		S.TO_DROPOFF:
			return "Drop off passengers"
		S.UNLOADING:
			return "Unloading..."
		S.RESULT:
			return "Job finished"
	return ""

# ------------------------------------------------------------------ job generation

func _pick_stop(origin: Vector3, dmin: float, dmax: float, avoid: Vector3) -> Dictionary:
	var best: Dictionary = {}
	for k in 300:
		var s: Dictionary = city.stops[rng.randi() % city.stops.size()]
		var p: Vector3 = s["pos"]
		var d := Vector2(p.x - origin.x, p.z - origin.z).length()
		best = s
		if d >= dmin and d <= dmax:
			if avoid == Vector3.INF or Vector2(p.x - avoid.x, p.z - avoid.z).length() > 40.0:
				return s
	return best

func _new_job() -> void:
	_clear_markers()
	var lvl := int(Save.data["level"])
	var pool := [0, 0, 0]
	if lvl >= 2:
		pool.append_array([1, 1])
	if lvl >= 3:
		pool.append(2)
	var t: int = pool[rng.randi() % pool.size()]
	var bpos := bus.global_position
	var pick := _pick_stop(bpos, 70.0, 260.0, Vector3.INF)
	var drop := _pick_stop(pick["pos"], 220.0, 560.0, bpos)
	var leg := city.path_length(city.guide_path(pick["pos"], drop), pick["pos"])
	var ty: Dictionary = TYPES[t]
	job = {
		"type": t,
		"pax": rng.randi_range(1, mini(6, 2 + lvl)),
		"pickup": pick,
		"dropoff": drop,
		"leg": leg,
		"time": leg / float(ty["speed"]) + float(ty["buffer"]),
	}
	comfort = 100.0
	progress = 0.0
	state = S.TO_PICKUP
	_pickup_marker = _make_marker(Color(0.2, 1.0, 0.6), 5.2)
	_pickup_marker.global_position = pick["pos"]
	_guide_t = 0.0
	toast.emit("New job: %s" % ty["name"], ty["color"])
	Audio.play("pickup", -6.0)
	job_changed.emit()

func skip_job() -> void:
	if state == S.TO_PICKUP or state == S.BOARDING or state == S.IDLE:
		_clear_markers()
		state = S.IDLE
		_timer = 0.3
		guide = PackedVector3Array()
		job_changed.emit()
	elif state == S.TO_DROPOFF or state == S.UNLOADING:
		_fail("Job cancelled")

# ------------------------------------------------------------------ markers

func _make_marker(col: Color, radius: float) -> Node3D:
	var n := Node3D.new()
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = col
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = radius - 0.45
	tm.outer_radius = radius
	tm.rings = 24
	tm.ring_segments = 8
	ring.mesh = tm
	ring.material_override = ring_mat
	ring.position.y = 0.4
	n.add_child(ring)
	var beam_mat := StandardMaterial3D.new()
	beam_mat.albedo_color = Color(col.r, col.g, col.b, 0.28)
	beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var beam := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius * 0.85
	cm.bottom_radius = radius * 0.85
	cm.height = 70.0
	cm.radial_segments = 16
	cm.rings = 1
	beam.mesh = cm
	beam.material_override = beam_mat
	beam.position.y = 35.0
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(beam)
	add_child(n)
	_markers.append(n)
	return n

func _clear_markers() -> void:
	for m in _markers:
		if is_instance_valid(m):
			m.queue_free()
	_markers.clear()
	_cp_markers.clear()
	checkpoints.clear()
	_pickup_marker = null
	_drop_marker = null

func _make_checkpoints() -> void:
	var path := city.guide_path(job["pickup"]["pos"], job["dropoff"])
	var nodes: Array[Vector3] = []
	for q in range(0, path.size() - 1):
		nodes.append(path[q])
	if nodes.size() < 4:
		return
	for idx in [nodes.size() / 3, (nodes.size() * 2) / 3]:
		var p: Vector3 = nodes[idx]
		checkpoints.append(p)
		var m := _make_marker(Color(1.0, 0.9, 0.2), 4.0)
		m.global_position = p
		_cp_markers.append(m)

# ------------------------------------------------------------------ main loop

func _near(p: Vector3, r: float) -> bool:
	var b := bus.global_position
	return Vector2(p.x - b.x, p.z - b.z).length() < r

func _update_guide() -> void:
	var tp := target_pos()
	if tp == Vector3.INF:
		return
	var stop: Dictionary = job["pickup"] if (state == S.TO_PICKUP or state == S.BOARDING) else job["dropoff"]
	var flat := Vector3(bus.global_position.x, 0, bus.global_position.z)
	guide = city.guide_path(flat, stop)
	route_dist = city.path_length(guide, flat)

func _process(delta: float) -> void:
	if bus == null or city == null:
		return
	_pulse_t += delta
	var s := 1.0 + 0.07 * sin(_pulse_t * 4.0)
	for m in _markers:
		if is_instance_valid(m):
			m.scale = Vector3(s, 1.0, s)
			m.rotation.y += delta * 0.8

	_guide_t -= delta
	if _guide_t <= 0.0 and active():
		_guide_t = 0.35
		_update_guide()

	match state:
		S.IDLE:
			_timer -= delta
			if _timer <= 0.0:
				_new_job()
		S.TO_PICKUP:
			if _near(job["pickup"]["pos"], 9.0) and bus.speed_kmh < 20.0:
				state = S.BOARDING
				progress = 0.0
		S.BOARDING:
			if _near(job["pickup"]["pos"], 12.0) and bus.speed_kmh < 18.0:
				progress += delta / 1.8
			else:
				progress -= delta * 0.8
				if progress <= 0.0:
					state = S.TO_PICKUP
					progress = 0.0
			if progress >= 1.0:
				_board()
		S.TO_DROPOFF:
			time_left -= delta
			for i in range(checkpoints.size() - 1, -1, -1):
				if _near(checkpoints[i], 9.5):
					_hit_checkpoint(i)
			if _near(job["dropoff"]["pos"], 9.0) and bus.speed_kmh < 20.0:
				state = S.UNLOADING
				progress = 0.0
			elif time_left <= 0.0:
				_fail("Time's up!")
		S.UNLOADING:
			time_left -= delta
			if _near(job["dropoff"]["pos"], 12.0) and bus.speed_kmh < 18.0:
				progress += delta / 1.5
			else:
				progress -= delta * 0.8
				if progress <= 0.0:
					state = S.TO_DROPOFF
					progress = 0.0
			if progress >= 1.0:
				_deliver()
			elif time_left <= 0.0:
				_fail("Time's up!")
		S.RESULT:
			_timer -= delta
			if _timer <= 0.0:
				state = S.IDLE
				_timer = 1.0
				job_changed.emit()

func _board() -> void:
	if _pickup_marker != null:
		_markers.erase(_pickup_marker)
		_pickup_marker.queue_free()
		_pickup_marker = null
	state = S.TO_DROPOFF
	progress = 0.0
	time_left = job["time"]
	_drop_marker = _make_marker(Color(1.0, 0.25, 0.7), 5.2)
	_drop_marker.global_position = job["dropoff"]["pos"]
	_make_checkpoints()
	Audio.play("pickup")
	toast.emit("Passengers aboard! Go go go!", Color(1.0, 0.9, 0.3))
	_guide_t = 0.0
	job_changed.emit()

func _hit_checkpoint(i: int) -> void:
	checkpoints.remove_at(i)
	var m := _cp_markers[i]
	_cp_markers.remove_at(i)
	_markers.erase(m)
	m.queue_free()
	time_left += 8.0
	Save.add_money(10)
	Audio.play("coin")
	toast.emit("Checkpoint! +8s  +$10", Color(1.0, 0.9, 0.2))

func on_crash(strength: float) -> void:
	if state != S.TO_DROPOFF and state != S.UNLOADING:
		return
	var strict: float = TYPES[job["type"]]["strict"]
	var loss := clampf(strength * 1.4, 3.0, 22.0) * strict
	comfort = maxf(0.0, comfort - loss)
	toast.emit("Bump! Comfort -%d%%" % int(loss), Color(1.0, 0.4, 0.3))
	if job["type"] == 2 and comfort < 35.0:
		_fail("The VIP got out. Too rough!")

func _deliver() -> void:
	var ty: Dictionary = TYPES[job["type"]]
	var fare := estimate_fare()
	var xp := int(25.0 + job["leg"] / 12.0 * float(ty["mult"]))
	Save.add_money(fare)
	var levels := Save.add_xp(xp)
	Save.data["deliveries"] = int(Save.data["deliveries"]) + 1
	Save.data["best_fare"] = maxi(int(Save.data["best_fare"]), fare)
	Save.save_game()
	_clear_markers()
	guide = PackedVector3Array()
	state = S.RESULT
	_timer = 3.5
	Audio.play("coin")
	if levels > 0:
		Audio.play("levelup")
	completed.emit(fare, xp, levels)
	job_changed.emit()

func _fail(reason: String) -> void:
	_clear_markers()
	guide = PackedVector3Array()
	state = S.RESULT
	_timer = 3.0
	Audio.play("fail")
	failed.emit(reason)
	job_changed.emit()
