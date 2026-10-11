# PROGRESS CHECKPOINT

## Session 2 (cars + realism request) - status
- [x] CAR ROSTER DONE: Cars.gd (7 cars: microbus + Kairo GT, Stallion GT, Vanguard RS, Sovereign, Aurelia GT3, Sovereign X - ORIGINAL designs, no real logos/brands/characters), CarBuilder (lofted bodies, wheels), CarModel (clear-coat paint, glass, lights, kits), Microbus spec-driven, Garage Cars tab, showroom switching, traffic uses roster, Save car/owned_cars
- [x] tests/CarsTest (all cars: no flips, 0-100 3-6 s, brake, flip recovery), UITest 21 checks pass, WorldTest passes
- [x] Realism pass DONE: time of day (Day/Golden hour/Night) setting, ACES tonemap, sun shadows, PBR asphalt, building day/night shader, sky reflections; screenshots checked (tod0/1/2)
- [x] UITest/WorldTest/CarsTest re-run after realism: 0 failures
- [ ] NEXT: user pushes to GitHub -> Actions builds APK; test on real phone (performance of High preset unmeasured)
- Honest limit: procedural cars are smooth stylized shapes, not photoreal; photoreal needs real 3D model assets (none free+offline in sandbox)

---
(older notes below)

Last updated: 2026-10-10 (session 1, after resume)

## Status: game feature-complete; APK build is written but NOT yet run (needs GitHub)

### Done and verified (Godot 4.3.stable, headless + xvfb/llvmpipe software GL)
- [x] M1-M2: project.godot, MeshKit, BusModel, Microbus, CameraRig, City, Weather, TouchControls, HUD, World
- [x] M3: Traffic, Missions, Garage (paint/neon/kits/5 upgrades)
- [x] M4: MainMenu, SettingsPanel, Audio (procedural), Save (JSON, corrupt-safe, int-normalised)
- [x] M5: visual check by real rendered screenshots (menu, garage, chase, far, rain); fixed anchors bug + save float bug + sleep bug + engine-force sign bug
- [x] M6 files: export_presets.cfg (arm64 + armv7 debug APK), .github/workflows/build.yml, README, LICENSE, THIRD_PARTY, .gitignore
- [x] `--export-pack` validation of all resources passes (110 KB pack)

### Test evidence
- tests/PhysicsTest: ~0-100 km/h in ~6 s, 56 m stop from 106 km/h, steering direction correct, flip recovery works
- tests/WorldTest: full loop job -> board -> 2 checkpoints -> deliver pays out; pause/camera/rain OK
- tests/UITest: 14 checks pass (purchases, upgrades change vehicle tuning, XP, save round-trip, corrupt save, owned-after-reload)
- tests/ShotTest: renders PNG screenshots under xvfb (`xvfb-run godot --rendering-driver opengl3 res://tests/ShotTest.tscn -- OUTDIR`)

## Remaining / next exact steps
1. User creates GitHub repo and pushes (sandbox `gh` token is invalid; cannot push from here)
2. Watch first Actions run; fix any CI-only failure (most likely spots: Android SDK path, export-template unzip names, editor_settings keys)
3. Install APK on a real phone, test touch controls, tune performance (Low preset: 0.6 render scale, no shadows/glow)

## Known issues / untested (be honest)
- APK never built or installed here (Android SDK download blocked in sandbox) - CI workflow unverified until first real run
- Touch controls, tilt steering (experimental), real-device FPS: untested
- Engine/horn/music sound quality judged only by code, not by ear
- Traffic may rear-end-block the player at start (random); collisions are simple
- Headless dummy renderer prints harmless `mesh_get_surface_count` errors
