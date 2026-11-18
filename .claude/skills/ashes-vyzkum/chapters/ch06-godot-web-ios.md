# Chapter 6: Godot web & iOS

## Core Idea
The web build runs WebAssembly + WebGL 2 in Safari's process budget. GPU passes, decoded audio and the wasm heap all compete for one per-page memory limit that is far below the phone's RAM.

## Facts (Godot docs @2c6cc13, 4.x)
- Web = Compatibility renderer only (WebGL 2); Safari has extra WebGL 2 issues. Native iOS export is always faster – web avoids the App Store.
- **Single-threaded export is the default since 4.3** and the recommended one for macOS/iOS (threads need cross-origin isolation). [OK] our presets: `thread_support=false`, `extensions_support=false`.
- **Audio**: default playback on web is *Sample* (Web Audio API): low latency without threads, but no AudioEffects, no reverb/doppler, no procedural audio. Stream mode = full features, more latency. Autoplay needs a user tap first.
- Smaller, faster start: compile an **optimised export template** with unused features disabled (shrinks the wasm payload). [H] for us: a custom web template without 3D/unused modules → less wasm memory and faster boot; worth one measured try.
- GitHub Pages gzips on the fly; wasm compresses to about a quarter.
- Background tabs are paused (no `_process`).
- `Engine.time_scale` scales `_process`/`_physics_process` delta and timers, **not audio speed** (use `AudioServer.playback_speed_scale` separately). [OK] our movement runs in `_process`, so slowed time at 0.15 does not staircase like physics ticks would (at 60 ticks/s × 0.15 a physics-driven body would update ~9×/s real time). Keep gameplay motion out of `_physics_process` or turn on physics interpolation.
- Basis Universal is transcoded at load to the GPU format; VRAM use ≈ VRAM Compressed; files are very small. [OK] no texture in the repo uses plain VRAM Compressed (checked imports: all compressed art is mode 4), so `for_mobile=false` does not hurt.
- `Parallax2D` (4.3+) replaces ParallaxBackground/Layer: `scroll_scale` < 1 = far; `repeat_size` for endless layers (texture should cover the viewport).
- **CanvasGroup** draws its children by reading the back buffer (custom shader) – i.e. an extra screen-sized copy per group.

## iOS Safari memory
- WebKit computes the page limit from physical RAM and the jetsam limit; analyses put it at roughly 300–450 MB on current iPhones; memory-pressure cleanups at ~50 % and ~65 %, reload at 100 %. Fast allocation bursts also get pages killed. Reload loops end in "A problem repeatedly occurred".
- Known leak: resizing a WebGL canvas repeatedly (orientation/address-bar changes) can leak backing stores.
- Godot forum reports: iOS web crashes across 4.4–4.6, WebGL context loss on some iOS versions, audio-related reload loops – our crash reporter is the right tool; keep the engine on a version whose reports are clean.

## Apply to Ashes
- [H] **CanvasGroup budget**: one per puppet + the dive/slow-mo ghost trail creates a new CanvasGroup (with fresh Sprite2Ds) every 0.05 s living 0.26 s. Try a pool of ~6 reused ghosts, or ghosts as flat Sprite2D silhouettes without a group; puppet body as a group only while alpha < 1. Measure fps in the biggest fight and `worst_frame` on the phone.
- [H] Pack per map instead of per chapter (heap = base + pack + game; report 14 died at heap 242 MB + ~150 MB textures).
- [H] Load in slices across frames at map start to avoid an allocation spike.
- [H] Never resize the canvas after boot (landscape lock); log `resize` events in crumbs to confirm.

## Key Takeaways
1. Budget the page at ~350 MB total, not the phone's RAM.
2. Every CanvasGroup and full-screen shader is a screen pass – count them.
3. Measure with crumbs on the iPhone, not on desktop.

## Cheaper wall shadow – idea from Barrow and Blade (80.lv, checked 2026-11-18) [H]
- Their trick (Unreal, 3D): each character has a second, much simpler mesh only for the shadow, driven by the main skeleton (no second animation), projected onto the floor; only the overall shape matters.
- Us: `puppet.gd _build_shadow()` makes a FULL black copy of every figure (every body sprite, both leg meshes, skirt, both guns) inside a second CanvasGroup = one more backbuffer pass per visible shadow plus a per-frame pose copy (`_shadow_spr` loop ~l. 897). With 6–8 figures in a fight that doubles the CanvasGroup count (see takeaway 1).
- [H] Try: shadow from 4–6 merged parts (head+hat, torso+coat, legs, gun arm) following the same bones; or one pre-drawn silhouette per pose family. Measure fps in the biggest fight (`--test=perf`) before/after on the iPhone; keep only if visibly the same on the wall (user rule: lights/shadows must make physical sense) and faster.
