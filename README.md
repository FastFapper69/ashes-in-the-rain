# INK & LEAD

Noir bullet-time shooter for phones, in the style of a 1940s ink comic. Godot 4.7, Compatibility renderer.

**Play in the browser (phone or PC):** https://fastfapper69.github.io/ink-and-lead/

## Controls

| Action | PC | Phone |
| --- | --- | --- |
| Walk | A / D | left thumbstick |
| Aim | mouse | automatic, at the nearest mobster |
| Shoot | left mouse button | revolver button |
| Slowed time | hold Shift | stopwatch button |
| Jump | W or Space | double-chevron button |
| Dive (roll out of a run) | E or Ctrl | runner button while standing |
| Slide | S or C while running | runner button while running |
| Crouch behind cover | hold S or C | thumbstick down |

Debug keys on PC: F9 runs the move demo and saves pictures, F10 saves a picture, F11 runs the cover test, 0 prints the frame rate.

## Layout

- `main.gd` – the level, the camera, the rules
- `puppet.gd` – characters drawn from separate parts, posed by code every frame
- `atmosphere.gd` – rain, mist, steam and the screen-wide ink grade
- `fx.gd` – gunfire, bullets, blood, lettered sound effects
- `hud.gd` – portrait, health, thumbstick and buttons
- `art/` – the drawings (generated, cut out and given light maps)
