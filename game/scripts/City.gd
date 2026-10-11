class_name City
extends Node3D
## Procedural futuristic city on a road grid (left-hand traffic, like Bangladesh).
## Everything is generated from code; heavy repeated geometry uses MultiMesh.

const N := 8                     # city blocks per side
const BLOCK := 64.0
const ROAD := 18.0
const P := BLOCK + ROAD          # road-centre to road-centre spacing
const LANE := 3.4                # traffic lane offset from road centre

const BUILDING_SHADER := """
shader_type spatial;
uniform float night : hint_range(0.0, 1.0) = 0.6;
varying vec3 wpos;
varying vec3 wnorm;
varying vec4 icol;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize(mat3(MODEL_MATRIX) * NORMAL);
	icol = COLOR;
}
void fragment() {
	if (abs(wnorm.y) > 0.5) {
		float n = vnoise(wpos.xz * 0.4) * 0.6 + vnoise(wpos.xz * 2.3) * 0.3;
		ALBEDO = icol.rgb * 0.45 * (0.75 + 0.5 * n);
		ROUGHNESS = 0.95;
	} else {
		float along = abs(wnorm.x) > 0.5 ? wpos.z : wpos.x;
		vec2 g = vec2(along / 3.0, wpos.y / 3.6);
		vec2 cell = floor(g);
		vec2 f = fract(g);
		float win = step(0.16, f.x) * step(f.x, 0.84) * step(0.2, f.y) * step(f.y, 0.8);
		float lit = step(0.5, hash(cell + floor(icol.r * 97.0)));
		float n = vnoise(vec2(along * 0.5, wpos.y * 0.12)) * 0.5 + vnoise(vec2(along * 2.2, wpos.y * 0.5)) * 0.3;
		vec3 wall = icol.rgb * mix(0.5, 0.85, n);
		wall *= mix(0.6, 1.0, smoothstep(0.0, 22.0, wpos.y));
		float panel = step(0.06, fract(wpos.y / 3.6)) ;
		wall *= mix(0.78, 1.0, panel);
		vec3 glass = vec3(0.035, 0.06, 0.09);
		ALBEDO = mix(wall, glass, win);
		ROUGHNESS = mix(0.85, 0.05, win);
		METALLIC = mix(0.0, 0.9, win);
		vec3 wcol = mix(vec3(1.0, 0.8, 0.5), vec3(0.65, 0.85, 1.0), step(0.5, hash(cell * 1.7 + 3.0)));
		EMISSION = wcol * win * lit * night * 1.5;
		float shop = step(wpos.y, 3.2) * step(0.15, wpos.y);
		EMISSION += icol.rgb * shop * 0.5 * night;
	}
}
"""

const NEON_SHADER := """
shader_type spatial;
render_mode unshaded;
uniform float intensity = 1.0;
varying vec4 c;
void vertex() { c = COLOR; }
void fragment() { ALBEDO = c.rgb * intensity; }
"""

var rng := RandomNumberGenerator.new()
var astar := AStar2D.new()
var road_mat: StandardMaterial3D
var stops: Array[Dictionary] = []
var half_extent := 0.0
var _building_mat: ShaderMaterial
var _neon_mat: ShaderMaterial
var _mark_mat: StandardMaterial3D
var _foliage_mat: StandardMaterial3D
var _building_mmi: MultiMeshInstance3D
var _static: StaticBody3D

static func c(k: int) -> float:
	return (k - N / 2.0) * P

static func node_id(i: int, j: int) -> int:
	return i * (N + 1) + j

func build(seed_value := 20260) -> void:
	rng.seed = seed_value
	half_extent = (N * P + ROAD) / 2.0
	var bs := Shader.new()
	bs.code = BUILDING_SHADER
	_building_mat = ShaderMaterial.new()
	_building_mat.shader = bs
	var ns := Shader.new()
	ns.code = NEON_SHADER
	_neon_mat = ShaderMaterial.new()
	_neon_mat.shader = ns
	_static = StaticBody3D.new()
	_static.collision_layer = 1
	_static.collision_mask = 0
	add_child(_static)

	_build_ground()
	_build_roads()
	_build_blocks()
	_build_lamps()
	_build_boundary()
	_build_skyline()
	_build_graph()

# ------------------------------------------------------------------ helpers

func _mm(mesh: Mesh, mat: Material, xforms: Array[Transform3D], colors: Array[Color] = []) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = colors.size() > 0
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
		if mm.use_colors:
			mm.set_instance_color(i, colors[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	return mmi

func _xf(pos: Vector3, yaw: float, scl: Vector3) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(scl), pos)

func _box_mesh(size := Vector3.ONE) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m

func _add_shape(size: Vector3, pos: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	cs.position = pos
	_static.add_child(cs)

## Concrete, brick, steel and blue-glass tones instead of saturated neon colours.
func _facade_color() -> Color:
	var r := rng.randf()
	if r < 0.3:
		return Color.from_hsv(rng.randf_range(0.04, 0.09), rng.randf_range(0.25, 0.45), rng.randf_range(0.5, 0.75))  # brick
	if r < 0.65:
		return Color.from_hsv(rng.randf_range(0.08, 0.14), rng.randf_range(0.03, 0.12), rng.randf_range(0.6, 0.9))  # concrete
	return Color.from_hsv(rng.randf_range(0.54, 0.62), rng.randf_range(0.12, 0.35), rng.randf_range(0.45, 0.8))  # glass-steel

func _neon_palette() -> Color:
	var cols := [Color(0.0, 0.9, 1.0), Color(1.0, 0.1, 0.65), Color(1.0, 0.85, 0.1), Color(0.5, 1.0, 0.2), Color(1.0, 0.45, 0.1), Color(0.6, 0.35, 1.0)]
	return cols[rng.randi() % cols.size()]

# ------------------------------------------------------------------ ground & roads

func _build_ground() -> void:
	var s := half_extent * 2.0
	_add_shape(Vector3(s + 60.0, 2.0, s + 60.0), Vector3(0, -1.0, 0))
	var mi := MeshKit.box(self, Vector3(s + 2400.0, 0.2, s + 2400.0), Vector3(0, -0.12, 0), MeshKit.mat(Color(0.015, 0.02, 0.035), 0.0, 0.0, 0.95))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _seg_pos(axis: int, k: int, along: float, off: float, y: float) -> Vector3:
	return Vector3(along, y, c(k) + off) if axis == 0 else Vector3(c(k) + off, y, along)

func _make_road_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = 0.05
	n.fractal_octaves = 4
	var tex := NoiseTexture2D.new()
	tex.noise = n
	tex.width = 512
	tex.height = 512
	tex.seamless = true
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(0.04, 0.042, 0.047), Color(0.15, 0.15, 0.16)])
	tex.color_ramp = g
	var n2 := FastNoiseLite.new()
	n2.noise_type = FastNoiseLite.TYPE_CELLULAR
	n2.frequency = 0.22
	n2.fractal_octaves = 2
	var nt := NoiseTexture2D.new()
	nt.noise = n2
	nt.width = 512
	nt.height = 512
	nt.seamless = true
	nt.as_normal_map = true
	nt.bump_strength = 5.0
	m.albedo_texture = tex
	m.normal_enabled = true
	m.normal_texture = nt
	m.normal_scale = 0.7
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(0.1, 0.1, 0.1)
	m.roughness = 0.9
	return m

func _build_roads() -> void:
	road_mat = _make_road_mat()
	_mark_mat = StandardMaterial3D.new()
	_mark_mat.vertex_color_use_as_albedo = true
	_mark_mat.roughness = 0.55
	_mark_mat.metallic_specular = 0.6
	_foliage_mat = StandardMaterial3D.new()
	_foliage_mat.vertex_color_use_as_albedo = true
	_foliage_mat.roughness = 0.9
	var s := N * P + ROAD
	for k in N + 1:
		MeshKit.box(self, Vector3(s, 0.1, ROAD), Vector3(0, 0.0, c(k)), road_mat)
		MeshKit.box(self, Vector3(ROAD, 0.1, s), Vector3(c(k), 0.0, 0), road_mat)

	var marks: Array[Transform3D] = []
	var mark_cols: Array[Color] = []
	var edges: Array[Transform3D] = []
	var edge_cols: Array[Color] = []
	var L := P - ROAD
	var cyan := Color(0.0, 0.85, 1.0)
	var magenta := Color(1.0, 0.1, 0.6)
	for axis in 2:
		var yaw := 0.0 if axis == 0 else PI / 2.0
		for k in N + 1:
			for i in N:
				var mid := (c(i) + c(i + 1)) / 2.0
				# dashed centre line
				for d in 6:
					var a := mid - L / 2.0 + (d + 0.5) / 6.0 * L
					marks.append(_xf(_seg_pos(axis, k, a, 0.0, 0.065), yaw, Vector3(3.6, 1, 0.3)))
					mark_cols.append(Color(0.9, 0.7, 0.15))
				# neon edge lines
				edges.append(_xf(_seg_pos(axis, k, mid, ROAD / 2.0 - 0.7, 0.07), yaw, Vector3(L, 1, 0.32)))
				edge_cols.append(Color(0.8, 0.8, 0.78))
				edges.append(_xf(_seg_pos(axis, k, mid, -ROAD / 2.0 + 0.7, 0.07), yaw, Vector3(L, 1, 0.32)))
				edge_cols.append(Color(0.8, 0.8, 0.78))
	# zebra crossings at every intersection approach
	for i in N + 1:
		for j in N + 1:
			var ctr := Vector3(c(i), 0.065, c(j))
			for dir in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
				var ni := i + int(dir.x)
				var nj := j + int(dir.y)
				if ni < 0 or ni > N or nj < 0 or nj > N:
					continue
				var along := Vector3(dir.x, 0, dir.y)
				var across := Vector3(-dir.y, 0, dir.x)
				var yaw2 := 0.0 if dir.x != 0.0 else PI / 2.0
				for st in 9:
					var off := (st - 4) * 1.7
					var p := ctr + along * (ROAD / 2.0 + 2.2) + across * off
					marks.append(_xf(p, yaw2, Vector3(3.0, 1, 0.8)))
					mark_cols.append(Color(0.85, 0.85, 0.83))
	var flat := _box_mesh(Vector3(1, 0.02, 1))
	_mm(flat, _mark_mat, marks, mark_cols)
	_mm(flat, _mark_mat, edges, edge_cols)

# ------------------------------------------------------------------ blocks & buildings

func _build_blocks() -> void:
	var pads: Array[Transform3D] = []
	var pad_cols: Array[Color] = []
	var bxf: Array[Transform3D] = []
	var bcols: Array[Color] = []
	var nxf: Array[Transform3D] = []
	var ncols: Array[Color] = []
	var tree_xf: Array[Transform3D] = []
	var tree_cols: Array[Color] = []
	var trunk_xf: Array[Transform3D] = []
	var trunk_cols: Array[Color] = []
	var roof_h := 0.0
	for i in N:
		for j in N:
			var bx := (c(i) + c(i + 1)) / 2.0
			var bz := (c(j) + c(j + 1)) / 2.0
			pads.append(_xf(Vector3(bx, 0.1, bz), 0.0, Vector3(BLOCK, 0.2, BLOCK)))
			pad_cols.append(Color(0.62, 0.62, 0.6))
			_add_shape(Vector3(BLOCK, 0.2, BLOCK), Vector3(bx, 0.1, bz))
			var d01 := clampf(Vector2(bx, bz).length() / half_extent, 0.0, 1.0)
			for pi in 4:
				var px := bx + (-1.0 if pi % 2 == 0 else 1.0) * BLOCK / 4.0
				var pz := bz + (-1.0 if pi < 2 else 1.0) * BLOCK / 4.0
				if rng.randf() < 0.11:
					# Bio-luminescent park instead of a building
					for t in 6:
						var tx := px + rng.randf_range(-11, 11)
						var tz := pz + rng.randf_range(-11, 11)
						var sc := rng.randf_range(0.8, 1.5)
						tree_xf.append(_xf(Vector3(tx, 0.2 + 2.2 + 1.6 * sc, tz), 0.0, Vector3(sc, sc, sc)))
						tree_cols.append(Color(rng.randf_range(0.05, 0.14), rng.randf_range(0.22, 0.4), rng.randf_range(0.05, 0.12)))
						trunk_xf.append(_xf(Vector3(tx, 0.2 + 1.2, tz), 0.0, Vector3(1, 1, 1)))
						trunk_cols.append(Color(0.18, 0.12, 0.08))
					continue
				var w := rng.randf_range(19.0, 27.0)
				var d := rng.randf_range(19.0, 27.0)
				var h := lerpf(95.0, 16.0, pow(d01, 0.8)) * rng.randf_range(0.55, 1.2)
				h = maxf(h, 11.0)
				if i == N / 2 - 1 and j == N / 2 - 1 and pi == 0:
					h = 170.0 # landmark spire
				bxf.append(_xf(Vector3(px, 0.2 + h / 2.0, pz), 0.0, Vector3(w, h, d)))
				bcols.append(_facade_color())
				_add_shape(Vector3(w, h, d), Vector3(px, 0.2 + h / 2.0, pz))
				# neon sign slab on a random face
				if rng.randf() < 0.65:
					var face := rng.randi() % 4
					var dirv := [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)][face] as Vector3
					var half := (w if face < 2 else d) / 2.0
					var yy := 5.0 + rng.randf() * minf(h - 9.0, 24.0)
					var sign_pos := Vector3(px, yy, pz) + dirv * (half + 0.25)
					var sw := (d if face < 2 else w) * rng.randf_range(0.4, 0.7)
					nxf.append(_xf(sign_pos, 0.0 if face >= 2 else PI / 2.0, Vector3(sw, rng.randf_range(2.0, 3.5), 0.4)))
					ncols.append(_neon_palette())
				# tall corner strip
				if rng.randf() < 0.4 and h > 25.0:
					var cx := px + (w / 2.0 + 0.15) * (1.0 if rng.randf() < 0.5 else -1.0)
					var cz := pz + (d / 2.0 + 0.15) * (1.0 if rng.randf() < 0.5 else -1.0)
					nxf.append(_xf(Vector3(cx, 0.2 + h * 0.6, cz), 0.0, Vector3(0.5, h * 0.8, 0.5)))
					ncols.append(_neon_palette())
				# rooftop beacon on tall towers
				if h > 55.0:
					nxf.append(_xf(Vector3(px, 0.2 + h + 5.0, pz), 0.0, Vector3(0.6, 10.0, 0.6)))
					ncols.append(Color(1.0, 0.1, 0.1))
					roof_h = maxf(roof_h, h)
	var unit := _box_mesh()
	_mm(unit, _building_mat, pads, pad_cols)
	_building_mmi = _mm(unit, _building_mat, bxf, bcols)
	_mm(unit, _neon_mat, nxf, ncols)
	var crown := SphereMesh.new()
	crown.radius = 2.0
	crown.height = 3.6
	crown.radial_segments = 8
	crown.rings = 4
	_mm(crown, _foliage_mat, tree_xf, tree_cols)
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.18
	trunk.bottom_radius = 0.28
	trunk.height = 2.4
	trunk.radial_segments = 6
	trunk.rings = 1
	_mm(trunk, _foliage_mat, trunk_xf, trunk_cols)

# ------------------------------------------------------------------ lamps, boundary, skyline

func _build_lamps() -> void:
	var pole_xf: Array[Transform3D] = []
	var head_xf: Array[Transform3D] = []
	var head_cols: Array[Color] = []
	var o := ROAD / 2.0 + 1.3
	for i in N + 1:
		for j in N + 1:
			for sx in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					# only place a lamp where an adjacent block actually exists
					var ni := i - (1 if sx < 0 else 0)
					var nj := j - (1 if sz < 0 else 0)
					if ni < 0 or nj < 0 or ni >= N or nj >= N:
						continue
					var p := Vector3(c(i) + sx * o, 0.0, c(j) + sz * o)
					pole_xf.append(_xf(p + Vector3(0, 3.7, 0), 0.0, Vector3(1, 1, 1)))
					head_xf.append(_xf(p + Vector3(-sx * 0.9, 7.5, -sz * 0.9), 0.0, Vector3(1.8, 0.16, 0.7)))
					head_cols.append(Color(1.0, 0.82, 0.55))
					_add_shape(Vector3(0.5, 7.4, 0.5), p + Vector3(0, 3.7, 0))
	var pole := CylinderMesh.new()
	pole.top_radius = 0.1
	pole.bottom_radius = 0.16
	pole.height = 7.4
	pole.radial_segments = 6
	pole.rings = 1
	_mm(pole, MeshKit.mat(Color(0.12, 0.13, 0.17), 0.0, 0.6, 0.5), pole_xf)
	_mm(_box_mesh(), _neon_mat, head_xf, head_cols)

func _build_boundary() -> void:
	var e := half_extent + 1.0
	var wall := MeshKit.mat(Color(0.0, 0.8, 1.0), 1.3, 0.0, 0.5, 0.18)
	wall.cull_mode = BaseMaterial3D.CULL_DISABLED
	for side in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]:
		var s := side as Vector3
		var along_x := s.x == 0.0
		var size := Vector3(half_extent * 2.0 + 6.0, 40.0, 2.0) if along_x else Vector3(2.0, 40.0, half_extent * 2.0 + 6.0)
		_add_shape(size, s * e + Vector3(0, 20, 0))
		var vis := Vector3(size.x, 9.0, 0.2) if along_x else Vector3(0.2, 9.0, size.z)
		MeshKit.box(self, vis, s * (e - 0.9) + Vector3(0, 4.5, 0), wall).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _build_skyline() -> void:
	var xf: Array[Transform3D] = []
	var cols: Array[Color] = []
	var r := half_extent + 110.0
	for k in 70:
		var ang := TAU * k / 70.0 + rng.randf_range(-0.03, 0.03)
		var rr := r + rng.randf_range(0.0, 260.0)
		var h := rng.randf_range(70.0, 260.0)
		var w := rng.randf_range(24.0, 60.0)
		xf.append(_xf(Vector3(cos(ang) * rr, h / 2.0, sin(ang) * rr), ang, Vector3(w, h, w * rng.randf_range(0.7, 1.3))))
		cols.append(_facade_color())
	_mm(_box_mesh(), _building_mat, xf, cols)

# ------------------------------------------------------------------ navigation graph

func _build_graph() -> void:
	for i in N + 1:
		for j in N + 1:
			astar.add_point(node_id(i, j), Vector2(c(i), c(j)))
	for i in N + 1:
		for j in N + 1:
			if i < N:
				astar.connect_points(node_id(i, j), node_id(i + 1, j))
			if j < N:
				astar.connect_points(node_id(i, j), node_id(i, j + 1))
	# Pick-up / drop-off stops: one on every road segment, in the kerb-side lane.
	for i in N + 1:
		for j in N + 1:
			if i < N:
				_add_stop(i, j, i + 1, j)
			if j < N:
				_add_stop(i, j, i, j + 1)

func _add_stop(i1: int, j1: int, i2: int, j2: int) -> void:
	var a := Vector3(c(i1), 0, c(j1))
	var b := Vector3(c(i2), 0, c(j2))
	var mid := (a + b) / 2.0
	var dirv := (b - a).normalized()
	var left := Vector3(dirv.z, 0, -dirv.x)
	var side := 1.0 if rng.randf() < 0.5 else -1.0
	var pos := mid + left * side * 6.4 + Vector3(0, 0.1, 0)
	stops.append({"pos": pos, "a": node_id(i1, j1), "b": node_id(i2, j2)})

func node_pos(id: int) -> Vector3:
	var v := astar.get_point_position(id)
	return Vector3(v.x, 0.0, v.y)

func nearest_node(p: Vector3) -> int:
	var i := clampi(roundi(p.x / P + N / 2.0), 0, N)
	var j := clampi(roundi(p.z / P + N / 2.0), 0, N)
	return node_id(i, j)

func neighbors(id: int) -> PackedInt64Array:
	return astar.get_point_connections(id)

## Waypoints (road intersections, then the stop itself) to drive from `from` to `stop`.
func guide_path(from: Vector3, stop: Dictionary) -> PackedVector3Array:
	var start := nearest_node(from)
	var best := PackedVector2Array()
	var best_len := INF
	for end_id in [stop["a"], stop["b"]]:
		var path := astar.get_point_path(start, end_id)
		var l := 0.0
		for q in range(1, path.size()):
			l += path[q].distance_to(path[q - 1])
		if l < best_len:
			best_len = l
			best = path
	var out := PackedVector3Array()
	for v in best:
		out.append(Vector3(v.x, 0.0, v.y))
	out.append(stop["pos"])
	return out

func path_length(pts: PackedVector3Array, from: Vector3) -> float:
	var l := 0.0
	var prev := from
	for p in pts:
		l += prev.distance_to(p)
		prev = p
	return l

## Snap a position to the nearest road centre line (used for safe respawns).
func nearest_road_point(p: Vector3) -> Vector3:
	var kx := clampi(roundi(p.x / P + N / 2.0), 0, N)
	var kz := clampi(roundi(p.z / P + N / 2.0), 0, N)
	var dx := absf(p.x - c(kx))
	var dz := absf(p.z - c(kz))
	if dx < dz:
		return Vector3(c(kx), 0.8, clampf(p.z, -half_extent + 10, half_extent - 10))
	return Vector3(clampf(p.x, -half_extent + 10, half_extent - 10), 0.8, c(kz))

func spawn_transform() -> Transform3D:
	var k := N / 2
	return Transform3D(Basis(Vector3.UP, 0.0), Vector3(c(k) - LANE, 0.9, c(k) + 30.0))

func set_wet(amount: float) -> void:
	road_mat.roughness = lerpf(0.88, 0.16, amount)
	road_mat.metallic = lerpf(0.0, 0.55, amount)

## 0 = full day, 1 = full night. Drives lit windows and sign/lamp brightness.
func set_night(n: float) -> void:
	_building_mat.set_shader_parameter("night", n)
	_neon_mat.set_shader_parameter("intensity", lerpf(0.3, 1.0, n))

## Buildings only cast sun shadows on the High preset (they are expensive on phones).
func set_building_shadows(on: bool) -> void:
	if _building_mmi != null:
		_building_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if on else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
