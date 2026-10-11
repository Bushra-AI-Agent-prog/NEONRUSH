class_name MeshKit
extends RefCounted
## Small procedural-mesh helpers so the whole game needs no art assets.

static func mat(c: Color, emit := 0.0, metal := 0.0, rough := 0.6, alpha := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(c.r, c.g, c.b, alpha)
	m.metallic = metal
	m.roughness = rough
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m

static func box(parent: Node, size: Vector3, pos: Vector3, material: Material, rot_deg := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = material
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi

static func cyl(parent: Node, radius: float, height: float, pos: Vector3, material: Material, rot_deg := Vector3.ZERO, segments := 14) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	cm.radial_segments = segments
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = material
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi

## Tire + neon rim, axis along local X. Added under `parent` (e.g. a VehicleWheel3D).
static func wheel_visual(parent: Node, radius: float, width: float, rim: Material) -> void:
	var tire := mat(Color(0.03, 0.03, 0.04), 0.0, 0.0, 0.9)
	cyl(parent, radius, width, Vector3.ZERO, tire, Vector3(0, 0, 90), 18)
	cyl(parent, radius * 0.62, width * 1.04, Vector3.ZERO, rim, Vector3(0, 0, 90), 14)
	cyl(parent, radius * 0.3, width * 1.08, Vector3.ZERO, mat(Color(0.1, 0.1, 0.12), 0.0, 0.8, 0.3), Vector3(0, 0, 90), 8)
