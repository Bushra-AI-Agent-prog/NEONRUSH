class_name CarModel
extends Node3D
## Visual model of a CarBuilder car. Same duck-typed API as BusModel so the
## physics vehicle, showroom and traffic can use either.

var body_mat: StandardMaterial3D
var neon_mat: StandardMaterial3D
var tail_mat: StandardMaterial3D
var glow_light: OmniLight3D
var headlight: SpotLight3D
var spec: Dictionary
var detail := 1
var _kit_root: Node3D

func setup(s: Dictionary, det: int) -> void:
	spec = s
	detail = det
	var L: float = s["len"]
	var m := CarBuilder.meshes(s)

	# Clear-coat metallic paint (reflects the sky), tinted glass, trim.
	body_mat = StandardMaterial3D.new()
	body_mat.albedo_color = Color.WHITE
	body_mat.metallic = 0.55
	body_mat.metallic_specular = 0.9
	body_mat.roughness = 0.3
	body_mat.clearcoat_enabled = true
	body_mat.clearcoat = 1.0
	body_mat.clearcoat_roughness = 0.05
	var glass := MeshKit.mat(Color(0.015, 0.03, 0.045), 0.0, 0.85, 0.04)
	var dark := MeshKit.mat(Color(0.015, 0.015, 0.018), 0.0, 0.3, 0.55)
	var chrome := MeshKit.mat(Color(0.85, 0.86, 0.9), 0.0, 1.0, 0.12)
	var head := MeshKit.mat(Color(1.0, 0.97, 0.88), 3.0)
	neon_mat = MeshKit.mat(Color(0, 0.9, 1), 2.0)
	tail_mat = MeshKit.mat(Color(1, 0.05, 0.05), 1.6)

	_mesh(m["body"], body_mat)
	_mesh(m["glass"], glass)
	_mesh(m["roof"], body_mat)

	var hwf := CarBuilder.cv(s["hw"], 0.04)
	var hwr := CarBuilder.cv(s["hw"], 0.97)
	var y0f := CarBuilder.cv(s["y0"], 0.04)
	var y1f := CarBuilder.cv(s["y1"], 0.04)
	var y0r := CarBuilder.cv(s["y0"], 0.97)
	var y1r := CarBuilder.cv(s["y1"], 0.97)
	var front_z := -L * 0.5
	# The nose is a flat face; everything below is mounted on it.
	var fh := CarBuilder.cv(s["hw"], 0.0) * 0.9
	var fy0 := CarBuilder.cv(s["y0"], 0.0)
	var fy1 := CarBuilder.cv(s["y1"], 0.0)
	var fym := (fy0 + fy1) * 0.5

	# Underbody
	MeshKit.box(self, Vector3(1.5, 0.08, L * 0.88), Vector3(0, float(CarBuilder.cv(s["y0"], 0.5)) + 0.03, 0), dark)

	# Painted-black wheel arches (read as arches around the tyres)
	var arch := MeshKit.mat(Color(0.012, 0.012, 0.015), 0.0, 0.0, 0.9)
	for sx in [-1.0, 1.0]:
		for z in [s["wzf"], s["wzr"]]:
			var wx := CarBuilder.wheel_x(s, float(z))
			MeshKit.cyl(self, float(s["wr"]) * 1.16, 0.06, Vector3(float(sx) * (wx - float(s["ww"]) * 0.5 + 0.02), float(s["wr"]), float(z)), arch, Vector3(0, 0, 90), 20)

	# Headlights on the face
	var ly := fym + (fy1 - fy0) * 0.18
	for sx in [-1.0, 1.0]:
		if s["lights"] == "round":
			MeshKit.cyl(self, 0.1, 0.05, Vector3(sx * fh * 0.68, ly, front_z + 0.02), arch, Vector3(90, 0, 0), 16)
			MeshKit.cyl(self, 0.075, 0.06, Vector3(sx * fh * 0.68, ly, front_z + 0.015), head, Vector3(90, 0, 0), 16)
		else:
			MeshKit.box(self, Vector3(fh * 0.6, 0.075, 0.05), Vector3(sx * fh * 0.64, ly, front_z + 0.02), head)
			MeshKit.box(self, Vector3(fh * 0.66, 0.1, 0.045), Vector3(sx * fh * 0.64, ly + 0.01, front_z + 0.03), arch)
	# Grille
	var gh := minf(0.22, (fy1 - fy0) * 0.5)
	var gw := fh * 2.0 * float(s["grille"]) * 0.8
	var gy := fym - (fy1 - fy0) * 0.12
	if s["chrome"]:
		MeshKit.box(self, Vector3(gw + 0.07, gh + 0.07, 0.04), Vector3(0, gy, front_z + 0.03), chrome)
	MeshKit.box(self, Vector3(gw, gh, 0.05), Vector3(0, gy, front_z + 0.025), dark)
	if detail > 0:
		var bars := 5
		for i in bars:
			var yy := gy - gh * 0.5 + gh * (i + 0.5) / bars
			MeshKit.box(self, Vector3(gw * 0.96, 0.012, 0.03), Vector3(0, yy, front_z + 0.0), chrome if s["chrome"] else MeshKit.mat(Color(0.25, 0.25, 0.28), 0, 0.7, 0.4))
	# Lower intake + splitter
	MeshKit.box(self, Vector3(fh * 1.5, 0.08, 0.04), Vector3(0, fy0 + 0.07, front_z + 0.02), dark)
	if s["splitter"]:
		MeshKit.box(self, Vector3(fh * 2.0, 0.03, 0.2), Vector3(0, fy0 - 0.01, front_z + 0.0), dark)

	# Rear: tail-light bar, diffuser, exhausts
	MeshKit.box(self, Vector3(hwr * 1.55, 0.09, 0.07), Vector3(0, y1r - 0.12, L * 0.5 - 0.05), tail_mat)
	MeshKit.box(self, Vector3(hwr * 1.3, 0.1, 0.07), Vector3(0, y0r + 0.07, L * 0.5 - 0.04), dark)
	if detail > 0:
		for sx in [-1.0, 1.0]:
			MeshKit.cyl(self, 0.042, 0.1, Vector3(sx * hwr * 0.5, y0r + 0.06, L * 0.5 + 0.02), chrome, Vector3(90, 0, 0), 10)

	# Hood scoop
	if s["scoop"]:
		var sy := CarBuilder.cv(s["y1"], 0.3)
		MeshKit.box(self, Vector3(0.5, 0.045, 0.45), Vector3(0, sy + 0.018, -L * 0.5 + L * 0.3), dark)

	# Factory wing
	var wing: int = s["wing"]
	if wing == 1:
		MeshKit.box(self, Vector3(hwr * 1.7, 0.035, 0.22), Vector3(0, y1r + 0.035, L * 0.5 - 0.17), dark, Vector3(8, 0, 0))
	elif wing == 2:
		_gt_wing(dark, y1r, L, hwr)

	# Mirrors and door shut lines
	if detail > 0:
		var mt: float = float(s["c0"]) + 0.07
		var mx := CarBuilder.cv(s["chw"], 0.0) + 0.1
		var my := CarBuilder.cv(s["y1"], mt) + 0.1
		for sx in [-1.0, 1.0]:
			MeshKit.box(self, Vector3(0.1, 0.075, 0.17), Vector3(sx * mx, my, -L * 0.5 + mt * L), body_mat, Vector3(0, sx * -8.0, 0))
		var d0: float = float(s["c0"]) + 0.02
		var d1: float = lerpf(float(s["c0"]), float(s["c1"]), 0.5)
		for tt in [d0, d1]:
			var hwd := CarBuilder.cv(s["hw"], tt)
			var yb := CarBuilder.cv(s["y0"], tt) + 0.12
			var yt := CarBuilder.cv(s["y1"], tt) - 0.04
			for sx in [-1.0, 1.0]:
				MeshKit.box(self, Vector3(0.012, yt - yb, 0.012), Vector3(sx * (hwd - 0.003), (yb + yt) * 0.5, -L * 0.5 + tt * L), dark)

	# Underglow, side accents and lights
	MeshKit.box(self, Vector3(hwf * 1.6, 0.02, L * 0.72), Vector3(0, float(CarBuilder.cv(s["y0"], 0.5)) - 0.015, 0), neon_mat)
	if detail > 0:
		for sx in [-1.0, 1.0]:
			MeshKit.box(self, Vector3(0.02, 0.03, L * 0.42), Vector3(sx * (CarBuilder.cv(s["hw"], 0.5) - 0.002), float(CarBuilder.cv(s["y0"], 0.5)) + 0.06, 0.15), neon_mat)
		headlight = SpotLight3D.new()
		headlight.position = Vector3(0, ly, front_z - 0.1)
		headlight.spot_range = 36.0
		headlight.spot_angle = 34.0
		headlight.light_energy = 2.4
		headlight.light_color = Color(1.0, 0.96, 0.88)
		add_child(headlight)
		glow_light = OmniLight3D.new()
		glow_light.position = Vector3(0, 0.1, 0)
		glow_light.omni_range = 5.5
		glow_light.light_energy = 1.2
		add_child(glow_light)
	else:
		# cheap grounding shadow for traffic
		var q := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(hwf * 2.5, L * 1.12)
		qm.orientation = PlaneMesh.FACE_Y
		q.mesh = qm
		q.position.y = 0.015
		q.material_override = _blob_mat()
		q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(q)

	_kit_root = Node3D.new()
	add_child(_kit_root)

static var _blob: StandardMaterial3D
static func _blob_mat() -> StandardMaterial3D:
	if _blob == null:
		var g := Gradient.new()
		g.colors = PackedColorArray([Color(0, 0, 0, 0.55), Color(0, 0, 0, 0.0)])
		g.offsets = PackedFloat32Array([0.35, 1.0])
		var tex := GradientTexture2D.new()
		tex.gradient = g
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		tex.width = 64
		tex.height = 64
		_blob = StandardMaterial3D.new()
		_blob.albedo_texture = tex
		_blob.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_blob.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return _blob

func _mesh(mesh: Mesh, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	add_child(mi)
	return mi

func _gt_wing(mat: Material, y1r: float, L: float, hwr: float) -> void:
	var wy := y1r + 0.42
	var wz := L * 0.5 - 0.3
	MeshKit.box(self, Vector3(hwr * 2.0, 0.04, 0.38), Vector3(0, wy, wz), mat, Vector3(6, 0, 0))
	MeshKit.box(self, Vector3(hwr * 2.0, 0.025, 0.2), Vector3(0, wy + 0.1, wz + 0.1), mat, Vector3(14, 0, 0))
	for sx in [-1.0, 1.0]:
		MeshKit.box(self, Vector3(0.04, 0.4, 0.1), Vector3(sx * hwr * 0.45, wy - 0.2, wz), mat)
		MeshKit.box(self, Vector3(0.02, 0.22, 0.46), Vector3(sx * hwr * 0.98, wy + 0.02, wz), mat)

# ---------------------------------------------------------------- BusModel-compatible API

func apply(color_i: int, neon_i: int, kit_i: int) -> void:
	var c: Color = Game.COLORS[clampi(color_i, 0, Game.COLORS.size() - 1)]["color"]
	var n: Color = Game.NEONS[clampi(neon_i, 0, Game.NEONS.size() - 1)]["color"]
	body_mat.albedo_color = c
	neon_mat.albedo_color = n
	neon_mat.emission = n
	if glow_light != null:
		glow_light.light_color = n
	_build_kit(clampi(kit_i, 0, Game.KITS.size() - 1), c)

## Direct paint (traffic cars use arbitrary colours).
func paint(c: Color) -> void:
	body_mat.albedo_color = c

func set_brake_light(on: bool) -> void:
	tail_mat.emission_energy_multiplier = 4.5 if on else 1.6

func set_lights_quality(q: int) -> void:
	if headlight != null:
		headlight.visible = q >= 1
	if glow_light != null:
		glow_light.visible = q >= 1

func _build_kit(kit: int, body: Color) -> void:
	for ch in _kit_root.get_children():
		ch.queue_free()
	var s := spec
	var L: float = s["len"]
	var hwr := CarBuilder.cv(s["hw"], 0.97)
	var hwf := CarBuilder.cv(s["hw"], 0.04)
	var y1r := CarBuilder.cv(s["y1"], 0.97)
	var carbon := MeshKit.mat(Color(0.02, 0.02, 0.025), 0.0, 0.4, 0.45)
	if kit == 1:
		MeshKit.box(_kit_root, Vector3(hwr * 1.7, 0.04, 0.2), Vector3(0, y1r + 0.05, L * 0.5 - 0.15), carbon, Vector3(10, 0, 0))
	if (kit == 2 or kit == 3) and int(s["wing"]) != 2:
		var wy := y1r + 0.34
		var wz := L * 0.5 - 0.28
		MeshKit.box(_kit_root, Vector3(hwr * 1.9, 0.04, 0.34), Vector3(0, wy, wz), carbon, Vector3(6, 0, 0))
		for sx in [-1.0, 1.0]:
			MeshKit.box(_kit_root, Vector3(0.04, 0.34, 0.1), Vector3(sx * hwr * 0.45, wy - 0.17, wz), carbon)
			MeshKit.box(_kit_root, Vector3(0.02, 0.18, 0.4), Vector3(sx * hwr * 0.96, wy + 0.02, wz), carbon)
	if kit == 3:
		var y0 := CarBuilder.cv(s["y0"], 0.5)
		for sx in [-1.0, 1.0]:
			MeshKit.box(_kit_root, Vector3(0.07, 0.1, L * 0.5), Vector3(sx * (CarBuilder.cv(s["hw"], 0.5) + 0.01), y0 + 0.06, 0.05), carbon)
		MeshKit.box(_kit_root, Vector3(hwf * 2.15, 0.03, 0.4), Vector3(0, CarBuilder.cv(s["y0"], 0.04) - 0.03, -L * 0.5 + 0.1), carbon)
