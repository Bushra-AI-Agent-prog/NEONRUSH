class_name BusModel
extends Node3D
## Visual model of the futuristic microbus. Forward is -Z. Used by the physics
## vehicle (Microbus) and by the garage preview. Wheels are added by the owner.

var body_mat: StandardMaterial3D
var neon_mat: StandardMaterial3D
var glow_light: OmniLight3D
var headlight: SpotLight3D
var tail_mat: StandardMaterial3D
var _kit_root: Node3D

func _init() -> void:
	body_mat = MeshKit.mat(Color.WHITE, 0.0, 0.55, 0.28)
	neon_mat = MeshKit.mat(Color(0, 0.9, 1), 2.2)
	tail_mat = MeshKit.mat(Color(1, 0.08, 0.08), 1.2)
	_build()

func _build() -> void:
	var dark := MeshKit.mat(Color(0.05, 0.05, 0.07), 0.0, 0.6, 0.5)
	var glass := MeshKit.mat(Color(0.02, 0.12, 0.18), 0.35, 0.9, 0.05, 0.88)
	var head := MeshKit.mat(Color(1.0, 0.97, 0.85), 3.0)

	# Chassis, nose and belly
	MeshKit.box(self, Vector3(1.95, 0.6, 4.8), Vector3(0, 0.05, 0), body_mat)
	MeshKit.box(self, Vector3(1.8, 0.2, 4.6), Vector3(0, -0.32, 0), dark)
	MeshKit.box(self, Vector3(1.9, 0.34, 1.0), Vector3(0, 0.5, -1.9), body_mat, Vector3(-14, 0, 0))
	# Cabin + roof
	MeshKit.box(self, Vector3(1.9, 1.05, 3.5), Vector3(0, 0.9, 0.65), body_mat)
	MeshKit.box(self, Vector3(1.78, 0.1, 3.45), Vector3(0, 1.48, 0.65), body_mat)
	# Glass: windshield and side windows
	MeshKit.box(self, Vector3(1.72, 0.78, 0.07), Vector3(0, 0.95, -1.12), glass, Vector3(-24, 0, 0))
	for sx in [-1.0, 1.0]:
		MeshKit.box(self, Vector3(0.05, 0.5, 3.1), Vector3(sx * 0.96, 1.08, 0.7), glass)
	# Neon accents
	for sx in [-1.0, 1.0]:
		MeshKit.box(self, Vector3(0.04, 0.07, 4.6), Vector3(sx * 0.98, 0.14, 0), neon_mat)
	MeshKit.box(self, Vector3(1.7, 0.03, 4.2), Vector3(0, -0.42, 0), neon_mat)
	MeshKit.box(self, Vector3(1.3, 0.07, 0.14), Vector3(0, 1.56, -0.95), neon_mat)
	# Bumpers
	MeshKit.box(self, Vector3(1.98, 0.2, 0.16), Vector3(0, -0.12, -2.42), dark)
	MeshKit.box(self, Vector3(1.98, 0.2, 0.16), Vector3(0, -0.12, 2.42), dark)
	# Head / tail lights
	for sx in [-1.0, 1.0]:
		MeshKit.box(self, Vector3(0.38, 0.14, 0.05), Vector3(sx * 0.7, 0.28, -2.42), head)
		MeshKit.box(self, Vector3(0.42, 0.13, 0.05), Vector3(sx * 0.7, 0.34, 2.42), tail_mat)

	headlight = SpotLight3D.new()
	headlight.position = Vector3(0, 0.3, -2.5)
	headlight.spot_range = 32.0
	headlight.spot_angle = 38.0
	headlight.light_energy = 2.5
	headlight.light_color = Color(1.0, 0.96, 0.85)
	add_child(headlight)

	glow_light = OmniLight3D.new()
	glow_light.position = Vector3(0, -0.2, 0)
	glow_light.omni_range = 6.0
	glow_light.light_energy = 1.4
	add_child(glow_light)

	_kit_root = Node3D.new()
	add_child(_kit_root)

## Apply customization by indices into Game.COLORS / NEONS / KITS.
func apply(color_i: int, neon_i: int, kit_i: int) -> void:
	var c: Color = Game.COLORS[clampi(color_i, 0, Game.COLORS.size() - 1)]["color"]
	var n: Color = Game.NEONS[clampi(neon_i, 0, Game.NEONS.size() - 1)]["color"]
	body_mat.albedo_color = c
	neon_mat.albedo_color = n
	neon_mat.emission = n
	glow_light.light_color = n
	_build_kit(clampi(kit_i, 0, Game.KITS.size() - 1), c)

func set_brake_light(on: bool) -> void:
	tail_mat.emission_energy_multiplier = 4.0 if on else 1.2

func set_lights_quality(q: int) -> void:
	headlight.visible = q >= 1
	glow_light.visible = q >= 1

func _build_kit(kit: int, body: Color) -> void:
	for ch in _kit_root.get_children():
		ch.queue_free()
	var accent := MeshKit.mat(body.darkened(0.25), 0.0, 0.6, 0.3)
	if kit == 1 or kit == 3:
		MeshKit.box(_kit_root, Vector3(0.08, 0.32, 1.5), Vector3(0, 1.68, 1.2), accent)
	if kit == 2 or kit == 3:
		MeshKit.box(_kit_root, Vector3(1.8, 0.07, 0.5), Vector3(0, 1.82, 2.3), accent)
		for sx in [-0.7, 0.7]:
			MeshKit.box(_kit_root, Vector3(0.06, 0.3, 0.2), Vector3(sx, 1.64, 2.3), accent)
	if kit == 3:
		for sx in [-1.0, 1.0]:
			MeshKit.box(_kit_root, Vector3(0.1, 0.16, 3.2), Vector3(sx * 1.0, -0.24, 0), accent)
		MeshKit.box(_kit_root, Vector3(1.9, 0.05, 0.5), Vector3(0, -0.28, -2.55), accent)
