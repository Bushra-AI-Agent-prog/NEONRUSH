# NEON BUS — Futuristic Microbus Driving Game (Android)

## Decisions
- **Engine:** Godot 4.3 (MIT, free). GDScript. Renderer: `gl_compatibility` (widest Android support, low-end friendly).
- **Assets:** 100% procedural (code-generated meshes, materials, audio). No third-party assets -> no licence risk, tiny APK, offline.
- **Build:** GitHub Actions on `ubuntu-latest` (free tier): JDK 17, Android SDK cmdline-tools, Godot headless + export templates, **debug APK** with auto-generated debug keystore (no secrets).
- **Dev PC (Win7/2GB) is not used.** Everything builds in CI.

## Architecture (scripts/)
| File | Responsibility |
|---|---|
| `Save.gd` (autoload) | JSON save: money, unlocks, upgrades, color, settings, best scores |
| `Audio.gd` (autoload) | Procedural SFX/engine/music (generated waveforms), volume buses |
| `Game.gd` (autoload) | Scene switching, quality application, pause, shared constants |
| `MeshKit.gd` | Helpers: boxes, cylinders, emissive/neon materials |
| `Microbus.gd` | VehicleBody3D: body mesh, 4 wheels, suspension, steering, upgrades, recovery |
| `CameraRig.gd` | 3 views: chase, hood, far |
| `City.gd` | Procedural grid city: roads, lane marks, buildings (MultiMesh), neon, lamps, sky, rain/fog |
| `Traffic.gd` | AI cars following grid lanes, stop on blocked ahead, collide as bodies |
| `Missions.gd` | Passenger pickup/drop-off, timer, fare, checkpoints, rewards, progression |
| `HUD.gd` | Speedo, money, mission panel, minimap, arrow, pause |
| `TouchControls.gd` | Steering buttons, gas, brake, handbrake, camera, reset |
| `World.gd` | Gameplay scene root wiring all of the above |
| `MainMenu.gd` / `Garage.gd` / `Settings.gd` | UI screens |

## Milestones / checklist (tracked in PROGRESS.md)
1. Foundation + drivable prototype
2. Physics tuning, cameras, HUD, touch, environment
3. Traffic, missions, rewards, garage, progression
4. Menus, settings, audio, saves
5. Polish, optimization, validation
6. CI workflow, repo, APK delivery

## Risks
- Cannot run an Android device/emulator here -> APK install/run is **untested** until the user installs it.
- `gh` token invalid in this sandbox -> user must create repo & push (instructions in README).
- Android SDK host blocked in sandbox -> APK build can only be proven by the real GitHub Actions run.
