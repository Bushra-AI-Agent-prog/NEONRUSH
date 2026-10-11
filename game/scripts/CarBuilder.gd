class_name CarBuilder
extends RefCounted
## Procedural car geometry. Bodies are lofted through superellipse cross-sections
## (smooth, curved panels instead of boxes). Meshes are cached per car id.

const SEG := 26
const NST := 30
const NSC := 16

static var _cache: Dictionary = {}
static var _wmats: Dictionary = {}

# ------------------------------------------------------------------ curves

## Smoothly interpolated value of a [[t, v], ...] curve.
static func cv(pts: Array, t: float) -> float:
	if t <= float(pts[0][0]):
		return float(pts[0][1])
	for i in range(1, pts.size()):
		if t <= float(pts[i][0]):
			var a: Array = pts[i - 1]
			var b: Array = pts[i]
			var u := (t - float(a[0])) / maxf(float(b[0]) - float(a[0]), 0.0001)
			u = u * u * (3.0 - 2.0 * u)
			return lerpf(float(a[1]), float(b[1]), u)
	return float(pts[pts.size() - 1][1])

# ------------------------------------------------------------------ loft

static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)

static func _ring(s: Dictionary) -> PackedVector3Array:
	var ring := PackedVector3Array()
	var n: float = s["n"]
	var y0: float = s["y0"]
	var y1: float = s["y1"]
	var ym := (y0 + y1) * 0.5
	var hh := maxf((y1 - y0) * 0.5, 0.002)
	var hw: float = s["hw"]
	var z: float = s["z"]
	for i in SEG:
		var a := TAU * float(i) / SEG
		var c := cos(a)
		var sn := sin(a)
		ring.append(Vector3(hw * signf(c) * pow(absf(c), 2.0 / n), ym + hh * signf(sn) * pow(absf(sn), 2.0 / n), z))
	return ring

## Build a closed mesh through the given stations (front -> rear along +Z).
static func loft(stations: Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array = []
	for s in stations:
		rings.append(_ring(s))
	st.set_smooth_group(0)
	for r in range(rings.size() - 1):
		var A: PackedVector3Array = rings[r]
		var B: PackedVector3Array = rings[r + 1]
		for i in SEG:
			var j := (i + 1) % SEG
			_tri(st, A[i], B[j], A[j])
			_tri(st, A[i], B[i], B[j])
	st.set_smooth_group(-1)
	var f: PackedVector3Array = rings[0]
	var rr: PackedVector3Array = rings[rings.size() - 1]
	var fc := Vector3.ZERO
	var rc := Vector3.ZERO
	for i in SEG:
		fc += f[i]
		rc += rr[i]
	fc /= SEG
	rc /= SEG
	for i in SEG:
		var j := (i + 1) % SEG
		_tri(st, fc, f[i], f[j])
		_tri(st, rc, rr[j], rr[i])
	st.generate_normals()
	return st.commit()

# ------------------------------------------------------------------ meshes per car

static func body_stations(s: Dictionary) -> Array:
	var L: float = s["len"]
	var out: Array = []
	var tf := (float(s["wzf"]) + L * 0.5) / L
	var tr := (float(s["wzr"]) + L * 0.5) / L
	for i in NST:
		var t := float(i) / (NST - 1)
		var hw := cv(s["hw"], t)
		# sharper nose / tail taper and fender flares over the wheels
		hw *= lerpf(0.9, 1.0, smoothstep(0.0, 0.1, t)) * lerpf(0.92, 1.0, smoothstep(1.0, 0.92, t))
		hw += 0.03 * exp(-pow((t - tf) / 0.07, 2.0)) + 0.035 * exp(-pow((t - tr) / 0.07, 2.0))
		var n := lerpf(3.2, 4.2, smoothstep(0.0, 0.14, t)) * lerpf(0.85, 1.0, smoothstep(1.0, 0.9, t))
		out.append({"z": -L * 0.5 + t * L, "hw": hw, "y0": cv(s["y0"], t), "y1": cv(s["y1"], t), "n": n})
	return out

static func cabin_stations(s: Dictionary, roof_panel: bool) -> Array:
	var L: float = s["len"]
	var t0: float = s["c0"]
	var t1: float = s["c1"]
	var out: Array = []
	for i in NSC:
		var u := float(i) / (NSC - 1)
		var t := lerpf(t0, t1, u)
		var belt := cv(s["y1"], t)
		var top := maxf(belt + cv(s["roof_f"], u) * (float(s["roof"]) - belt), belt + 0.02)
		var hw := cv(s["chw"], u)
		if roof_panel:
			out.append({"z": -L * 0.5 + t * L, "hw": hw * 0.9, "y0": maxf(top - 0.05, belt - 0.02), "y1": top + 0.004, "n": 3.0})
		else:
			out.append({"z": -L * 0.5 + t * L, "hw": hw, "y0": belt - 0.06, "y1": top, "n": 3.0})
	return out

## Wheel centre X so the tyre sits just proud of the (flared) body side.
static func wheel_x(s: Dictionary, z: float) -> float:
	var L: float = s["len"]
	var t := (z + L * 0.5) / L
	var tf := (float(s["wzf"]) + L * 0.5) / L
	var tr := (float(s["wzr"]) + L * 0.5) / L
	var hw := cv(s["hw"], t) + 0.03 * exp(-pow((t - tf) / 0.07, 2.0)) + 0.035 * exp(-pow((t - tr) / 0.07, 2.0))
	return hw - float(s["ww"]) * 0.5 + 0.045

static func meshes(s: Dictionary) -> Dictionary:
	var id: String = s["id"]
	if not _cache.has(id):
		_cache[id] = {
			"body": loft(body_stations(s)),
			"glass": loft(cabin_stations(s, false)),
			"roof": loft(cabin_stations(s, true)),
		}
	return _cache[id]

# ------------------------------------------------------------------ wheels

static func _wmat(key: String, color: Color, metal: float, rough: float) -> StandardMaterial3D:
	if not _wmats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.metallic = metal
		m.roughness = rough
		_wmats[key] = m
	return _wmats[key]

## Tyre + alloy wheel with spokes, dish and brake caliper. Axle along local X.
static func wheel_visual(parent: Node3D, s: Dictionary, detail: int) -> void:
	var r: float = s["wr"]
	var w: float = s["ww"]
	var tire := _wmat("tire", Color(0.025, 0.025, 0.03), 0.0, 0.9)
	var alloy := _wmat("alloy", Color(0.72, 0.73, 0.78), 1.0, 0.22)
	var dish := _wmat("dish", Color(0.06, 0.06, 0.07), 0.6, 0.5)
	var cal := _wmat("caliper", Color(0.85, 0.08, 0.08), 0.3, 0.4)
	MeshKit.cyl(parent, r, w, Vector3.ZERO, tire, Vector3(0, 0, 90), 22 if detail > 0 else 12)
	if detail <= 0:
		MeshKit.cyl(parent, r * 0.64, w * 1.03, Vector3.ZERO, alloy, Vector3(0, 0, 90), 12)
		return
	MeshKit.cyl(parent, r * 0.68, w * 1.01, Vector3.ZERO, alloy, Vector3(0, 0, 90), 24)
	MeshKit.cyl(parent, r * 0.58, w * 1.03, Vector3.ZERO, dish, Vector3(0, 0, 90), 24)
	MeshKit.box(parent, Vector3(w * 0.5, r * 0.26, r * 0.3), Vector3(0, r * 0.38, r * 0.12), cal)
	for k in 5:
		MeshKit.box(parent, Vector3(w * 1.07, r * 0.07, r * 1.18), Vector3.ZERO, alloy, Vector3(k * 36.0, 0, 0))
	MeshKit.cyl(parent, r * 0.16, w * 1.1, Vector3.ZERO, alloy, Vector3(0, 0, 90), 12)

# ------------------------------------------------------------------ assembly

static func build(s: Dictionary, detail: int) -> CarModel:
	var m := CarModel.new()
	m.setup(s, detail)
	return m
