class_name Cars
extends RefCounted
## Car roster. Index 0 is the original Neon Microbus (BusModel). The others are
## ORIGINAL designs (not copies of any real car or brand) built procedurally by CarBuilder.
##
## Curves are [t, value] pairs, t = 0 at the nose .. 1 at the tail (body) or
## u = 0..1 across the cabin. Units are metres; the ground is y = 0.

const BUS := 0

const LIST: Array = [
	{
		"id": "microbus", "name": "Neon Microbus", "kind": "bus", "level": 1, "cost": 0,
		"desc": "Roomy 6-seat taxi. Stable and forgiving.",
		"mass": 1300.0, "power": 3000.0, "kmh": 140, "top": 140.0, "grip": 5.0, "brake": 30.0, "steer": 1.0,
		"downforce": 6.0, "com": Vector3(0, -0.35, 0.1), "cam": 1.0, "len": 4.8, "paint": 1,
		"box": Vector3(1.9, 1.8, 4.7), "box_y": 0.6,
		"wr": 0.4, "ww": 0.3, "wx": 0.95, "wzf": -1.55, "wzr": 1.55, "wy": -0.2, "rest": 0.2,
		"stiff": 48.0, "roll": 0.15, "oh": 0.0,
	},
	{
		"id": "kairo", "name": "Kairo GT", "kind": "coupe", "level": 2, "cost": 1800,
		"desc": "Wide-body sports coupe with a ducktail. Agile and grippy.",
		"mass": 1450.0, "power": 3200.0, "kmh": 160, "top": 175.0, "grip": 6.4, "brake": 36.0, "steer": 1.0,
		"downforce": 8.0, "com": Vector3(0, -0.15, 0.05), "cam": 0.82, "len": 4.42, "paint": 4,
		"hw": [[0, .76], [.05, .88], [.16, .92], [.32, .93], [.7, .93], [.88, .95], [.97, .88], [1, .78]],
		"y0": [[0, .30], [.03, .22], [.1, .17], [.9, .17], [.97, .24], [1, .32]],
		"y1": [[0, .50], [.06, .60], [.22, .69], [.40, .79], [.62, .83], [.86, .88], [.96, .88], [1, .78]],
		"c0": 0.38, "c1": 0.86, "roof": 1.27,
		"chw": [[0, .82], [.5, .76], [1, .70]],
		"roof_f": [[0, 0.0], [.1, .55], [.3, .97], [.55, 1.0], [.8, .78], [1, .2]],
		"wr": 0.34, "ww": 0.28, "wx": 0.80, "wzf": -1.36, "wzr": 1.38, "wy": -0.05, "rest": 0.14,
		"stiff": 66, "roll": 0.08, "oh": 0.477,
		"wing": 1, "splitter": true, "grille": 0.5, "lights": "slim", "scoop": false, "chrome": false,
		"box": Vector3(1.86, 1.1, 4.3), "box_y": 0.7,
	},
	{
		"id": "stallion", "name": "Stallion GT", "kind": "muscle", "level": 3, "cost": 3000,
		"desc": "Long-hood muscle coupe. Loud, fast and heavy.",
		"mass": 1650.0, "power": 3500.0, "kmh": 165, "top": 185.0, "grip": 5.8, "brake": 36.0, "steer": 0.95,
		"downforce": 7.0, "com": Vector3(0, -0.2, -0.1), "cam": 0.92, "len": 4.78, "paint": 3,
		"hw": [[0, .78], [.05, .90], [.16, .94], [.4, .95], [.8, .95], [.95, .92], [1, .82]],
		"y0": [[0, .32], [.03, .24], [.1, .2], [.9, .2], [.97, .27], [1, .34]],
		"y1": [[0, .62], [.06, .72], [.25, .80], [.5, .88], [.62, .91], [.88, .94], [.96, .94], [1, .85]],
		"c0": 0.5, "c1": 0.88, "roof": 1.32,
		"chw": [[0, .84], [.5, .78], [1, .72]],
		"roof_f": [[0, 0.0], [.1, .5], [.3, .95], [.55, 1.0], [.8, .7], [1, .15]],
		"wr": 0.35, "ww": 0.29, "wx": 0.82, "wzf": -1.5, "wzr": 1.5, "wy": -0.05, "rest": 0.14,
		"stiff": 72, "roll": 0.09, "oh": 0.491,
		"wing": 0, "splitter": true, "grille": 0.62, "lights": "round", "scoop": true, "chrome": false,
		"box": Vector3(1.9, 1.15, 4.7), "box_y": 0.72,
	},
	{
		"id": "vanguard", "name": "Vanguard RS", "kind": "sport", "level": 4, "cost": 4500,
		"desc": "Aggressive sport coupe with a huge grille and a wide stance.",
		"mass": 1600.0, "power": 3700.0, "kmh": 170, "top": 190.0, "grip": 6.6, "brake": 40.0, "steer": 1.0,
		"downforce": 9.0, "com": Vector3(0, -0.2, 0), "cam": 0.95, "len": 4.8, "paint": 0,
		"hw": [[0, .80], [.05, .92], [.16, .95], [.5, .96], [.85, .96], [.96, .92], [1, .82]],
		"y0": [[0, .32], [.03, .24], [.1, .19], [.9, .19], [.97, .26], [1, .34]],
		"y1": [[0, .62], [.08, .74], [.3, .84], [.5, .88], [.9, .93], [1, .88]],
		"c0": 0.36, "c1": 0.9, "roof": 1.38,
		"chw": [[0, .84], [.5, .78], [1, .72]],
		"roof_f": [[0, 0.0], [.1, .6], [.3, 1.0], [.7, 1.0], [.9, .6], [1, .15]],
		"wr": 0.36, "ww": 0.30, "wx": 0.83, "wzf": -1.5, "wzr": 1.52, "wy": -0.05, "rest": 0.14,
		"stiff": 72, "roll": 0.08, "oh": 0.501,
		"wing": 1, "splitter": true, "grille": 0.92, "lights": "slim", "scoop": false, "chrome": false,
		"box": Vector3(1.92, 1.18, 4.8), "box_y": 0.74,
	},
	{
		"id": "sovereign", "name": "Sovereign", "kind": "luxury", "level": 5, "cost": 7000,
		"desc": "Long luxury sedan. Smooth, stately and very stable.",
		"mass": 2300.0, "power": 3800.0, "kmh": 140, "top": 165.0, "grip": 5.6, "brake": 34.0, "steer": 0.9,
		"downforce": 6.0, "com": Vector3(0, -0.25, 0), "cam": 1.1, "len": 5.5, "paint": 5,
		"hw": [[0, .84], [.05, .94], [.16, .96], [.5, .97], [.9, .96], [.97, .93], [1, .86]],
		"y0": [[0, .34], [.03, .27], [.1, .24], [.9, .24], [.97, .3], [1, .36]],
		"y1": [[0, .78], [.06, .92], [.25, 1.0], [.5, 1.02], [.9, 1.05], [1, 1.0]],
		"c0": 0.34, "c1": 0.88, "roof": 1.5,
		"chw": [[0, .86], [.5, .82], [1, .76]],
		"roof_f": [[0, 0.0], [.08, .7], [.2, 1.0], [.8, 1.0], [.93, .6], [1, .1]],
		"wr": 0.38, "ww": 0.27, "wx": 0.84, "wzf": -1.75, "wzr": 1.75, "wy": -0.05, "rest": 0.15,
		"stiff": 115, "roll": 0.1, "oh": 0.545,
		"wing": 0, "splitter": false, "grille": 0.55, "lights": "slim", "scoop": false, "chrome": true,
		"box": Vector3(1.96, 1.3, 5.4), "box_y": 0.85,
	},
	{
		"id": "aurelia", "name": "Aurelia GT3", "kind": "gt3", "level": 7, "cost": 11000,
		"desc": "Track-bred GT racer with a giant wing. Very fast, very sharp.",
		"mass": 1330.0, "power": 4300.0, "kmh": 195, "top": 215.0, "grip": 7.6, "brake": 46.0, "steer": 0.9,
		"downforce": 16.0, "com": Vector3(0, -0.1, 0.1), "cam": 0.85, "len": 4.6, "paint": 6,
		"hw": [[0, .84], [.05, .95], [.16, 1.0], [.5, 1.0], [.85, 1.0], [.96, .95], [1, .85]],
		"y0": [[0, .26], [.03, .17], [.1, .13], [.9, .13], [.97, .2], [1, .28]],
		"y1": [[0, .40], [.05, .52], [.25, .60], [.42, .72], [.6, .80], [.88, .80], [1, .62]],
		"c0": 0.36, "c1": 0.78, "roof": 1.12,
		"chw": [[0, .80], [.5, .74], [1, .66]],
		"roof_f": [[0, 0.0], [.15, .6], [.35, 1.0], [.6, 1.0], [.85, .6], [1, .1]],
		"wr": 0.37, "ww": 0.33, "wx": 0.88, "wzf": -1.38, "wzr": 1.4, "wy": -0.05, "rest": 0.13,
		"stiff": 96, "roll": 0.05, "oh": 0.513,
		"wing": 2, "splitter": true, "grille": 0.4, "lights": "slim", "scoop": true, "chrome": false,
		"box": Vector3(2.0, 0.95, 4.5), "box_y": 0.6,
	},
	{
		"id": "sovereignx", "name": "Sovereign X", "kind": "suv", "level": 8, "cost": 15000,
		"desc": "Tall luxury SUV. Commanding, heavy and unstoppable.",
		"mass": 2700.0, "power": 4200.0, "kmh": 135, "top": 170.0, "grip": 5.4, "brake": 34.0, "steer": 0.9,
		"downforce": 5.0, "com": Vector3(0, -0.35, 0), "cam": 1.2, "len": 5.3, "paint": 5,
		"hw": [[0, .90], [.04, .98], [.15, 1.0], [.5, 1.0], [.92, 1.0], [.98, .96], [1, .9]],
		"y0": [[0, .42], [.03, .34], [.1, .3], [.9, .3], [.97, .36], [1, .42]],
		"y1": [[0, .95], [.04, 1.1], [.2, 1.2], [.5, 1.22], [.95, 1.22], [1, 1.1]],
		"c0": 0.3, "c1": 0.98, "roof": 1.82,
		"chw": [[0, .92], [.5, .88], [1, .84]],
		"roof_f": [[0, 0.0], [.08, .8], [.2, 1.0], [.9, 1.0], [.97, .6], [1, .15]],
		"wr": 0.44, "ww": 0.3, "wx": 0.9, "wzf": -1.7, "wzr": 1.7, "wy": -0.05, "rest": 0.18,
		"stiff": 105, "roll": 0.08, "oh": 0.637,
		"wing": 0, "splitter": false, "grille": 0.6, "lights": "slim", "scoop": false, "chrome": true,
		"box": Vector3(2.0, 1.5, 5.2), "box_y": 1.0,
	},
]

static func spec(i: int) -> Dictionary:
	return LIST[clampi(i, 0, LIST.size() - 1)]

## The full physics-less visual model for car `i`. detail: 0 = cheap (traffic), 1 = full.
static func make_model(i: int, detail := 1) -> Node3D:
	if i == BUS:
		return BusModel.new()
	return CarBuilder.build(spec(i), detail)

## Attach plain (non-physics) wheels, used by the garage/menu showroom.
static func add_static_wheels(model: Node3D, i: int, rim: Material) -> void:
	var s := spec(i)
	if i == BUS:
		for p in [Vector3(-0.95, -0.4, -1.55), Vector3(0.95, -0.4, -1.55), Vector3(-0.95, -0.4, 1.55), Vector3(0.95, -0.4, 1.55)]:
			var w := Node3D.new()
			w.position = p
			model.add_child(w)
			MeshKit.wheel_visual(w, 0.4, 0.3, rim)
		return
	for sx in [-1.0, 1.0]:
		for z in [s["wzf"], s["wzr"]]:
			var w := Node3D.new()
			w.position = Vector3(float(sx) * CarBuilder.wheel_x(s, float(z)), float(s["wr"]), float(z))
			model.add_child(w)
			CarBuilder.wheel_visual(w, s, 1)

## Y offset to put a model's ground contact at y = 0 (bus origin is 0.8 above the ground).
static func ground_offset(i: int) -> float:
	return 0.8 if i == BUS else 0.0
