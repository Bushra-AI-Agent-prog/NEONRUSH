class_name Traffic
extends Node3D
## Ambient traffic. Cars drive the road graph on the LEFT, slow for obstacles
## ahead (other cars and the player) and stop briefly when bumped.

class TrafficCar extends AnimatableBody3D:
	var from_id := 0
	var to_id := 0
	var target := Vector3.ZERO
	var speed := 0.0
	var cruise := 12.0
	var lane := City.LANE
	var yaw := 0.0
	var stun := 0.0
	var stuck := 0.0
	var length := 4.0

var city: City
var player: Microbus
var cars: Array[TrafficCar] = []
var rng := RandomNumberGenerator.new()

func setup(c: City, p: Microbus) -> void:
	city = c
	player = p
	rng.randomize()

func spawn(count: int) -> void:
	var tries := 0
	while cars.size() < count and tries < count * 20:
		tries += 1
		var i := rng.randi_range(0, City.N)
		var j := rng.randi_range(0, City.N)
		var id := City.node_id(i, j)
		var nb := city.neighbors(id)
		var to_id := int(nb[rng.randi() % nb.size()])
		var a := city.node_pos(id)
		var b := city.node_pos(to_id)
		var d := (b - a).normalized()
		var left := Vector3(d.z, 0, -d.x)
		var lane := City.LANE if rng.randf() < 0.6 else City.LANE * 1.9
		var pos := a + d * rng.randf_range(12.0, 50.0) + left * lane
		if player != null and pos.distance_to(player.global_position) < 45.0:
			continue
		var blocked := false
		for o in cars:
			if o.global_position.distance_to(pos) < 12.0:
				blocked = true
		if blocked:
			continue
		_make_car(id, to_id, pos, d, lane)

func _make_car(from_id: int, to_id: int, pos: Vector3, d: Vector3, lane: float) -> void:
	var car := TrafficCar.new()
	car.from_id = from_id
	car.to_id = to_id
	car.lane = lane
	car.cruise = rng.randf_range(9.0, 15.0)
	car.speed = car.cruise * 0.6
	car.yaw = atan2(-d.x, -d.z)
	car.collision_layer = 2
	car.collision_mask = 0
	car.sync_to_physics = true
	_build_visual(car)
	add_child(car)
	car.global_transform = Transform3D(Basis(Vector3.UP, car.yaw), Vector3(pos.x, 0.0, pos.z))
	car.target = _lane_target(to_id, d, lane)
	cars.append(car)

func _lane_target(node: int, d: Vector3, lane: float) -> Vector3:
	var left := Vector3(d.z, 0, -d.x)
	return city.node_pos(node) + left * lane

func _build_visual(car: TrafficCar) -> void:
	var kind := rng.randi() % 7 # 0-4 roster car, 5 van, 6 cargo truck
	var col := Color.from_hsv(rng.randf(), rng.randf_range(0.0, 0.85), rng.randf_range(0.25, 0.9))
	if kind < 5:
		var idx := rng.randi_range(1, Cars.LIST.size() - 1)
		var sp := Cars.spec(idx)
		var m: CarModel = Cars.make_model(idx, 0)
		m.paint(col)
		car.add_child(m)
		car.length = float(sp["len"])
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = sp["box"]
		cs.shape = sh
		cs.position = Vector3(0, float(sp["box_y"]), 0)
		car.add_child(cs)
		for sx in [-1.0, 1.0]:
			for z in [sp["wzf"], sp["wzr"]]:
				var w := Node3D.new()
				w.position = Vector3(float(sx) * CarBuilder.wheel_x(sp, float(z)), float(sp["wr"]), float(z))
				car.add_child(w)
				CarBuilder.wheel_visual(w, sp, 0)
		return
	var body := MeshKit.mat(col, 0.0, 0.5, 0.35)
	var glass := MeshKit.mat(Color(0.015, 0.03, 0.045), 0.0, 0.85, 0.05)
	var neon := MeshKit.mat(Color.from_hsv(rng.randf(), 0.9, 1.0), 2.0)
	var head := MeshKit.mat(Color(1, 0.95, 0.8), 2.5)
	var tail := MeshKit.mat(Color(1, 0.05, 0.05), 2.0)
	var len := 4.6
	var hgt := 2.1
	if kind == 5:
		MeshKit.box(car, Vector3(1.85, 0.7, len), Vector3(0, 0.7, 0), body)
		MeshKit.box(car, Vector3(1.8, 0.9, len - 1.0), Vector3(0, 1.45, 0.4), body)
		MeshKit.box(car, Vector3(1.7, 0.45, 0.06), Vector3(0, 1.55, -len / 2.0 + 0.9), glass, Vector3(-18, 0, 0))
	else:
		len = 6.4
		hgt = 2.9
		MeshKit.box(car, Vector3(2.0, 0.6, len), Vector3(0, 0.6, 0), MeshKit.mat(Color(0.12, 0.13, 0.17), 0.0, 0.5, 0.5))
		MeshKit.box(car, Vector3(1.9, 1.3, 1.6), Vector3(0, 1.45, -len / 2.0 + 1.0), body)
		MeshKit.box(car, Vector3(1.75, 0.5, 0.06), Vector3(0, 1.6, -len / 2.0 + 0.19), glass)
		MeshKit.box(car, Vector3(2.0, 1.9, len - 2.2), Vector3(0, 1.75, 1.1), MeshKit.mat(Color.from_hsv(rng.randf(), 0.2, 0.8), 0.0, 0.3, 0.6))
		MeshKit.box(car, Vector3(2.04, 0.1, len - 2.2), Vector3(0, 1.0, 1.1), neon)
	car.length = len
	for sx in [-1.0, 1.0]:
		MeshKit.box(car, Vector3(0.35, 0.12, 0.05), Vector3(sx * 0.65, 0.7, -len / 2.0), head)
		MeshKit.box(car, Vector3(0.4, 0.12, 0.05), Vector3(sx * 0.65, 0.7, len / 2.0), tail)
		for sz in [-1.0, 1.0]:
			MeshKit.cyl(car, 0.36, 0.26, Vector3(sx * 0.92, 0.36, sz * len * 0.32), MeshKit.mat(Color(0.03, 0.03, 0.04), 0.0, 0.0, 0.9), Vector3(0, 0, 90), 10)
	var cs2 := CollisionShape3D.new()
	var sh2 := BoxShape3D.new()
	sh2.size = Vector3(1.9, hgt - 0.3, len)
	cs2.shape = sh2
	cs2.position = Vector3(0, 0.3 + (hgt - 0.3) / 2.0, 0)
	car.add_child(cs2)

func _pick_next(car: TrafficCar) -> void:
	var nb := city.neighbors(car.to_id)
	var options: Array[int] = []
	for n in nb:
		if int(n) != car.from_id:
			options.append(int(n))
	if options.is_empty():
		options.append(car.from_id)
	var nxt := options[rng.randi() % options.size()]
	var d := (city.node_pos(nxt) - city.node_pos(car.to_id)).normalized()
	car.from_id = car.to_id
	car.to_id = nxt
	car.target = _lane_target(nxt, d, car.lane)

func _physics_process(delta: float) -> void:
	if city == null:
		return
	var ppos := Vector3.ZERO
	var has_player := player != null and is_instance_valid(player)
	if has_player:
		ppos = player.global_position
	for car in cars:
		var pos := car.global_position
		var to_t := car.target - pos
		to_t.y = 0.0
		if to_t.length() < 7.5:
			_pick_next(car)
			to_t = car.target - pos
			to_t.y = 0.0
		var fwd := Vector3(-sin(car.yaw), 0.0, -cos(car.yaw))
		var right := Vector3(-fwd.z, 0.0, fwd.x)
		var want := car.cruise
		# Look ahead for anything in our way
		var look := 6.0 + car.speed * 0.6
		for o in cars:
			if o == car:
				continue
			want = minf(want, _limit_for(pos, fwd, right, o.global_position, look, car.cruise))
		if has_player:
			want = minf(want, _limit_for(pos, fwd, right, ppos, look, car.cruise))
			var rel := ppos - pos
			rel.y = 0.0
			if rel.length() < car.length * 0.5 + 2.6 and player.speed_kmh > 6.0 and car.stun <= 0.0:
				car.stun = 1.6
		if car.stun > 0.0:
			car.stun -= delta
			want = 0.0
		var acc := 20.0 if want < car.speed else 8.0
		car.speed = move_toward(car.speed, want, acc * delta)
		# stuck handling: if waiting too long, creep to unblock
		if car.speed < 0.2 and car.stun <= 0.0:
			car.stuck += delta
			if car.stuck > 6.0:
				car.stun = 0.0
				car.speed = 3.0
				car.stuck = 0.0
		else:
			car.stuck = 0.0
		var want_yaw := atan2(-to_t.x, -to_t.z)
		car.yaw = rotate_toward(car.yaw, want_yaw, delta * 2.8)
		var nf := Vector3(-sin(car.yaw), 0.0, -cos(car.yaw))
		var np := pos + nf * car.speed * delta
		np.y = 0.0
		car.global_transform = Transform3D(Basis(Vector3.UP, car.yaw), np)

## Speed cap imposed by an obstacle at `opos` (1 = no limit).
func _limit_for(pos: Vector3, fwd: Vector3, right: Vector3, opos: Vector3, look: float, cruise: float) -> float:
	var rel := opos - pos
	rel.y = 0.0
	var ahead := rel.dot(fwd)
	if ahead <= 0.5 or ahead > look + 4.0:
		return cruise
	var lat := absf(rel.dot(right))
	var band := 2.7 + (1.0 if ahead < 8.0 else 0.0)
	if lat > band:
		return cruise
	return cruise * clampf((ahead - 5.5) / maxf(look - 5.5, 1.0), 0.0, 1.0)
